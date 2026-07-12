#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR=${BROWSER_STREAM_CACHE_DIR:-/srv/lan-arcade/native-downloads/browser-stream/debian-bookworm-amd64}
IMAGE=${BROWSER_STREAM_BASE_IMAGE:-node:24-bookworm-slim}
STAGE=$(mktemp -d /tmp/lan-arcade-browser-stream-cache.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT

packages=(
  ace-of-penguins btanks freedroidrpg liquidwar novnc openbox procps scrot
  sopwith tuxmath websockify x11-utils x11vnc xdotool xvfb
)

mkdir -p "$CACHE_DIR"

docker run --rm \
  --network bridge \
  --env "HOST_UID=$(id -u)" --env "HOST_GID=$(id -g)" \
  --mount "type=bind,src=$STAGE,dst=/cache" \
  "$IMAGE" \
  bash -ec '
    apt-get update
    apt-get -y --download-only \
      -o APT::Install-Recommends=false \
      -o Dir::Cache::archives=/cache \
      install "$@"
    chown -R "$HOST_UID:$HOST_GID" /cache
  ' browser-stream-cache "${packages[@]}"

find "$STAGE" -maxdepth 1 -type f -name '*.deb' -exec chmod 0644 {} +
rsync -a --ignore-existing "$STAGE/" "$CACHE_DIR/"
(
  cd "$CACHE_DIR"
  dpkg-scanpackages --multiversion . /dev/null >Packages
  gzip -9c Packages >Packages.gz
  sha256sum ./*.deb Packages Packages.gz >SHA256SUMS
)

printf 'Cached %s packages (%s) in %s\n' \
  "$(find "$CACHE_DIR" -maxdepth 1 -type f -name '*.deb' | wc -l)" \
  "$(du -sh "$CACHE_DIR" | awk '{print $1}')" \
  "$CACHE_DIR"
