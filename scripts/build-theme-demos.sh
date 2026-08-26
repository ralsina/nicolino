#!/bin/bash
# Build a demo site for each Nicolino theme and copy the output
# into assets/themes/demo/<themename>/ so the main site serves
# live theme previews.
#
# Usage:  scripts/build-theme-demos.sh
#   or:   make theme-demos
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

THEMES="default minimal terminal papermod"
DEMO_DIR="$REPO_ROOT/demo"
ASSETS_DIR="$REPO_ROOT/assets/themes/demo"

for theme in $THEMES; do
  echo "🎨 Building demo: $theme"

  # Point demo config at this theme
  sed -i "s/^theme: .*/theme: $theme/" "$DEMO_DIR/conf.yml"

  # Wipe previous build artefacts so Croupier doesn't carry over
  # stale task graphs from a different theme
  rm -rf "$DEMO_DIR/output" "$DEMO_DIR/.croupier" "$DEMO_DIR/.kvstore"

  # Build the demo site
  (cd "$DEMO_DIR" && ../bin/nicolino build)

  # Ship the result into the main site's assets
  rm -rf "${ASSETS_DIR:?}/$theme"
  cp -r "$DEMO_DIR/output" "$ASSETS_DIR/$theme"

  # Clean up before the next theme
  rm -rf "$DEMO_DIR/output" "$DEMO_DIR/.croupier" "$DEMO_DIR/.kvstore"

  echo "  ✓ $theme → assets/themes/demo/$theme/"
done

# Restore the nicest-looking theme for manual `demo/` browsing
sed -i "s/^theme: .*/theme: papermod/" "$DEMO_DIR/conf.yml"

echo "✅ All theme demos built in assets/themes/demo/"
