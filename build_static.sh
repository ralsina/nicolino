#!/bin/bash
set -e

# Builds statically-linked release binaries inside per-architecture Alpine
# containers. The whole Crystal build runs under QEMU emulation, so this is
# slow; it is meant for release days, when it can just run overnight.
#
# vips is disabled (-Dnovips) because statically linking libvips and its
# huge dependency tree is not practical.

mkdir -p bin

for platform in linux/amd64 linux/arm64; do
    arch="${platform#linux/}"
    tag="nicolino-builder-$arch"
    output="bin/nicolino-static-linux-$arch"

    echo "==> Building $output"
    docker build -q . -f Dockerfile.static --platform "$platform" -t "$tag"
    docker run --rm --platform "$platform" -v "$PWD":/app --user="$(id -u)" "$tag" \
        sh -c "cd /app && rm -rf lib && shards install \
               && shards build --release --static -Dnovips --without-development \
               && strip bin/nicolino"
    mv bin/nicolino "$output"
done

echo "==> Done"
ls -la bin/nicolino-static-linux-*
