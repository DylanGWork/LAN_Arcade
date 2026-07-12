#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CACHE_DIR=${BROWSER_STREAM_CACHE_DIR:-/srv/lan-arcade/native-downloads/browser-stream/debian-bookworm-amd64}
IMAGE=${BROWSER_STREAM_IMAGE:-lan-arcade/browser-stream:bookworm}
CONTEXT=$(mktemp -d /tmp/lan-arcade-browser-stream-build.XXXXXX)
trap 'rm -rf "$CONTEXT"' EXIT

for name in Packages Packages.gz; do
  if [[ ! -s "$CACHE_DIR/$name" ]]; then
    printf 'Missing %s. Run cache_packages.sh first.\n' "$CACHE_DIR/$name" >&2
    exit 1
  fi
done

mkdir -p "$CONTEXT/debs" "$CONTEXT/container"
cp "$REPO_ROOT/deploy/browser-stream/Dockerfile" "$CONTEXT/Dockerfile"
cp "$REPO_ROOT/config/browser-stream-games.json" "$CONTEXT/browser-stream-games.json"
cp "$REPO_ROOT/services/browser-stream/container/"*.py "$CONTEXT/container/"
cp "$CACHE_DIR/"*.deb "$CONTEXT/debs/"
cp "$CACHE_DIR/Packages" "$CACHE_DIR/Packages.gz" "$CONTEXT/debs/"

docker build --network none --pull=false --tag "$IMAGE" "$CONTEXT"
docker image inspect "$IMAGE" >/dev/null
printf 'Built %s entirely from the local package cache.\n' "$IMAGE"
