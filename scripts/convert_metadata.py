#!/usr/bin/env python3
"""
Convert Nikola metadata format to Nicolino YAML format.

This script uses the same metadata extraction logic from Nikola:
- NikolaMetadata._extract_metadata_from_text() to read Nikola format
- YAMLMetadata.write_metadata() to write YAML format

Nikola format (HTML comment with .. prefix):
<!--
.. title: My Post Title
.. slug: my-post-slug
.. date: 2024-08-02 13:21:11 UTC
.. tags: programming, python
-->

Nicolino format (YAML):
---
title: My Post Title
slug: my-post-slug
date: 2024-08-02 13:21:11 UTC
tags: programming, python
---

Usage:
    python scripts/convert_metadata.py content/posts/file.md
    python scripts/convert_metadata.py content/posts/*.md
    python scripts/convert_metadata.py --dry-run content/posts/*.md
"""

import re
import sys
from pathlib import Path

# From Nikola's NikolaMetadata class
nikola_re = re.compile(r"^\s*\.\. (.*?): (.*)")


def extract_nikola_metadata(source_text: str) -> dict:
    """Extract metadata from Nikola format.

    This is adapted from NikolaMetadata._extract_metadata_from_text()
    https://github.com/getnikola/nikola/blob/master/nikola/metadata_extractors.py
    """
    outdict = {}
    for line in source_text.split("\n"):
        match = nikola_re.match(line)
        if match:
            k, v = match.group(1), match.group(2)
            if v:
                outdict[k] = v
    return outdict


def write_yaml_metadata(metadata: dict) -> str:
    """Write metadata in YAML format.

    This is adapted from YAMLMetadata.write_metadata()
    https://github.com/getnikola/nikola/blob/master/nikola/metadata_extractors.py
    """
    try:
        from ruamel.yaml import YAML

        yaml = YAML(typ="safe")
        yaml.default_flow_style = False

        import io

        stream = io.StringIO()
        yaml.dump(metadata, stream)
        stream.seek(0)
        return "\n".join(("---", stream.read().strip(), "---", ""))
    except ImportError:
        # Fallback if ruamel.yaml is not available
        lines = []
        order = [
            "title",
            "slug",
            "date",
            "tags",
            "category",
            "link",
            "description",
            "type",
        ]

        # Fields that need quoting if they contain special characters
        quote_fields = {"title", "description", "slug"}

        # Add fields in priority order
        for k in order:
            if k in metadata:
                v = metadata[k]
                # Quote if it contains special YAML characters
                if k in quote_fields and any(
                    c in str(v)
                    for c in [
                        ":",
                        "[",
                        "]",
                        "{",
                        "}",
                        "#",
                        "!",
                        "|",
                        ">",
                        "*",
                        "&",
                        "'",
                        '"',
                    ]
                ):
                    lines.append(f'{k}: "{v}"')
                else:
                    lines.append(f"{k}: {v}")

        # Add any remaining fields
        for k in sorted(metadata.keys()):
            if k not in order:
                v = metadata[k]
                if k in quote_fields and any(
                    c in str(v)
                    for c in [
                        ":",
                        "[",
                        "]",
                        "{",
                        "}",
                        "#",
                        "!",
                        "|",
                        ">",
                        "*",
                        "&",
                        "'",
                        '"',
                    ]
                ):
                    lines.append(f'{k}: "{v}"')
                else:
                    lines.append(f"{k}: {v}")

        return "---\n" + "\n".join(lines) + "\n---\n"


def extract_html_comment_metadata(content: str) -> tuple:
    """Extract metadata from HTML comment wrapper and return (metadata, content_start).

    Nikola wraps metadata in HTML comments like:
    <!--
    .. title: Foo
    ..
    -->
    Actual content here
    """
    # Find HTML comment block
    comment_match = re.search(r"<!--\s*\n(.*?)\n-->", content, re.DOTALL)
    if not comment_match:
        return None, 0

    comment_content = comment_match.group(1)
    content_start = comment_match.end() + 1

    # Extract metadata from the comment content
    metadata = extract_nikola_metadata(comment_content)

    return metadata, content_start


def convert_file(file_path: Path, dry_run: bool = False) -> bool:
    """Convert a single file from Nikola to Nicolino format."""
    print(f"Processing: {file_path}")

    content = file_path.read_text()

    # Check if already has YAML metadata (starts with ---)
    if content.startswith("---"):
        print(f"  ✓ Already has YAML metadata, skipping")
        return False

    # Try to extract Nikola metadata from HTML comment
    metadata, content_start = extract_html_comment_metadata(content)

    if not metadata:
        print(f"  ✗ No Nikola metadata found, skipping")
        return False

    # Get the actual content (skip blank lines after HTML comment)
    while content_start < len(content) and content[content_start] in "\n\r\t ":
        content_start += 1

    actual_content = content[content_start:]

    # Build new content with YAML metadata
    yaml_metadata = write_yaml_metadata(metadata)
    new_content = yaml_metadata + "\n" + actual_content

    if dry_run:
        print(f"  [DRY RUN] Would convert with {len(metadata)} metadata fields")
        for k, v in metadata.items():
            print(f"    {k}: {v}")
    else:
        file_path.write_text(new_content)
        print(f"  ✓ Converted successfully")

    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: python convert_metadata.py <file> [file2 ...]", file=sys.stderr)
        print(
            "       python convert_metadata.py --dry-run <file> [file2 ...]",
            file=sys.stderr,
        )
        sys.exit(1)

    dry_run = "--dry-run" in sys.argv
    if dry_run:
        sys.argv.remove("--dry-run")

    files = []
    for arg in sys.argv[1:]:
        path = Path(arg)
        if path.is_dir():
            # Recursively find all markdown, rst, and txt files
            files.extend(path.glob("**/*.md"))
            files.extend(path.glob("**/*.rst"))
            files.extend(path.glob("**/*.txt"))
        else:
            files.append(path)

    if not files:
        print("No files found to process", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(files)} file(s) to process\n")

    converted = 0
    skipped = 0

    for file_path in files:
        if convert_file(file_path, dry_run):
            converted += 1
        else:
            skipped += 1

    print(f"\n{'=' * 60}")
    print(f"Processed {len(files)} file(s):")
    print(f"  Converted: {converted}")
    print(f"  Skipped:   {skipped}")

    if not dry_run and converted > 0:
        print(f"\n✓ Successfully converted {converted} file(s)")


if __name__ == "__main__":
    main()
