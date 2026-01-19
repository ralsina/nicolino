Check all in-site links for broken references.

## Usage

```text
{{% shell command="bin/nicolino check_links --help" %}}
```

## Description

Scans all HTML files in the output directory and verifies that
internal links point to existing files. This is useful when
porting a site to ensure no links were broken in the process.

External links (http://, https://, mailto:, etc.) are skipped.
Anchors (same-page links starting with #) are also skipped.
