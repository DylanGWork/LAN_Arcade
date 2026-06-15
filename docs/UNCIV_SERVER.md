# Unciv LAN Server

Unciv is the lighter "fancier strategy" option for LAN Arcade. Each phone or
desktop runs the Unciv client locally, while GannanNet or the camping Pi stores
and serves multiplayer turn files over HTTP.

That split is friendly to small hardware: the server is not rendering a web
game, simulating browsers, or running a large database stack. The important
offline requirement is that LAN Arcade must also cache the client installers,
not merely tell players to fetch them from the internet later.

## Files

```text
services/unciv/Dockerfile
services/unciv/entrypoint.sh
deploy/unciv.compose.yml
scripts/cache_unciv_offline_assets.py
local-games/unciv-lan/index.html
```

The container downloads `UncivServer.jar` during image build, then runs without
internet access. Current Unciv server releases require Java 21, so the container
uses a Java 21 runtime even if the host VM only has Java 17 installed.

## Cached Offline Assets

Run this from the repo root while internet is available:

```sh
scripts/cache_unciv_offline_assets.py
```

Current cached release on GannanNet:

```text
Version: 4.20.13
Downloads: /var/www/html/mirrors/games/downloads/native/unciv/
Docs:      /var/www/html/mirrors/unciv-docs/
```

The cache includes:

```text
Unciv-signed.apk
Unciv.msi
Unciv-Windows64.zip
Unciv-Linux64.zip
Unciv.jar
UncivServer.jar
linuxFilesForJar.zip
SHA256SUMS.txt
manifest.json
```

The Unciv hub links to the stable local paths under:

```text
/mirrors/games/downloads/native/unciv/latest/
```

Do not store these large binaries in Git.

## Build And Run

From the repo root:

```sh
docker compose -f deploy/unciv.compose.yml build
docker compose -f deploy/unciv.compose.yml up -d
```

Server data is stored at:

```text
/var/lib/lan-arcade/unciv
```

The container runs as UID/GID `10002`, so the host data directory must be
writable by that ID:

```sh
sudo mkdir -p /var/lib/lan-arcade/unciv
sudo chown -R 10002:10002 /var/lib/lan-arcade/unciv
```

Default LAN URL on GannanNet:

```text
http://192.168.1.106:8090
```

In each Unciv client, open multiplayer settings and use the LAN URL as the
multiplayer server.

## Tuning

The default container does not set a JVM maximum heap. For the Raspberry Pi 4,
start conservatively:

```sh
UNCIV_JAVA_OPTS="-Xms64m -Xmx256m" \
docker compose -f deploy/unciv.compose.yml up -d --build
```

Raise the heap only if the server logs show memory pressure with real players.

## Current VM Smoke Result

The container starts successfully with Java 21 and
`UNCIV_JAVA_OPTS="-Xms64m -Xmx256m"`. The Unciv client connection endpoint is:

```text
GET /isalive
```

VM load smoke:

```text
Image size:                     about 331 MB
Idle container memory:          about 127 MiB
After 500 /isalive requests:    about 137 MiB
Request result:                 500/500 HTTP 200
```

Raw reports:

```text
qa/reports/strategy-spike/unciv-load.json
qa/reports/service-smoke/unciv-on-demand-20260613T184532Z.json
```

The 2026-06-13 on-demand smoke initially failed because the host data directory
was root-owned. After `chown -R 10002:10002 /var/lib/lan-arcade/unciv`,
`/isalive` returned HTTP 200 and the container was stopped cleanly.

VM file-loop smoke on 2026-06-14 against `http://127.0.0.1:8090`:

```text
/isalive:                         HTTP 200, authVersion=1, chatVersion=1
Fresh UUID auth before set:       HTTP 204
Set password:                     HTTP 200 (`PUT /auth` body is the new password)
Correct auth after set:           HTTP 200
Wrong password auth:              HTTP 401
PUT /files/<qa-file>:             HTTP 200
GET /files/<qa-file>:             HTTP 200, content matched
Wrong-password overwrite:         HTTP 401, original content preserved
Idle/test memory:                 about 132 MiB
```

Raw report:

```text
qa/reports/service-smoke/unciv-file-loop-final-20260614T001555Z.json
```

## Offline Checklist

- Cache the Unciv release files and docs with `scripts/cache_unciv_offline_assets.py`.
- Build the Docker image before leaving internet.
- Open `/mirrors/unciv-lan/` and verify Android/Windows/Linux client downloads are served locally.
- Start the container and confirm a client can check/connect to the LAN URL.
- Test at least one complete create-game, upload-turn, and download-turn loop offline.
- Keep the large release files outside Git under `/var/www/html/mirrors/games/downloads/native/unciv/`.

## Sources

- Unciv source and releases: https://github.com/yairm210/Unciv
- Unciv official docs: https://yairm210.github.io/Unciv/
- Unciv multiplayer docs: https://yairm210.github.io/Unciv/Other/Multiplayer/
