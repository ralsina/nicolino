#!/usr/bin/env bash
# Build the Nicolino theme registry for the production site.
#
# Bundles every shipped theme into a tarball, computes its SHA256, and
# writes a themes.json registry that the `nicolino theme` command reads.
# The outputs are placed under assets/ so a normal `nicolino build`
# copies them to output/ and the deploy step rsync's them to
# https://nicolino.ralsina.me/.
#
#   themes.json                      -> /themes.json
#   assets/themes/registry/<n>.tar.gz -> /themes/registry/<n>.tar.gz
#
# Both outputs are git-ignored build artifacts (like assets/themes/demo/).
#
# Usage:  scripts/build-theme-registry.sh
#   or:   make theme-registry
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# All themes that ship with Nicolino and are available in the registry.
THEMES="default minimal terminal papermod blox"
SITE_URL="https://nicolino.ralsina.me"

REGISTRY_OUT="$REPO_ROOT/assets/themes.json"
TARBALL_OUT="$REPO_ROOT/assets/themes/registry"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$TARBALL_OUT" "$WORKDIR"
: > "$REGISTRY_OUT"

echo "{" >> "$REGISTRY_OUT"
echo '  "themes": {' >> "$REGISTRY_OUT"

first=true
for theme in $THEMES; do
  THEME_DIR="$REPO_ROOT/themes/$theme"
  if [ ! -f "$THEME_DIR/theme.yml" ]; then
    echo "  ✗ themes/$theme has no theme.yml; skipping" >&2
    continue
  fi

  # Build tarball with themes/<theme>/ structure (as the installer expects)
  rm -rf "$WORKDIR/themes"
  mkdir -p "$WORKDIR/themes"
  cp -r "$THEME_DIR" "$WORKDIR/themes/"
  tarball="$TARBALL_OUT/$theme.tar.gz"
  tar czf "$tarball" -C "$WORKDIR" themes
  sha256=$(sha256sum "$tarball" | cut -d' ' -f1)

  # Read metadata from theme.yml
  get() { grep "^$1:" "$THEME_DIR/theme.yml" | head -1 | cut -d' ' -f2- | sed 's/"//g' | xargs; }
  name=$(get name)
  version=$(get version)
  description=$(get description)
  author=$(get author)
  license=$(get license)
  screenshot="$(get screenshot)"

  if [ "$first" = true ]; then first=false; else echo "," >> "$REGISTRY_OUT"; fi
  cat >> "$REGISTRY_OUT" <<EOF
    "$theme": {
      "url": "$SITE_URL/themes/registry/$theme.tar.gz",
      "sha256": "$sha256",
      "name": "$name",
      "version": "$version",
      "description": "$description",
      "author": "$author",
      "license": "$license",
      "screenshot": "$screenshot"
    }
EOF
  echo "  ✓ $theme → $tarball ($(du -h "$tarball" | cut -f1))"
done

echo '  }' >> "$REGISTRY_OUT"
echo '}' >> "$REGISTRY_OUT"

# Keep the JSON tidy (single object, trailing newline); ensure it parses.
python3 - "$REGISTRY_OUT" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as f:
    data = json.load(f)
with open(p, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

echo "✅ Registry written to $REGISTRY_OUT"
