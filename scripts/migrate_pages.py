#!/usr/bin/env python3
"""
Migrate Nikola pages to Nicolino format.

Pages in Nikola go to stories/, in Nicolino they go in content/ root.
"""

import os
import sys
from datetime import datetime
from pathlib import Path

# Paths
SOURCE_DIR = Path("mysite/pages")
TARGET_DIR = Path("myblog/content")
TARGET_ES_DIR = Path("myblog/content/es")


def parse_frontmatter(content: str):
    """Parse YAML frontmatter from content."""
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

    # Clean up the date string - remove timezone info
    date_str_clean = date_str.replace("UTC", "").replace("GMT", "").strip()

    # Try various date formats
    formats_to_try = [
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y/%m/%d %H:%M:%S",
        "%Y/%m/%d %H:%M",
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
    slug = slug.lower().replace(' ', '-')
    slug = slug.replace('/', '-')
    return slug or "untitled"


def determine_extension(filename: str) -> str:
    """Determine the file extension based on filename."""
    if filename.endswith(".md"):
        return ".md"
    if filename.endswith(".html"):
        return ".html"
    if filename.endswith(".rst"):
        return ".rst"
    return ".rst"


def convert_frontmatter_to_nicolino(metadata: dict, content: str) -> str:
    """Convert Nikola frontmatter to Nicolino format."""
    title = metadata.get("title", "Untitled")
    date_str = metadata.get("date", "")
    tags = metadata.get("tags", "")

    nicolino_date = convert_nikola_date_to_nicolino(date_str)

    frontmatter_lines = [
        "---",
        f'title: "{title}"',
        f"date: {nicolino_date}",
    ]

    if tags:
        frontmatter_lines.append(f"tags: [{tags}]")

    frontmatter_lines.append("---")
    frontmatter_lines.append("")

    return "\n".join(frontmatter_lines) + content


def process_file(source_file: Path, target_dir: Path, is_translation: bool = False):
    """Process a single page file and convert it to Nicolino format."""
    if "wpcomment" in source_file.name or ".meta." in source_file.name:
        return None

    if source_file.is_dir():
        return None

    content = source_file.read_text(encoding="utf-8", errors="ignore")
    metadata, body = parse_frontmatter(content)

    if not metadata:
        print(f"Warning: No frontmatter found in {source_file.name}, skipping")
        return None

    slug = metadata.get("slug", "")
    ext = determine_extension(source_file.name)

    # For pages, we use just the slug or the original name
    file_slug = sanitize_slug(slug)
    if not file_slug or file_slug == "untitled":
        # Use original filename without extension
        file_slug = source_file.stem

    filename = f"{file_slug}{ext}"

    target_file = target_dir / filename

    new_content = convert_frontmatter_to_nicolino(metadata, body)
    target_file.write_text(new_content, encoding="utf-8")
    return target_file


def main():
    """Main migration function."""
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    TARGET_ES_DIR.mkdir(parents=True, exist_ok=True)

    processed_count = 0
    skipped_count = 0

    for source_file in SOURCE_DIR.iterdir():
        if not source_file.is_file():
            continue

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
    print(f"Processed: {processed_count} pages")
    print(f"Skipped: {skipped_count} files")


if __name__ == "__main__":
    main()
