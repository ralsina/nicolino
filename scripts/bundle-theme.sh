#!/usr/bin/env bash
# Bundle a Nicolino theme into a tarball and generate themes.json entry
# Usage: ./scripts/bundle-theme.sh <theme-name>

set -e

THEME_NAME="${1:-}"
if [ -z "$THEME_NAME" ]; then
    echo "Usage: $0 <theme-name>"
    echo "Example: $0 minimal"
    exit 1
fi

THEME_DIR="themes/$THEME_NAME"
THEME_YML="$THEME_DIR/theme.yml"
TARBALL="themes/$THEME_NAME.tar.gz"

# Check if theme directory exists
if [ ! -d "$THEME_DIR" ]; then
    echo "Error: Theme directory '$THEME_DIR' does not exist"
    exit 1
fi

# Check if theme.yml exists
if [ ! -f "$THEME_YML" ]; then
    echo "Error: Theme metadata file '$THEME_YML' does not exist"
    exit 1
fi

# Create tarball with themes/<theme>/ structure
echo "Creating tarball: $TARBALL"
mkdir -p /tmp/bundle-theme
rm -rf /tmp/bundle-theme/themes
mkdir -p /tmp/bundle-theme/themes
cp -r "$THEME_DIR" /tmp/bundle-theme/themes/
tar czf "$TARBALL" -C /tmp/bundle-theme themes
rm -rf /tmp/bundle-theme/themes

# Calculate SHA256
echo "Calculating SHA256..."
SHA256=$(sha256sum "$TARBALL" | cut -d' ' -f1)

# Read metadata from theme.yml
# We need to parse YAML manually in pure bash or use a tool
# For simplicity, we'll output JSON with the sha256 and url
# The rest of the metadata should be copied from theme.yml

echo ""
echo "Theme '$THEME_NAME' bundled successfully!"
echo ""
echo "Add this entry to themes.json:"
echo ""
echo "  \"$THEME_NAME\": {"
echo "    \"url\": \"https://nicolino.site/themes/$THEME_NAME.tar.gz\","
echo "    \"sha256\": \"$SHA256\","
echo "    \"name\": \"$(grep '^name:' "$THEME_YML" | cut -d' ' -f2-)\","
echo "    \"version\": \"$(grep '^version:' "$THEME_YML" | cut -d' ' -f2-)\","
echo "    \"description\": \"$(grep '^description:' "$THEME_YML" | cut -d' ' -f2- | sed 's/"//g')\","
echo "    \"author\": \"$(grep '^author:' "$THEME_YML" | cut -d' ' -f2- | sed 's/"//g')\","
echo "    \"license\": \"$(grep '^license:' "$THEME_YML" | cut -d' ' -f2- | sed 's/"//g')\","
echo "    \"screenshot\": \"$(grep '^screenshot:' "$THEME_YML" | cut -d' ' -f2-)\""
echo "  }"
