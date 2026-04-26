# Mindustry LAN Server

Mindustry is the first "bigger than a browser card" Pi-hosted game path for LAN Arcade.
Phones and laptops run the official Mindustry client locally, while the Raspberry Pi hosts
only the dedicated server and world state.

This is a good fit for the Pi 4 because the expensive rendering and controls stay on each
player device. The Pi handles multiplayer coordination.

## Files

```text
services/mindustry/Dockerfile
services/mindustry/entrypoint.sh
deploy/mindustry.compose.yml
```

The container downloads `server-release.jar` during image build, then runs without internet.
The companion app also shows a `Mindustry LAN Server` card with the default connection port.

## Build And Run

From the repo root:

```sh
docker compose -f deploy/mindustry.compose.yml build
docker compose -f deploy/mindustry.compose.yml up -d
```

Server data is stored at:

```text
/var/lib/lan-arcade/mindustry
```

Default LAN port:

```text
6567/tcp
6567/udp
```

On each phone or desktop, install Mindustry before the trip, open Multiplayer, and join:

```text
<pi-ip>:6567
```

## Tuning

Use environment variables at build/run time:

```sh
MINDUSTRY_VERSION=v157.4 \
MINDUSTRY_SERVER_NAME="Camp Mindustry" \
MINDUSTRY_MAP=groundZero \
MINDUSTRY_MODE=survival \
MINDUSTRY_XMX=512m \
docker compose -f deploy/mindustry.compose.yml up -d --build
```

For a Raspberry Pi 4 8 GB, start with `MINDUSTRY_XMX=512m`.
Raise it only if the server logs show memory pressure.

## Offline Checklist

- Build the image before leaving internet.
- Start the container once on the Pi and confirm it hosts a game.
- Connect at least one Android phone and one laptop while the router has no internet.
- Keep a copy of the Mindustry APK/installer on the Pi or a USB drive.
- Do not make Mindustry camping-critical until this exact Pi has survived a multiplayer smoke test.

## Sources

- Mindustry server documentation: https://mindustrygame.github.io/wiki/servers/
- Mindustry releases: https://github.com/Anuken/Mindustry/releases
