# Unciv LAN Server

Unciv is the lighter "fancier strategy" option for LAN Arcade. Each phone or
desktop runs the Unciv client locally, while the Raspberry Pi stores and serves
the multiplayer turn files over HTTP.

That split is friendly to a Raspberry Pi 4: the Pi is not rendering a web game,
simulating browsers, or running a large database stack.

## Files

```text
services/unciv/Dockerfile
services/unciv/entrypoint.sh
deploy/unciv.compose.yml
```

The container downloads `UncivServer.jar` during image build, then runs without
internet access. Current Unciv server releases require Java 21, so the container
uses a Java 21 runtime even if the host VM only has Java 17 installed.

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

The container runs as UID/GID `10002`, so the host data directory must be writable by that ID:

```sh
sudo mkdir -p /var/lib/lan-arcade/unciv
sudo chown -R 10002:10002 /var/lib/lan-arcade/unciv
```

Default LAN URL:

```text
http://<pi-ip>:8090
```

In each Unciv client, open multiplayer settings and use the Pi URL as the
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

The container starts successfully with Java 21 and `UNCIV_JAVA_OPTS="-Xms64m -Xmx256m"`.
The Unciv client connection endpoint is:

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

The 2026-06-13 on-demand smoke initially failed because the host data directory was root-owned. After `chown -R 10002:10002 /var/lib/lan-arcade/unciv`, `/isalive` returned HTTP 200 and the container was stopped cleanly.

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

- Build the Docker image before leaving internet.
- Install the Unciv app/APK on each phone before the trip.
- Start the container on the Pi and confirm a client can check/connect to the LAN URL.
- Keep a copy of the APK/desktop installer on the Pi or USB storage.
- Test at least one complete create-game, upload-turn, and download-turn loop offline.

## Sources

- Unciv multiplayer server notes: https://github.com/yairm210/Unciv/blob/master/docs/Other/Multiplayer.md
- Unciv releases: https://github.com/yairm210/Unciv/releases
