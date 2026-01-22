#!/usr/bin/env python3
"""
Migrate Nikola posts to Nicolino format.

Nikola format:
- Numbered files (1001.txt, 1002.txt, etc.)
- YAML frontmatter with date, title, tags, etc.
- Spanish translations as 1001.es.txt

Nicolino format:
- Date-based filenames: YYYY-MM-DD-slug.md
- YAML frontmatter (mostly compatible)
- Spanish translations in content/es/posts/

Usage:
    python3 scripts/migrate_posts.py
"""

import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple

# Paths
SOURCE_DIR = Path("mysite/posts")
TARGET_DIR = Path("myblog/content/posts")
TARGET_ES_DIR = Path("myblog/content/es/posts")


def parse_frontmatter(content: str) -> Tuple[dict, str]:
    """Parse YAML frontmatter from content.

    Returns (metadata_dict, content_without_frontmatter)
    """
    if not content.startswith("---"):
        return {}, content

    parts = content.split("---", 2)
    if len(parts) < 3:
        return {}, content

    frontmatter_text = parts[1]
    body = parts[2].lstrip()

    metadata = {}
    for line in frontmatter_text.strip().split("\n"):
        line = line.strip()
        if ":" in line and not line.startswith("#"):
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip().strip("'").strip('"')
            metadata[key] = value

    return metadata, body


def convert_nikola_date_to_nicolino(date_str: str) -> str:
    """Convert Nikola date format to Nicolino filename date.

    Nikola formats:
    - 2012/03/04 17:40
    - 2015-05-13 02:31:11 UTC
    Nicolino: 2012-03-04
    """
    if not date_str:
        return "0000-00-00"

    # Clean up the date string - remove timezone info and T separator
    date_str_clean = date_str.replace("UTC", "").replace("GMT", "").replace("T", " ").strip()

    # Try various date formats
    formats_to_try = [
        "%Y-%m-%d %H:%M:%S%z",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y/%m/%d %H:%M:%S",
        "%Y/%m/%d %H:%M",
        "%y/%m/%d %H:%M:%S",
        "%y/%m/%d %H:%M",
        "%Y/%m/%d",
        "%Y-%m-%d",
    ]

    for fmt in formats_to_try:
        try:
            dt = datetime.strptime(date_str_clean, fmt)
            return dt.strftime("%Y-%m-%d")
        except ValueError:
            continue

    return "0000-00-00"


def sanitize_slug(slug: str) -> str:
    """Convert slug to a safe filename."""
    if not slug:
        return "untitled"
    # Remove leading BB if present (from BB1001)
    slug = re.sub(r'^BB', '', slug)
    # Convert to lowercase, replace spaces with hyphens
    slug = slug.lower().replace(' ', '-')
    # Remove non-alphanumeric chars except hyphen
    slug = re.sub(r'[^a-z0-9-]', '', slug)
    # Remove multiple consecutive hyphens
    slug = re.sub(r'-+', '-', slug)
    # Remove leading/trailing hyphens
    slug = slug.strip('-')
    return slug or "untitled"


def determine_extension(filename: str) -> str:
    """Determine the file extension based on filename."""
    if filename.endswith(".md"):
        return ".md"
    if filename.endswith(".html"):
        return ".html"
    if filename.endswith(".rst"):
        return ".rst"
    # Default .txt files are restructuredtext
    return ".rst"


def convert_frontmatter_to_nicolino(metadata: dict, content: str) -> str:
    """Convert Nikola frontmatter to Nicolino format.

    Nicolino uses:
    - title: required
    - date: required, format YYYY-MM-DD
    - tags: optional, comma-separated
    - draft: optional
    """
    title = metadata.get("title", "Untitled")
    date_str = metadata.get("date", "")
    tags = metadata.get("tags", "")

    # Convert date
    nicolino_date = convert_nikola_date_to_nicolino(date_str)

    # Build Nicolino frontmatter
    frontmatter_lines = [
        "---",
        f'title: "{title}"',
        f"date: {nicolino_date}",
    ]

    if tags:
        # Tags are comma-separated in Nikola - keep as quoted string to handle special chars
        # Remove markdown bold (***) syntax from tags if present
        tags_clean = tags.replace("**", "").replace("*", "")
        frontmatter_lines.append(f'tags: [{tags_clean}]')

    frontmatter_lines.append("---")
    frontmatter_lines.append("")

    return "\n".join(frontmatter_lines) + content


def process_file(source_file: Path, target_dir: Path, is_translation: bool = False) -> Optional[Path]:
    """Process a single post file and convert it to Nicolino format."""
    # Skip comment files and metadata files
    if "wpcomment" in source_file.name or ".meta." in source_file.name:
        return None

    # Skip subdirectories for now (goodreads, youtube, etc.)
    if source_file.is_dir():
        return None

    content = source_file.read_text(encoding="utf-8", errors="ignore")
    metadata, body = parse_frontmatter(content)

    if not metadata:
        print(f"Warning: No frontmatter found in {source_file.name}, skipping")
        return None

    # Preserve original filename to maintain output paths
    # Just change extension if needed
    ext = determine_extension(source_file.name)
    filename = source_file.stem + ext

    target_file = target_dir / filename

    # Convert frontmatter
    new_content = convert_frontmatter_to_nicolino(metadata, body)

    # Write to target
    target_file.write_text(new_content, encoding="utf-8")
    return target_file


def main():
    """Main migration function."""
    # Create target directories
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    TARGET_ES_DIR.mkdir(parents=True, exist_ok=True)

    # Process all files in source directory
    processed_count = 0
    skipped_count = 0

    for source_file in SOURCE_DIR.iterdir():
        if not source_file.is_file():
            continue

        # Check if this is a Spanish translation
        is_es = source_file.name.endswith(".es.txt") or source_file.name.endswith(".es.md")

        if is_es:
            target_file = process_file(source_file, TARGET_ES_DIR, is_translation=True)
        elif source_file.name.endswith((".txt", ".md", ".rst", ".html")):
            target_file = process_file(source_file, TARGET_DIR, is_translation=False)
        else:
            skipped_count += 1
            continue

        if target_file:
            processed_count += 1
            print(f"Processed: {source_file.name} -> {target_file}")
        else:
            skipped_count += 1

    print(f"\nMigration complete!")
    print(f"Processed: {processed_count} posts")
    print(f"Skipped: {skipped_count} files")


if __name__ == "__main__":
    main()
