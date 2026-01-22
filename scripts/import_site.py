#!/usr/bin/env python3
"""
Complete site import from Nikola to Nicolino.

This script handles:
- Posts (blog posts with dates)
- Pages (static content)
- Galleries (image galleries)
- Images (from galleries and images folder)
- Files (static assets)
- Listings (code listings with syntax highlighting)

Uses cached HTML when available for non-markdown formats.

Usage:
    cd /path/to/nicolino
    python3 scripts/import_site.py
"""

import os
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple, List

# =============================================================================
# Configuration
# =============================================================================

# Source directories (Nikola site)
SOURCE_DIR = Path("mysite")
SOURCE_POSTS = SOURCE_DIR / "posts"
SOURCE_PAGES = SOURCE_DIR / "pages"
SOURCE_GALLERIES = SOURCE_DIR / "galleries"
SOURCE_IMAGES = SOURCE_DIR / "images"
SOURCE_FILES = SOURCE_DIR / "files"
SOURCE_LISTINGS = SOURCE_DIR / "listings"
SOURCE_PYTUT = SOURCE_DIR / "pytut"
SOURCE_CACHE = SOURCE_DIR / "cache"

# Target directories (Nicolino site)
TARGET_DIR = Path("myblog")
TARGET_CONTENT = TARGET_DIR / "content"
TARGET_POSTS = TARGET_CONTENT / "posts"
TARGET_ES_POSTS = TARGET_CONTENT / "es" / "posts"
TARGET_ES_CONTENT = TARGET_CONTENT / "es"
TARGET_GALLERIES = TARGET_CONTENT / "galleries"
TARGET_IMAGES = TARGET_CONTENT / "images"
TARGET_LISTINGS = TARGET_CONTENT / "listings"
TARGET_PYTUT = TARGET_CONTENT / "pytut"

# =============================================================================
# Utility Functions
# =============================================================================


def parse_frontmatter(content: str) -> Tuple[dict, str]:
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
    """Convert Nikola date format to Nicolino filename date."""
    if not date_str:
        return "0000-00-00"

    date_str_clean = date_str.replace("UTC", "").replace("GMT", "").replace("T", " ").strip()

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
    slug = re.sub(r'^BB', '', slug)
    slug = slug.lower().replace(' ', '-').replace('/', '-')
    slug = re.sub(r'[^a-z0-9-]', '', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug.strip('-') or "untitled"


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
        tags_clean = tags.replace("**", "").replace("*", "")
        frontmatter_lines.append(f'tags: [{tags_clean}]')

    frontmatter_lines.append("---")
    frontmatter_lines.append("")

    return "\n".join(frontmatter_lines) + content


def get_cached_html(source_file: Path, is_es: bool = False) -> Optional[str]:
    """Get cached HTML from Nikola cache if available.

    Returns the HTML content wrapped in raw tags to prevent shortcode reprocessing,
    or None if no cache exists.
    """
    # Build cache path
    # pages/26.txt -> cache/pages/26.html
    # pages/26.txt.es -> cache/pages/26.es.html
    stem = source_file.stem  # e.g., "26" from "26.txt"

    # Determine the cache subdirectory and filename
    rel_path = source_file.relative_to(SOURCE_DIR)
    cache_dir = SOURCE_CACHE / rel_path.parent

    if is_es:
        cache_file = cache_dir / f"{stem}.es.html"
    else:
        cache_file = cache_dir / f"{stem}.html"

    if not cache_file.exists():
        return None

    # Read the cached HTML
    try:
        html_content = cache_file.read_text(encoding="utf-8")

        # Wrap in raw shortcode tags to prevent reprocessing
        # The cached HTML may have {{ shortcodes }} that were already processed
        # We use {% raw %}...{% endraw %} to preserve them
        wrapped = "{% raw %}\n" + html_content + "\n{% endraw %}"

        return wrapped
    except Exception as e:
        print(f"    Warning: Could not read cache {cache_file}: {e}")
        return None


# =============================================================================
# Posts Migration
# =============================================================================


def process_post_file(source_file: Path, target_dir: Path) -> Optional[Path]:
    """Process a single post file and convert it to Nicolino format."""
    if "wpcomment" in source_file.name or ".meta." in source_file.name:
        return None
    if source_file.is_dir():
        return None

    # Check if this is a translation
    is_es = source_file.name.endswith((".es.txt", ".es.md", ".es.rst", ".es.html"))

    content = source_file.read_text(encoding="utf-8", errors="ignore")
    metadata, body = parse_frontmatter(content)

    if not metadata:
        print(f"  Warning: No frontmatter in {source_file.name}, skipping")
        return None

    # Check if we can use cached HTML (for non-markdown files)
    cached_html = None
    if not source_file.name.endswith(".md"):
        cached_html = get_cached_html(source_file, is_es)
        if cached_html:
            print(f"    Using cached HTML from cache")
            body = cached_html

    # Preserve original filename to maintain output paths
    # Change extension to .html if using cached content, .md for markdown
    if cached_html:
        # If we have cached HTML, save as .html file with HTML content
        ext = ".html"
    else:
        ext = determine_extension(source_file.name)

    filename = source_file.stem + ext
    target_file = target_dir / filename

    # Convert frontmatter
    new_content = convert_frontmatter_to_nicolino(metadata, body)

    # Write to target
    target_file.write_text(new_content, encoding="utf-8")
    return target_file


def migrate_posts():
    """Migrate all blog posts."""
    print("\n" + "="*60)
    print("MIGRATING POSTS")
    print("="*60)

    if not SOURCE_POSTS.exists():
        print(f"  Source directory not found: {SOURCE_POSTS}")
        return

    TARGET_POSTS.mkdir(parents=True, exist_ok=True)
    TARGET_ES_POSTS.mkdir(parents=True, exist_ok=True)

    processed = 0
    skipped = 0

    for source_file in SOURCE_POSTS.iterdir():
        if not source_file.is_file():
            continue

        is_es = source_file.name.endswith((".es.txt", ".es.md", ".es.rst", ".es.html"))

        if is_es:
            target_file = process_post_file(source_file, TARGET_ES_POSTS)
        elif source_file.name.endswith((".txt", ".md", ".rst", ".html")):
            target_file = process_post_file(source_file, TARGET_POSTS)
        else:
            skipped += 1
            continue

        if target_file:
            processed += 1
            print(f"  {source_file.name} -> {target_file.relative_to(TARGET_DIR)}")
        else:
            skipped += 1

    print(f"\n  Processed: {processed} posts")
    print(f"  Skipped: {skipped} files")


# =============================================================================
# Pages Migration
# =============================================================================


def process_page_file(source_file: Path, target_dir: Path) -> Optional[Path]:
    """Process a single page file."""
    if "wpcomment" in source_file.name or ".meta." in source_file.name:
        return None
    if source_file.is_dir():
        return None

    # Check if this is a translation
    is_es = source_file.name.endswith((".es.txt", ".es.md", ".es.rst", ".es.html"))

    content = source_file.read_text(encoding="utf-8", errors="ignore")
    metadata, body = parse_frontmatter(content)

    if not metadata:
        print(f"  Warning: No frontmatter in {source_file.name}, skipping")
        return None

    # Check if we can use cached HTML (for non-markdown files)
    cached_html = None
    if not source_file.name.endswith(".md"):
        cached_html = get_cached_html(source_file, is_es)
        if cached_html:
            print(f"    Using cached HTML from cache")
            body = cached_html

    # Preserve original filename
    # Change extension to .html if using cached content, .md for markdown
    if cached_html:
        ext = ".html"
    else:
        ext = determine_extension(source_file.name)

    file_slug = sanitize_slug(metadata.get("slug", ""))
    if not file_slug or file_slug == "untitled":
        file_slug = source_file.stem

    filename = f"{file_slug}{ext}"
    target_file = target_dir / filename

    new_content = convert_frontmatter_to_nicolino(metadata, body)
    target_file.write_text(new_content, encoding="utf-8")
    return target_file


def migrate_pages():
    """Migrate all pages."""
    print("\n" + "="*60)
    print("MIGRATING PAGES")
    print("="*60)

    if not SOURCE_PAGES.exists():
        print(f"  Source directory not found: {SOURCE_PAGES}")
        return

    TARGET_CONTENT.mkdir(parents=True, exist_ok=True)
    TARGET_ES_CONTENT.mkdir(parents=True, exist_ok=True)

    processed = 0
    skipped = 0

    for source_file in SOURCE_PAGES.iterdir():
        if not source_file.is_file():
            continue

        is_es = source_file.name.endswith((".es.txt", ".es.md", ".es.rst", ".es.html"))

        if is_es:
            target_file = process_page_file(source_file, TARGET_ES_CONTENT)
        elif source_file.name.endswith((".txt", ".md", ".rst", ".html")):
            target_file = process_page_file(source_file, TARGET_CONTENT)
        else:
            skipped += 1
            continue

        if target_file:
            processed += 1
            print(f"  {source_file.name} -> {target_file.relative_to(TARGET_DIR)}")
        else:
            skipped += 1

    print(f"\n  Processed: {processed} pages")
    print(f"  Skipped: {skipped} files")


# =============================================================================
# Galleries Migration
# =============================================================================


def convert_gallery_index(index_file: Path):
    """Convert a gallery index.txt to index.md."""
    if not index_file.exists():
        return

    content = index_file.read_text(encoding="utf-8")

    # Parse Nikola metadata format
    title = "Gallery"
    title_match = re.search(r'\.\.\s*title:\s*(.+)', content)
    if title_match:
        title = title_match.group(1).strip()

    # Remove Nikola metadata lines
    lines = []
    for line in content.split("\n"):
        if not line.strip().startswith(".."):
            lines.append(line)

    body_content = "\n".join(lines).strip()

    new_content = f"""---
title: "{title}"
date: 2024-01-01
---

{body_content}
"""

    output_file = index_file.parent / "index.md"
    output_file.write_text(new_content, encoding="utf-8")
    index_file.unlink()

    return output_file


def migrate_galleries():
    """Migrate galleries."""
    print("\n" + "="*60)
    print("MIGRATING GALLERIES")
    print("="*60)

    if not SOURCE_GALLERIES.exists():
        print(f"  Source directory not found: {SOURCE_GALLERIES}")
        return

    TARGET_GALLERIES.mkdir(parents=True, exist_ok=True)

    # Copy gallery directories and convert index files
    processed = 0

    for item in SOURCE_GALLERIES.iterdir():
        if item.is_dir():
            # Copy the entire gallery directory
            target_gallery = TARGET_GALLERIES / item.name
            if target_gallery.exists():
                shutil.rmtree(target_gallery)
            shutil.copytree(item, target_gallery)

            # Convert index.txt if present
            index_txt = target_gallery / "index.txt"
            index_es_txt = target_gallery / "index.es.txt"

            if index_txt.exists():
                convert_gallery_index(index_txt)
                processed += 1
                print(f"  {item.name}/index.txt -> index.md")

            if index_es_txt.exists():
                convert_gallery_index(index_es_txt)
                processed += 1
                print(f"  {item.name}/index.es.txt -> index.es.md")

    print(f"\n  Processed: {processed} gallery indexes")


# =============================================================================
# Images Migration
# =============================================================================


def migrate_images():
    """Migrate images from galleries and images folder."""
    print("\n" + "="*60)
    print("MIGRATING IMAGES")
    print("="*60)

    TARGET_IMAGES.mkdir(parents=True, exist_ok=True)
    copied = 0

    # Copy from images/ folder if it exists
    if SOURCE_IMAGES.exists():
        for img_file in SOURCE_IMAGES.rglob("*"):
            if img_file.is_file():
                rel_path = img_file.relative_to(SOURCE_IMAGES)
                target_file = TARGET_IMAGES / rel_path
                target_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(img_file, target_file)
                copied += 1

    print(f"  Copied: {copied} image files")


# =============================================================================
# Files Migration (Static Assets)
# =============================================================================


def migrate_files():
    """Migrate static files to assets/."""
    print("\n" + "="*60)
    print("MIGRATING STATIC FILES (ASSETS)")
    print("="*60)

    if not SOURCE_FILES.exists():
        print(f"  Source directory not found: {SOURCE_FILES}")
        return

    target_assets = TARGET_DIR / "assets"
    target_assets.mkdir(parents=True, exist_ok=True)

    # Copy entire files directory to assets
    if target_assets.exists():
        # Only copy contents, don't remove assets if it has other stuff
        for item in SOURCE_FILES.iterdir():
            target_item = target_assets / item.name
            if target_item.exists():
                if target_item.is_dir():
                    shutil.rmtree(target_item)
                else:
                    target_item.unlink()
            if item.is_dir():
                shutil.copytree(item, target_item)
            else:
                shutil.copy2(item, target_item)

    print(f"  Copied: files/ -> assets/")


# =============================================================================
# Listings Migration (Code Listings)
# =============================================================================


def migrate_listings():
    """Migrate code listings."""
    print("\n" + "="*60)
    print("MIGRATING CODE LISTINGS")
    print("="*60)

    if not SOURCE_LISTINGS.exists():
        print(f"  Source directory not found: {SOURCE_LISTINGS}")
        return

    TARGET_LISTINGS.mkdir(parents=True, exist_ok=True)

    processed = 0
    for listing_file in SOURCE_LISTINGS.glob("*.py"):
        target_file = TARGET_LISTINGS / listing_file.name
        shutil.copy2(listing_file, target_file)
        processed += 1
        print(f"  {listing_file.name}")

    print(f"\n  Copied: {processed} listing files")


# =============================================================================
# Python Tutorial Migration
# =============================================================================


def migrate_pytut():
    """Migrate Python tutorial."""
    print("\n" + "="*60)
    print("MIGRATING PYTHON TUTORIAL")
    print("="*60)

    if not SOURCE_PYTUT.exists():
        print(f"  Source directory not found: {SOURCE_PYTUT}")
        return

    TARGET_PYTUT.mkdir(parents=True, exist_ok=True)

    # Copy tutorial files, excluding sphinx output
    processed = 0
    for tut_file in SOURCE_PYTUT.glob("*.txt"):
        if "sphinx-out" not in str(tut_file):
            target_file = TARGET_PYTUT / tut_file.name
            shutil.copy2(tut_file, target_file)
            processed += 1
            print(f"  {tut_file.name}")

    print(f"\n  Copied: {processed} tutorial files")


# =============================================================================
# Configuration Migration
# =============================================================================


def migrate_config():
    """Copy and adapt configuration."""
    print("\n" + "="*60)
    print("MIGRATING CONFIGURATION")
    print("="*60)

    # Copy the config file if it doesn't exist
    target_conf = TARGET_DIR / "conf.yml"
    if not target_conf.exists():
        default_conf = Path("conf.yml")
        if default_conf.exists():
            shutil.copy2(default_conf, target_conf)
            print(f"  Created: conf.yml")

    print("\n  Note: You may need to manually adjust paths in conf.yml")


# =============================================================================
# Main Entry Point
# =============================================================================


def main():
    """Run the complete site migration."""
    print("\n" + "="*60)
    print("NICOLINO SITE IMPORT")
    print("="*60)
    print(f"\nSource: {SOURCE_DIR.absolute()}")
    print(f"Target: {TARGET_DIR.absolute()}")

    if not SOURCE_DIR.exists():
        print(f"\nError: Source directory not found: {SOURCE_DIR}")
        print("Please ensure 'mysite' directory exists in the nicolino root.")
        return

    # Create target directories
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    TARGET_CONTENT.mkdir(parents=True, exist_ok=True)

    # Run all migrations
    migrate_config()
    migrate_posts()
    migrate_pages()
    migrate_galleries()
    migrate_images()
    migrate_files()
    migrate_listings()
    migrate_pytut()

    print("\n" + "="*60)
    print("IMPORT COMPLETE!")
    print("="*60)
    print("\nNext steps:")
    print("1. Review conf.yml and adjust paths if needed")
    print("2. Run: cd myblog && ../bin/nicolino build")
    print("3. Create compatibility symlinks for old HTML paths:")
    print("   ../scripts/add_compat_symlinks.sh myblog/output")
    print("4. Check the output/ directory for generated files")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()
