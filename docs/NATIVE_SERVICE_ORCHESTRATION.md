# Native Service Orchestration Plan

LAN Arcade now has three kinds of larger game entries:

1. Static research mirrors, such as 0 A.D., Wesnoth, OpenTTD, FreeCol, and Stendhal website/wiki mirrors.
2. Native-client games where the arcade stores installers/manuals but the game runs on each phone or computer.
3. Native services where GannanNet or the camping Pi hosts a server, such as Mindustry and Unciv.

The admin model should treat these differently. Browser games can be always available. Heavy native services should be explicit, on-demand, observable, and smoke-tested one at a time.

## Service Registry

Use `config/native-services.json` as the allowlisted source of truth. Each entry records:

- catalog hub path
- service tier
- compose file or cached artifacts
- ports
- data directory
- health check expectation
- last smoke report
- admin state: `startable`, `research`, or `candidate`

Future admin UI/API work should read from this registry. It must not accept arbitrary shell commands from the browser.

## One-At-A-Time Rule

Default policy: only one heavy service should run or smoke-test at a time on Pi-class hardware. Use a lock such as:

```text
/tmp/lan-arcade-native-service-smoke.lock
```

A smoke executor should refuse to start if another heavy smoke is active, unless the operator explicitly overrides it from the shell.

## Admin Controls

The eventual admin page should expose safe actions per service:

- `Status`: show installed/cached/running/smoke status.
- `Start`: run the allowlisted compose/systemd start command.
- `Stop`: run the allowlisted compose/systemd stop command.
- `Smoke Test`: start service, run health/client loop, write report, then stop unless marked keep-running.
- `Logs`: show the tail of the service log with secrets redacted.

The API should return job IDs for long operations. The page should poll job status rather than holding a request open.

## Smoke Test Rules

A native-service smoke is not just HTTP 200. It should prove the game-specific loop:

- Mindustry: container starts, valid map loads, port 6567 opens, logs do not show bad map/start errors.
- Unciv: `/isalive` works, auth registration works, file upload/download works, wrong-password overwrite is rejected.
- OpenTTD future: dedicated server starts, a test map loads, port opens, one client can see/connect.
- Stendhal future: local server starts, Java/Android clients can connect, a test account can enter the world.
- Veloren future: server starts, client version matches, login/world join smoke passes, resource use is recorded.

Each smoke writes to `qa/reports/service-smoke/` and records memory use, ports, logs, and cleanup state.

## Current Status

- `mindustry-lan`: startable Docker service; VM smoke passed; server-compatible desktop/server JAR shelf and docs mirror cached under `/mirrors/games/downloads/native/mindustry/` and `/mirrors/mindustry-docs/`.
- `unciv-lan`: startable Docker service; auth/file-loop smoke passed.
- `openttd-lan`: Debian packages installed; dedicated server TCP smoke passed; VM client launch screenshot passed; Windows/Linux/macOS clients plus OpenGFX/OpenSFX/OpenMSX cached; real client join/play pending.
- `freeciv-lan`: Debian server/client installed; server TCP smoke passed; VM GTK client launch screenshot passed; Windows/Linux packages cached; real client join/play pending.
- `wesnoth-lan`: Debian server package installed; server TCP smoke passed; Windows/macOS installers cached; native client install/launch and lobby join pending.
- `stendhal-lan`: client ZIP and Android APK found; ZIP integrity smoke passed; local server smoke pending.
- `freecol-lan`: website/manual mirror found; Windows/macOS/Java/ZIP release files cached; Java release launch smoke pending.
- `zero-ad-lan`: mirror found; Release 28 Windows/Linux/macOS clients cached; client installer/LAN smoke pending; Debian data package is heavy, so test later.
- `veloren-lan`: Airshipper launchers for Windows/Linux/macOS plus Linux server binary cached; current Linux binary is blocked on Debian 12 glibc 2.38/2.39 and full game profile caching is still pending, so do not call it play-ready.

See `docs/NATIVE_GAME_TESTING.md` for the testing ladder and exact report paths.

## Implementation Path

1. Add a shell executor that reads `config/native-services.json` and supports `list`, `status`, `start`, `stop`, and `smoke` for allowlisted services only.
2. Wire Mindustry and Unciv first because their compose files and smoke expectations already exist.
3. Add an admin API wrapper with authentication and a job queue.
4. Add UI controls to the admin page and service hub pages.
5. Promote Stendhal/OpenTTD/Veloren only after each has its own repeatable smoke script.
