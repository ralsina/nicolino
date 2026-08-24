#!/bin/bash
set -e

PKGNAME=$(basename "$PWD")
VERSION=$(git cliff --bumped-version | cut -dv -f2)

# ameba is a dev dependency installed into lib/, not a build target of this
# shard; compile its CLI into bin/ so the lint task (`bin/ameba --fix`) works.
# lib/ may be missing or stale (e.g. after `hace clean` or a static build),
# so refresh it first; shards install is idempotent when it is up to date.
shards install
crystal build lib/ameba/src/cli.cr -o bin/ameba

sed "s/^version:.*$/version: $VERSION/g" -i shard.yml
pre-commit run --all-files -v
hace lint test
hace static
# build_static.sh rebuilds lib/ via docker; shard.lock is tracked, so restore
# the committed version rather than committing whatever the build resolved.
git checkout -- shard.lock
git add shard.yml
# Prepend the new version's changelog section, preserving curated entries
# below (skip if the section was already written by hand).
if ! grep -q "^## \[$VERSION\]" CHANGELOG.md; then
    git cliff --bump --unreleased --prepend CHANGELOG.md
fi
pre-commit run --all-files -v || true
git commit -a -m "chore: bump version to $VERSION"
git tag "v$VERSION"
git push
git push --tags
# Release notes come from the committed changelog's section for this version
# (which may be hand-curated); fall back to git-cliff's latest when absent.
NOTES=$(awk -v v="$VERSION" '
    /^## \[/ { on=0 }
    $0 ~ "^## \\[" v "\\]" { on=1; next }
    on { print }
' CHANGELOG.md)
if [ -z "$NOTES" ]; then
    NOTES=$(git cliff -l -s all)
fi
gh release create "v$VERSION" \
    "bin/$PKGNAME-static-linux-amd64" \
    "bin/$PKGNAME-static-linux-arm64" \
    --title "Release v$VERSION" --notes "$NOTES"
