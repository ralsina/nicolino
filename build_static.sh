#!/bin/bash
set -e

docker run --rm --privileged \
  multiarch/qemu-user-static \
  --reset -p yes

# Build for AMD64
docker build . -f Dockerfile.static -t nicolino-builder
docker run -ti --rm -v "$PWD":/app --user="$UID" nicolino-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build -Dnovips --release --without-development --static && strip bin/nicolino"
mv bin/nicolino bin/nicolino-static-linux-amd64

# Build for ARM64
docker build . -f Dockerfile.static --platform linux/arm64 -t hace-builder
docker run -ti --rm -v "$PWD":/app --platform linux/arm64 --user="$UID" hace-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build -Dnovips --release --without-development --static && strip bin/nicolino"
mv bin/hace bin/hace-static-linux-arm64
