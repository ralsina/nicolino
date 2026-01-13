#!/usr/bin/env python3
"""
Convert Pandoc files to Markdown to remove Pandoc dependency.

This script:
1. Reads conf.yml to find which file extensions are configured for Pandoc
2. Finds all files with those extensions
3. Converts them to Markdown using pandoc
4. Preserves YAML metadata (separates it before conversion, then restores it)

Usage:
    python scripts/convert_pandoc_to_md.py
    python scripts/convert_pandoc_to_md.py --dry-run
    python scripts/convert_pandoc_to_md.py --content-dir content/posts
"""

import os
import re
import subprocess
import sys
from pathlib import Path

import yaml


def extract_yaml_frontmatter(content):
    """Extract YAML frontmatter from content."""
    if not content.startswith("---"):
        return None, content

    parts = content.split("---\n", 3)
    if len(parts) < 3:
        return None, content

    frontmatter = parts[1]
    remaining_content = parts[2]
    return frontmatter, remaining_content


def convert_pandoc_to_markdown(input_path, dry_run=False):
    """Convert a Pandoc file to Markdown."""
    print(f"Processing: {input_path}")

    content = input_path.read_text()

    # Extract YAML frontmatter
    frontmatter, body_content = extract_yaml_frontmatter(content)

    if frontmatter is None:
        print(f"  ✗ No YAML frontmatter found, skipping")
        return False

    # Convert the body content using pandoc
    try:
        # Use pandoc to convert from the input format to markdown
        result = subprocess.run(
            ["pandoc", "-f", "rst", "-t", "markdown", "--wrap=none"],
            input=body_content,
            capture_output=True,
            text=True,
            timeout=30,
        )

        if result.returncode != 0:
            print(f"  ✗ Pandoc conversion failed: {result.stderr}")
            return False

        markdown_body = result.stdout
    except subprocess.TimeoutExpired:
        print(f"  ✗ Pandoc conversion timed out")
        return False
    except FileNotFoundError:
        print(f"  ✗ Pandoc not found in PATH")
        return False

    # Reconstruct with YAML frontmatter
    new_content = f"---\n{frontmatter}---\n\n{markdown_body}"

    # Determine output path (.md instead of original extension)
    output_path = input_path.with_suffix(".md")

    if dry_run:
        print(f"  [DRY RUN] Would convert to: {output_path}")
        print(f"  [DRY RUN] Content preview: {new_content[:100]}...")
    else:
        # Write the converted markdown
        output_path.write_text(new_content)

        # Remove the original file
        input_path.unlink()

        print(f"  ✓ Converted to: {output_path}")

    return True


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Convert Pandoc files to Markdown")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without making changes",
    )
    parser.add_argument(
        "--content-dir", default="content", help="Content directory (default: content)"
    )
    args = parser.parse_args()

    # Read configuration
    config_path = Path("conf.yml")
    if not config_path.exists():
        print("Error: conf.yml not found in current directory", file=sys.stderr)
        sys.exit(1)

    with open(config_path, "r") as f:
        config = yaml.safe_load(f)

    # Get the formats configuration
    formats = config.get("options", {}).get("formats", {})

    # Find which extensions use Pandoc (rst format)
    pandoc_extensions = []
    for ext, format_name in formats.items():
        if format_name == "rst":
            # Remove the leading dot
            pandoc_extensions.append(ext.lstrip("."))
        elif format_name in ["rst", "markdown", "html"]:
            # Add other pandoc-supported formats if needed
            pandoc_extensions.append(ext.lstrip("."))

    if not pandoc_extensions:
        print("No Pandoc-configured file extensions found in conf.yml", file=sys.stderr)
        sys.exit(1)

    print(f"Found Pandoc extensions: {', '.join(pandoc_extensions)}")

    content_dir = Path(args.content_dir)
    if not content_dir.exists():
        print(f"Error: Content directory '{content_dir}' not found", file=sys.stderr)
        sys.exit(1)

    # Find all files with Pandoc extensions
    files_to_convert = []
    for ext in pandoc_extensions:
        files_to_convert.extend(content_dir.rglob(f"*.{ext}"))

    if not files_to_convert:
        print("No files found to convert")
        sys.exit(0)

    print(f"Found {len(files_to_convert)} file(s) to convert\n")

    # Convert each file
    converted = 0
    skipped = 0

    for file_path in files_to_convert:
        if convert_pandoc_to_markdown(file_path, args.dry_run):
            converted += 1
        else:
            skipped += 1

    print(f"\n{'=' * 60}")
    print(f"Processed {len(files_to_convert)} file(s):")
    print(f"  Converted: {converted}")
    print(f"  Skipped:   {skipped}")

    if not args.dry_run and converted > 0:
        print(f"\n✓ Successfully converted {converted} file(s)")
        print(
            f"\nNote: Don't forget to update conf.yml to remove or change the 'formats' configuration"
        )
        print(f"      and disable the 'pandoc' feature if no longer needed.")


if __name__ == "__main__":
    main()
