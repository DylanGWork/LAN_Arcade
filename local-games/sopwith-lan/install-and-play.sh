#!/bin/sh
set -eu
SERVER_URL="${LAN_ARCADE_URL:-http://gannannet.local}"
REPOSITORY="$SERVER_URL/mirrors/games/downloads/native/intake/open-source-wave1/debian-bookworm-pool"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM
mkdir -p "$TEMP_DIR/lists/partial"
printf 'deb [trusted=yes] %s ./\n' "$REPOSITORY" > "$TEMP_DIR/sources.list"
if command -v sudo >/dev/null 2>&1; then
  SUDO=sudo
elif [ "$(id -u)" -eq 0 ]; then
  SUDO=
else
  echo "This installer needs administrator access. Install sudo or run it as root." >&2
  exit 1
fi
echo "Installing sopwith from GannanNet..."
$SUDO apt-get -o Dir::Etc::sourcelist="$TEMP_DIR/sources.list" -o Dir::Etc::sourceparts="-" -o Dir::State::lists="$TEMP_DIR/lists" -o Acquire::Languages="none" update
$SUDO apt-get -o Dir::Etc::sourcelist="$TEMP_DIR/sources.list" -o Dir::Etc::sourceparts="-" -o Dir::State::lists="$TEMP_DIR/lists" --no-install-recommends install -y "sopwith"
if [ "${LAN_ARCADE_INSTALL_ONLY:-0}" = "1" ]; then
  echo "Sopwith installed successfully."
  exit 0
fi
echo "Starting Sopwith..."
exec /usr/games/sopwith -n
