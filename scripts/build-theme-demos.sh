#!/bin/bash
# Build a demo site for each Nicolino theme and copy the output
# into assets/themes/demo/<themename>/ so the main site serves
# live theme previews.
#
# Each demo builds with url_prefix set so the relativizer computes
# correct relative paths for the nested location.
#
# Usage:  scripts/build-theme-demos.sh
#   or:   make theme-demos
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

THEMES="default minimal terminal papermod blox loveit coder"
DEMO_DIR="$REPO_ROOT/demo"
ASSETS_DIR="$REPO_ROOT/assets/themes/demo"
mkdir -p "$ASSETS_DIR"

for theme in $THEMES; do
  echo "🎨 Building demo: $theme"

  # Set theme and url_prefix so relativize computes correct paths
  sed -i "s/^theme: .*/theme: $theme/" "$DEMO_DIR/conf.yml"
  sed -i "/^url_prefix:/d" "$DEMO_DIR/conf.yml"
  sed -i "/^theme: .*/a url_prefix: \"/themes/demo/$theme\"" "$DEMO_DIR/conf.yml"

  # Wipe previous build artefacts
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

# Restore papermod and clean up config
sed -i "s/^theme: .*/theme: papermod/" "$DEMO_DIR/conf.yml"
sed -i "/^url_prefix:/d" "$DEMO_DIR/conf.yml"

echo "✅ All theme demos built in assets/themes/demo/"
