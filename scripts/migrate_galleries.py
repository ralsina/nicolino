#!/usr/bin/env python3
"""
Convert Nikola gallery index.txt files to Nicolino index.md format.
"""

import re
from pathlib import Path

# Paths
GALLERIES_DIR = Path("myblog/content/galleries")


def convert_gallery_index(index_file: Path):
    """Convert a gallery index.txt to index.md."""
    if not index_file.exists():
        return

    # Read the content
    content = index_file.read_text(encoding="utf-8")

    # Parse Nikola metadata format: .. title: Some Title
    title = "Gallery"
    date = ""

    # Extract title from Nikola format
    title_match = re.search(r'\.\.\s*title:\s*(.+)', content)
    if title_match:
        title = title_match.group(1).strip()

    # Extract slug if present
    slug_match = re.search(r'\.\.\s*slug:\s*(.+)', content)
    slug = slug_match.group(1).strip() if slug_match else index_file.parent.name

    # Remove Nikola metadata lines
    lines = []
    for line in content.split("\n"):
        if not line.strip().startswith(".."):
            lines.append(line)

    body_content = "\n".join(lines).strip()

    # Create Nicolino frontmatter
    new_content = f"""---
title: "{title}"
date: 2024-01-01
---

{body_content}
"""

    # Write to index.md
    output_file = index_file.parent / "index.md"
    output_file.write_text(new_content, encoding="utf-8")

    # Remove old index.txt
    index_file.unlink()

    print(f"Converted: {index_file} -> {output_file}")


def main():
    """Convert all gallery index files."""
    # Find all index.txt files
    index_files = list(GALLERIES_DIR.rglob("index.txt"))
    index_files.extend(GALLERIES_DIR.rglob("index.es.txt"))

    for index_file in index_files:
        try:
            convert_gallery_index(index_file)
        except Exception as e:
            print(f"Error converting {index_file}: {e}")

    print(f"\nConverted {len(index_files)} gallery index files")


if __name__ == "__main__":
    main()
