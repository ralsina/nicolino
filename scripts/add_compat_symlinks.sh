#!/bin/bash
# Add compatibility symlinks for Nikola site HTML paths
# Run after nicolino build to maintain backward compatibility

set -e

OUTPUT_DIR="${1:-output}"

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory not found: $OUTPUT_DIR"
    echo "Usage: $0 [output_directory]"
    exit 1
fi

cd "$OUTPUT_DIR"

echo "Creating compatibility symlinks for HTML paths..."

# Link stories -> . (pages HTML are at root, stories was old location)
# This allows old links to /stories/10.html to find /10.html
if [ ! -L "stories" ]; then
    ln -s . stories
    echo "  stories -> .  (so /stories/10.html → /10.html)"
fi

# Link weblog/posts -> ../posts (blog posts now in posts/, were in weblog/posts)
# This allows old links to /weblog/posts/XXX.html to find /posts/XXX.html
mkdir -p weblog
if [ ! -L "weblog/posts" ]; then
    ln -s ../posts weblog/posts
    echo "  weblog/posts -> ../posts  (so /weblog/posts/XXX.html → /posts/XXX.html)"
fi

echo "Compatibility symlinks created!"
