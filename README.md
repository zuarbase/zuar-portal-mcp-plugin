# Zuar Portal plugin for Claude Code

This plugin lets Claude Code build and edit content on Zuar Portal
instances: pages, blocks, charts, themes, queries and datasources.

It contains a local MCP server (`zportal-client-mcp`) and a set of
skills. The server runs on your machine over stdio. It keeps a list of
the portals you have connected, and forwards each tool call to the
Portal MCP server of the right portal, authenticated with that
portal's API key. When several connected portals run the same Portal
version, Claude sees one set of tools with a `portal` argument, not a
copy per portal.

## Requirements

- Claude Code.
- Node.js 18 or later on your `PATH`. The plugin starts the server
  with `node`.
- A Zuar Portal instance on version 1.21 or later (the first release
  with a Portal MCP server), and a Portal API key for it.

## Install

In Claude Code:

```
/plugin marketplace add zuarbase/zuar-portal-mcp-plugin
/plugin install zportal@zuar-portal
```

Then restart the session, or run `/reload-plugins`.

To preconfigure the plugin for everyone working in a project, add this
to the project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "zuar-portal": {
      "source": {"source": "github", "repo": "zuarbase/zuar-portal-mcp-plugin"}
    }
  },
  "enabledPlugins": {"zportal@zuar-portal": true}
}
```

### If you installed from `zuarbase/portal-client-mcp`

That address no longer serves the plugin. Remove the marketplace and
add it again from this repo:

```
/plugin marketplace remove zuar-portal
/plugin marketplace add zuarbase/zuar-portal-mcp-plugin
/plugin install zportal@zuar-portal
```

## Update

```
/plugin marketplace update zuar-portal
```

Then restart the session, or run `/reload-plugins`.

## Connect a portal

In Claude Code, run `/zportal:connect <portal-url> [alias]`, or ask
Claude to connect a portal. The alias is the short name you use for
the portal in later requests. The server opens a form in your browser
on `localhost`, and you paste the API key there. The key never passes
through the conversation.

Connected portals are saved in `~/.zuar/portals.json`, which is
written with file mode 600 (readable only by you). Set
`ZUAR_PORTAL_REGISTRY` to use a different file.

`/zportal:status` shows the connected portals and which one the
session is using.

## Use it

Ask Claude for what you want built or changed on the portal. The
`zportal:portal-authoring` skill loads automatically for that kind of
request, and each portal serves guidance for its own version through
its `get_skill` tool.

### Which portal a session uses

A session works with one Portal version (major.minor) at a time. At
startup the server picks portals in this order:

1. A portal named explicitly: the `ZUAR_PORTAL` environment variable,
   for example `ZUAR_PORTAL=acme claude`.
2. A per-folder default: a `.zuar-portal/config.json` file containing
   `{"default_portal": "<alias>"}`, found in the current directory or
   any parent directory.
3. All connected portals, when they all run the same Portal version.

If none of these applies, the session starts with only the portal
management tools (`list_portals`, `connect_portal`, `use_portal`,
`remove_portal`). Calling `use_portal` selects a portal and makes the
portal tools available in the same session.

## Use it without Claude Code

Each release attaches the server as a single file, `zportal.js`, with
no dependencies to install. It works with any MCP client that runs
stdio servers, and doubles as a command line tool for managing
connected portals:

```bash
gh release download -R zuarbase/zuar-portal-mcp-plugin -p zportal.js
node zportal.js connect acme https://acme.example.com   # opens the key form
node zportal.js add acme https://acme.example.com <key> # for scripts
node zportal.js list
node zportal.js remove acme
```

Register it with your MCP client as:

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

Codex does not pick up new tools in the middle of a session. Start it
with the portal named up front: `ZUAR_PORTAL=acme codex`.

## Automated runs (CI, scripts)

To use a portal without saving its key to disk, pass it in the
environment:

```bash
ZUAR_PORTAL_URL=https://acme.example.com \
ZUAR_PORTAL_API_KEY=<key> \
  claude -p "..."
```

That portal replaces the saved list for the process, and nothing is
written to disk. `ZUAR_PORTAL` sets its alias (default `portal`).
Setting `ZUAR_PORTAL_URL` without `ZUAR_PORTAL_API_KEY` is an error
and the server exits at startup.
