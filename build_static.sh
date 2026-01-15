#!/bin/bash
set -e

docker run --rm --privileged \
  multiarch/qemu-user-static \
  --reset -p yes

# Build for AMD64
docker build . -f Dockerfile.static -t nicolino-builder
docker run -ti --rm -v "$PWD":/app --user="$UID" nicolino-builder /bin/sh -c "cd /app && rm -rf lib && shards build -Dnovips --static --release --without-development && strip bin/nicolino"
mv bin/nicolino bin/nicolino-static-linux-amd64

# Build for ARM64
#docker build . -f Dockerfile.static --platform linux/arm64 -t nicolino-builder
#docker run -ti --rm -v "$PWD":/app --platform linux/arm64 --user="$UID" nicolino-builder /bin/sh -c "cd /app && rm -rf lib && shards build -Dnovips --static --release --without-development && strip bin/nicolino"
#mv bin/nicolino bin/nicolino-static-linux-arm64
