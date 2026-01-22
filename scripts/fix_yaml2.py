#!/usr/bin/env python3
"""
Fix YAML parsing issues in migrated posts - properly escape quotes.
"""

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

    # Fix title by using YAML literal style if there are quotes
    # Pattern: title: 'text with "quotes' (broken)
    # Replace with: title: "text with \"quotes\""
    lines = frontmatter.split("\n")
    new_lines = []

    for line in lines:
        if line.strip().startswith("title:"):
            # Extract the title value
            if "title: '" in line:
                # Using single quotes - switch to double with escaped quotes
                match = line.split("title: '", 1)
                if len(match) == 2:
                    title_content = match[1].rstrip("'")
                    # Escape double quotes
                    title_escaped = title_content.replace('"', '\\"')
                    new_lines.append(f'title: "{title_escaped}"')
                    continue
            elif 'title: "' in line:
                # Using double quotes - check for unescaped embedded quotes
                match = line.split('title: "', 1)
                if len(match) == 2:
                    rest = match[1]
                    # Find the closing quote
                    if '" ,' in rest:  # Quote followed by comma (tags)
                        title_end = rest.index('" ,')
                        title_content = rest[:title_end]
                        # Escape double quotes
                        title_escaped = title_content.replace('"', '\\"')
                        new_lines.append(f'title: "{title_escaped}",')
                        continue
                    elif rest.endswith('"'):
                        title_content = rest[:-1]
                        # Escape double quotes
                        title_escaped = title_content.replace('"', '\\"')
                        new_lines.append(f'title: "{title_escaped}"')
                        continue
        new_lines.append(line)

    new_frontmatter = "\n".join(new_lines)
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
