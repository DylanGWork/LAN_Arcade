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

- `mindustry-lan`: startable Docker service; VM smoke passed.
- `unciv-lan`: startable Docker service; auth/file-loop smoke passed.
- `stendhal-lan`: client ZIP and Android APK found; local server smoke pending.
- `openttd-lan`: mirror found; installer/server cache pending.
- `zero-ad-lan`: mirror found; client installer/LAN smoke pending.
- `wesnoth-lan`: website/wiki/manual mirror found; installer/hotseat/LAN smoke pending.
- `freecol-lan`: website/manual mirror found; Java release launch smoke pending.
- `veloren-lan`: not found on this VM; treat as a fresh intake candidate.

## Implementation Path

1. Add a shell executor that reads `config/native-services.json` and supports `list`, `status`, `start`, `stop`, and `smoke` for allowlisted services only.
2. Wire Mindustry and Unciv first because their compose files and smoke expectations already exist.
3. Add an admin API wrapper with authentication and a job queue.
4. Add UI controls to the admin page and service hub pages.
5. Promote Stendhal/OpenTTD/Veloren only after each has its own repeatable smoke script.
