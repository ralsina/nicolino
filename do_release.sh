#!/bin/bash
set -e

PKGNAME=$(basename "$PWD")
VERSION=$(git cliff --bumped-version |cut -dv -f2)

sed "s/^version:.*$/version: $VERSION/g" -i shard.yml
pre-commit run --all-files -v
hace lint test
hace static
git add shard.yml
git cliff --bump -o
pre-commit run --all-files -v || true
git commit -a -m "bump: Release v$VERSION"
git tag "v$VERSION"
git push --tags
gh release create "v$VERSION" "bin/$PKGNAME-static-linux-amd64" --title "Release v$VERSION" --notes "$(git cliff -l -s all)"
