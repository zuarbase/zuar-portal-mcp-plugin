#!/usr/bin/env bash
# Build the files attached to a GitHub release of this repo:
#
#   zportal-<version>.zip  the plugin, for Claude Code's "archive" plugin source
#   marketplace.json       a catalog whose zportal entry downloads that zip,
#                          pinned by its sha256
#   zportal.js             the bundled MCP server on its own, for other clients
#
# Users add the marketplace with the URL of the latest release's
# marketplace.json, so installing needs HTTPS access and no git.
#
# Usage: build-release-assets.sh <plugin-tree> <tag> <owner/repo> <out-dir>
#   <plugin-tree>  directory laid out like this repo (a checkout of a tag)
#   <tag>          release tag, such as v0.6.0
#   <owner/repo>   GitHub repository the release is published to
#   <out-dir>      directory to write the three files to (created if missing)
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 <plugin-tree> <tag> <owner/repo> <out-dir>" >&2
  exit 2
fi

tree=$(cd "$1" && pwd)
tag=$2
repo=$3
mkdir -p "$4"
out=$(cd "$4" && pwd)
version=${tag#v}

# Everything Claude Code loads from the plugin. The marketplace file is
# left out: it describes where to get the plugin, not the plugin itself.
files=(
  .claude-plugin/plugin.json
  .mcp.json
  client-mcp/dist/index.js
  client-mcp/package.json
)
for f in "${files[@]}"; do
  [ -f "$tree/$f" ] || { echo "missing $f in $tree" >&2; exit 1; }
done
[ -d "$tree/skills" ] || { echo "missing skills/ in $tree" >&2; exit 1; }

# The plugin's version comes from plugin.json, and Claude Code installs
# an update only when that version changes. Refuse a tree whose version
# does not match the tag.
manifest_version=$(jq -r .version "$tree/.claude-plugin/plugin.json")
if [ "$manifest_version" != "$version" ]; then
  echo "plugin.json version is $manifest_version, tag is $tag" >&2
  exit 1
fi

# Copy into a staging directory and set every file's time and mode, so
# building the same tree twice gives the same zip bytes and sha256.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
for f in "${files[@]}"; do
  mkdir -p "$stage/$(dirname "$f")"
  cp "$tree/$f" "$stage/$f"
done
cp -R "$tree/skills" "$stage/skills"
find "$stage" -type d -exec chmod 755 {} +
find "$stage" -type f -exec chmod 644 {} +
find "$stage" -exec env TZ=UTC touch -t 200001010000.00 {} +

zip_name="zportal-$version.zip"
rm -f "$out/$zip_name"
(
  cd "$stage"
  # Sorted names and no extra attributes (-X) keep the archive stable.
  find . -type f | sed 's|^\./||' | LC_ALL=C sort \
    | TZ=UTC zip -q -X "$out/$zip_name" -@
)

if command -v sha256sum >/dev/null; then
  sha256=$(sha256sum "$out/$zip_name" | cut -d' ' -f1)
else
  sha256=$(shasum -a 256 "$out/$zip_name" | cut -d' ' -f1)
fi

# The zip URL names this release's tag, not "latest", so the sha256
# stays correct after later releases.
zip_url="https://github.com/$repo/releases/download/$tag/$zip_name"

jq -n \
  --arg url "$zip_url" \
  --arg sha256 "$sha256" \
  --arg description "$(jq -r .description "$tree/.claude-plugin/plugin.json")" \
  '{
    name: "zuar-portal",
    description: "Zuar Portal plugin for Claude Code",
    owner: {name: "Zuar", url: "https://github.com/zuarbase"},
    plugins: [{
      name: "zportal",
      description: $description,
      source: {source: "archive", url: $url, sha256: $sha256}
    }]
  }' > "$out/marketplace.json"

cp "$tree/client-mcp/dist/index.js" "$out/zportal.js"

echo "zip:      $out/$zip_name"
echo "sha256:   $sha256"
echo "zip url:  $zip_url"
echo "catalog:  $out/marketplace.json"
echo "server:   $out/zportal.js"
