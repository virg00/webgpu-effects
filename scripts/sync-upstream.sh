#!/bin/bash
# Pull a release of the upstream `shaders` npm package and regenerate everything derived from it:
#   upstream/bundle.js + registry.mjs + LICENSE   (pristine copies)
#   app/webgpu-effects/src/main/ets/engine/bundle.js     (patched for the Ark runtime)
#   app/webgpu-effects/src/main/ets/components/components.ts, entry rawfile catalog.json (generated)
# Usage: scripts/sync-upstream.sh [version]   (default: latest)
set -euo pipefail
source "$(dirname "$0")/env.sh"
VERSION="${1:-latest}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
(cd "$TMP" && npm pack "shaders@$VERSION" --registry=https://registry.npmjs.org >/dev/null && tar xzf shaders-*.tgz)
PKG="$TMP/package"
echo "shaders $(node -p "require('$PKG/package.json').version")"
cp "$PKG/dist/js/bundle.js" "$ROOT/upstream/bundle.js"
cp "$PKG/dist/registry.js" "$ROOT/upstream/registry.mjs"
cp "$PKG/LICENSE" "$ROOT/upstream/LICENSE"
node -p "require('$PKG/package.json').version" > "$ROOT/upstream/VERSION"
node "$ROOT/scripts/patch-bundle.mjs" "$ROOT/upstream/bundle.js" "$ROOT/app/webgpu-effects/src/main/ets/engine/bundle.js"
node "$ROOT/scripts/gen-components.mjs" "$ROOT/upstream/registry.mjs"
