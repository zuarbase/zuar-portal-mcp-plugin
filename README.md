# Zuar Portal MCP plugin

This plugin lets an AI coding agent build and edit content on Zuar
Portal instances: pages, blocks, charts, themes, queries and
datasources. It works with Claude Code, Codex, and any other MCP
client that can run a local stdio server.

It has two parts:

- **An MCP server** (`zportal-client-mcp`) that runs on your machine.
  It keeps a list of the portals you have connected, and forwards each
  tool call to the Portal MCP server of the right portal,
  authenticated with that portal's API key. When several connected
  portals run the same Portal version, the agent sees one set of tools
  with a `portal` argument, not a copy per portal.
- **Skills**: instructions that tell the agent how to connect portals
  and how to author Portal content. Each portal also serves guidance
  for its own version through its `get_skill` tool, which every client
  can use.

In Claude Code you install both parts as a plugin. In other clients
you register the server, which is a single file, `zportal.js`.

## Requirements

- Node.js 18 or later on your `PATH`. The server runs with `node`.
- For Claude Code: version 2.1.224 or later. Run `claude --version` to
  check. You do not need git. If you use the Claude desktop app, work
  in its **Code** view, not **Chat**: the plugin and its commands are
  available only in Claude Code.
- A Zuar Portal instance on version 1.21 or later (the first release
  with a Portal MCP server), admin access to it, and a Portal API key.
  To create the key, see
  [Connect an AI assistant to Portal MCP](https://www.zuar.com/docs/portal/1.21.0/How-to/Integrations/connect-to-portal-mcp/).
- An MCP client: Claude Code, Codex, or another client that runs local
  stdio servers.

## Install

### Claude Code

Run these commands in a Claude Code session:

```
/plugin marketplace add https://raw.githubusercontent.com/zuarbase/zuar-portal-mcp-plugin/main/marketplace.json
/plugin install zportal@zuar-portal
```

Then restart the session, or run `/reload-plugins`.

The first command downloads the plugin list (`marketplace.json`). The
second downloads the plugin as a zip file from the latest GitHub
release and checks it against the SHA-256 checksum in that list.
Both downloads use HTTPS; git is not used.

To preconfigure the plugin for everyone working in a project, add this
to the project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "zuar-portal": {
      "source": {
        "source": "url",
        "url": "https://raw.githubusercontent.com/zuarbase/zuar-portal-mcp-plugin/main/marketplace.json"
      }
    }
  },
  "enabledPlugins": {"zportal@zuar-portal": true}
}
```

### Codex and other MCP clients

Each release attaches the server as a single file, `zportal.js`, with
no dependencies to install. Download it:

```bash
curl -fLO https://github.com/zuarbase/zuar-portal-mcp-plugin/releases/latest/download/zportal.js
```

Or download it from the
[latest release](https://github.com/zuarbase/zuar-portal-mcp-plugin/releases/latest).

Register it with Codex:

```bash
codex mcp add zportal-client-mcp -- node /path/to/zportal.js
```

For other clients, register it with the client's MCP server
configuration. Most clients take this JSON format:

```json
{
  "mcpServers": {
    "zportal-client-mcp": {
      "command": "node",
      "args": ["/path/to/zportal.js"]
    }
  }
}
```

## Update

- **Claude Code:** run `/plugin marketplace update zuar-portal`, then
  restart the session or run `/reload-plugins`.
- **Other clients:** download `zportal.js` again over the old file,
  then restart the session.

## Connect a portal

In Claude Code, run `/zportal:connect` with your portal's URL and a
short name (an alias) to refer to it by:

```
/zportal:connect https://your-brand.zuarbase.net your-portal-nickname
```

In other clients, ask the agent to connect a portal, giving the same
URL and alias. The server opens a form in your browser on `localhost`,
and you paste the API key there. The key never passes through the
conversation.

You can also connect portals from a terminal, before starting a
session:

```bash
node zportal.js connect your-portal-nickname https://your-brand.zuarbase.net   # opens the key form
node zportal.js add your-portal-nickname https://your-brand.zuarbase.net <key> # for scripts
node zportal.js list
node zportal.js remove your-portal-nickname
```

In a Claude Code install, the same file is at
`client-mcp/dist/index.js` inside the plugin folder.

Connected portals are saved in `~/.zuar/portals.json`, which is
written with file mode 600 (readable only by you). Set
`ZUAR_PORTAL_REGISTRY` to use a different file.

## Use it

Ask the agent for what you want built or changed on the portal. In
Claude Code, `/zportal:status` shows the connected portals and which
one the session is using.

### Which portal a session uses

A session works with one Portal version (major.minor) at a time. At
startup the server picks portals in this order:

1. A portal named explicitly with the `ZUAR_PORTAL` environment
   variable, for example `ZUAR_PORTAL=your-portal-nickname claude` or
   `ZUAR_PORTAL=your-portal-nickname codex`.
2. A per-folder default: a `.zuar-portal/config.json` file containing
   `{"default_portal": "<alias>"}`, found in the current directory or
   any parent directory.
3. All connected portals, when they all run the same Portal version.

If none of these applies, the session starts with only the portal
management tools (`list_portals`, `connect_portal`, `use_portal`,
`remove_portal`). Calling `use_portal` selects a portal and adds the
portal tools to the session. Claude Code picks up the new tools
immediately. Codex does not pick up new tools in the middle of a
session, so start Codex with `ZUAR_PORTAL` set instead.

## Automated runs (CI, scripts)

To use a portal without saving its key to disk, pass it in the
environment of the agent process:

```bash
ZUAR_PORTAL_URL=https://your-brand.zuarbase.net \
ZUAR_PORTAL_API_KEY=<key> \
  claude -p "..."
```

That portal replaces the saved list for the process, and nothing is
written to disk. `ZUAR_PORTAL` sets its alias (default `portal`).
Setting `ZUAR_PORTAL_URL` without `ZUAR_PORTAL_API_KEY` is an error
and the server exits at startup.

## Installed a pre-release version?

Pre-release instructions added the marketplace as
`zuarbase/zuar-portal-mcp-plugin` or `zuarbase/portal-client-mcp`.
Those installs fetch with git and no longer receive updates. Re-add the
marketplace once:

```
/plugin marketplace remove zuar-portal
/plugin marketplace add https://raw.githubusercontent.com/zuarbase/zuar-portal-mcp-plugin/main/marketplace.json
/plugin install zportal@zuar-portal
```

Your connected portals are kept: they live in `~/.zuar/portals.json`,
outside the plugin.
