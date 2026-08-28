#!/usr/bin/env bash
# Port the next Hugo theme from THEME-TODO.md using opencode.
#
# Picks the first unchecked entry, hands it to `opencode run --auto`
# with the full porting checklist, and lets the agent do the work
# end-to-end (port, build, test, screenshots, registry, showcase,
# commit, push, deploy).
#
# Guards:
#   - refuses to run if the git tree is dirty (a port commit must
#     not sweep in unrelated changes)
#   - refuses if another port is already running (flock)
#
# Usage:  scripts/port-next-theme.sh   (or: hace port-next-theme)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v opencode >/dev/null 2>&1; then
  echo "Error: opencode is not installed (needed for the port agent)." >&2
  exit 1
fi

# Refuse on a dirty tree so the port commit stays clean
if [ -n "$(git status --porcelain)" ]; then
  echo "Error: git tree is dirty; commit or stash before porting a theme." >&2
  git status --short >&2
  exit 1
fi

# One port at a time
exec 9>/tmp/nicolino-port.lock
if ! flock -n 9; then
  echo "Error: another port-next-theme run is already in progress." >&2
  exit 1
fi

# First unchecked theme in THEME-TODO.md, e.g.:
#   "- [ ] loveit (dillonzq/LoveIt, 3,870 stars)"
NEXT="$(grep -m1 '^- \[ \]' THEME-TODO.md || true)"
if [ -z "$NEXT" ]; then
  echo "No unported themes left in THEME-TODO.md."
  exit 0
fi
THEME="$(sed -E 's/^- \[ \] ([^ (]+).*/\1/' <<<"$NEXT")"
REPO="$(sed -E 's/.*\(([^],]+),.*/\1/' <<<"$NEXT")"
echo "🎨 Porting next theme: $THEME ($REPO)"

# Model for the port agent. The global default (glm-4.6) was erroring
# server-side; glm-5.2 is the known-good endpoint. Override with
# PORT_MODEL=... hace port-next-theme
PORT_MODEL="${PORT_MODEL:-zai-coding-plan/glm-5.2}"

exec opencode run --auto --model "$PORT_MODEL" --title "port-$THEME" \
  "Port the Hugo theme $REPO (entry \`$THEME\` in THEME-TODO.md) to Nicolino.

TRANSLATE the original design, never reimagine it. Samey ports come
from writing CSS from generic memory instead of extracting the
original's actual values. So work like a translator:

1. Clone $REPO AND open the original's themes.gohugo.io page
   (https://themes.gohugo.io/themes/$THEME/) for its screenshots
   and demo link.
2. Mine the original for facts before writing anything:
   - layouts: the exact DOM of the header, list item, article meta
     row, footer, pagination (keep the original's class names where
     practical so CSS maps 1:1)
   - styles: real values from its SCSS/CSS or compiled assets --
     color hexes, font stacks and sizes, spacing scale, radii,
     shadows, transitions. If it uses SCSS variables or Tailwind,
     resolve them to concrete values and copy those.
   - icons: which Font Awesome (or other) icons appear where;
     inline the SVG equivalents
3. Write the port from those extracted values. The theme palette
   must literally contain the original's colors (except where
   base16 hooks are required). Do not reuse CSS values, class names
   or markup patterns from other Nicolino themes.

Available data: post values carry link, title, date, summary, html,
toc, taxonomies, metadata, preview_image, has_teaser, word_count,
reading_time, related_posts, language_links, is_fallback. There are
no Hugo widgets, search params or i18n catalogs -- hardcode the
original's English strings where it uses i18n.

Follow docs/theme-porting.md and mirror the structure of themes/blox/
(the most recent hand-checked port). Do the complete job:

1. Port the theme into themes/<name>/ (templates, assets/css,
   theme.yml, LICENSE preserved from the original). Shorten the Hugo
   name sensibly for the directory and registry name, like
   hugo-PaperMod -> papermod and blox-tailwind -> blox. Create the
   demo/themes/<name> symlink too.
2. Wire it everywhere: scripts/build-theme-demos.sh,
   scripts/build-theme-registry.sh, scripts/screenshot-themes.js
   THEMES lists, Hacefile.yml dependency lists, and a card in
   content/pages/themes-showcase.md.
3. Verify: shards build, crystal spec, bin/ameba, demo build in both
   languages, hace screenshots theme-registry, full site build and
   check_links with 0 broken links. Then audit fidelity
   programmatically (you cannot see images): diff the ported CSS's
   hex colors against the original's, and grep the demo HTML for
   the original's signature elements (meta rows, icons, class
   names). Iterate until the audit is clean.
4. Mark it ported in THEME-TODO.md (change \`- [ ] $THEME ...\` to
   \`- [x] <name> ... -- ported\`).
5. Commit all pertinent files (if a pre-commit hook fails, fix the
   issue and retry the commit, never amend), push, then run
   hace deploy and verify the theme is live in /themes.json.

Known traps (also in the porting guide): title.tmpl and post.tmpl
render without the \`theme\` constant; empty strings are truthy in
Crinja; markdownlint enforces line length; never use not_nil!;
dates arrive pre-formatted via the site's date_output_format (the
demo uses a humanized one); code highlighting is server-side via
/css/syntax.css, never ship highlight.js.

If the port cannot be completed successfully, clean the working
tree (git checkout . plus removing any untracked theme dirs you
created), leave the repo as you found it, and report why."
