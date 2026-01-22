#!/usr/bin/env python3
"""
Fix YAML parsing issues in migrated posts.
"""

import re
from pathlib import Path

# Paths
POSTS_DIR = Path("myblog/content/posts")
ES_POSTS_DIR = Path("myblog/content/es/posts")


def fix_yaml_quotes(file_path: Path):
    """Fix YAML quotes in frontmatter."""
    content = file_path.read_text(encoding="utf-8")

    # Check if there's a frontmatter
    if not content.startswith("---"):
        return False

    # Split into frontmatter and body
    parts = content.split("---", 2)
    if len(parts) < 3:
        return False

    frontmatter = parts[1]
    body = parts[2]

    # Fix title with embedded quotes
    # Pattern: title: "text with "quotes" in it"
    # Replace with: title: 'text with "quotes" in it'
    def fix_title(match):
        title_content = match.group(1)
        # Swap single and double quotes
        return f"title: '{title_content}'"

    new_frontmatter = re.sub(
        r'title: "([^"]*"[^"]*)"',  # Matches title with embedded quotes
        fix_title,
        frontmatter
    )

    # If that didn't work (quotes were already mixed), try escaping
    if new_frontmatter == frontmatter:
        # Check for mixed quotes
        if 'title: "' in frontmatter and '"",' in frontmatter:
            # Extract the title and properly escape it
            match = re.search(r'title: "(.+)"', frontmatter)
            if match:
                title_content = match.group(1)
                # Use single quotes for the whole thing
                new_frontmatter = re.sub(
                    r'title: ".+?"',
                    f"title: '{title_content}'",
                    frontmatter
                )

    new_content = f"---{new_frontmatter}---{body}"

    if new_content != content:
        file_path.write_text(new_content, encoding="utf-8")
        print(f"Fixed: {file_path}")
        return True
    return False


def main():
    """Fix all YAML issues in posts."""
    fixed_count = 0

    # Process English posts
    for post_file in POSTS_DIR.glob("*.rst"):
        if fix_yaml_quotes(post_file):
            fixed_count += 1

    for post_file in POSTS_DIR.glob("*.md"):
        if fix_yaml_quotes(post_file):
            fixed_count += 1

    # Process Spanish posts
    for post_file in ES_POSTS_DIR.glob("*.rst"):
        if fix_yaml_quotes(post_file):
            fixed_count += 1

    for post_file in ES_POSTS_DIR.glob("*.md"):
        if fix_yaml_quotes(post_file):
            fixed_count += 1

    print(f"\nFixed {fixed_count} files with YAML issues")


if __name__ == "__main__":
    main()
