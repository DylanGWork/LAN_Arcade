# Native Game Testing

Native and server-backed games must not be marked playable just because their hub page returns HTTP 200. Use this ladder when promoting larger games into LAN Arcade.

## Gates

| Gate | Name | What must be proven | Evidence |
| --- | --- | --- | --- |
| 0 | Hub QA | The arcade hub page loads, has meaningful player-facing content, local screenshots/manual/wiki/docs links, no broken local assets, and no runtime internet requests. | `npm run qa:static`, browser smoke screenshots, external-request log. |
| 1 | Artifact/package QA | Required installers, APKs, packages, ROMs, launchers, server jars, or cached archives exist locally and match their expected checksums/license notes. | SHA256 files, package names, archive integrity reports. |
| 2 | Server smoke | The dedicated server starts, opens only expected ports, accepts a basic TCP/protocol connection, records memory, and stops cleanly. | `scripts/native_service_smoke.sh <service-id>` report. |
| 3 | Client launch smoke | A native client launches under Xvfb or another controlled display and produces a nonblank screenshot. | Screenshot plus process/memory report. |
| 4 | Join/play smoke | A real or virtual client joins the local server, enters a map/world/lobby, performs a minimal action, and disconnects. | Logs, screenshots, saved game/lobby state. |
| 5 | Real LAN device smoke | A laptop/phone on the LAN connects using documented player steps. | Dylan/player report plus logs/screenshots. |
| 6 | Offline survival | The game works after internet is disabled or upstream DNS is unavailable. | Network block/offline report. |

## One-at-a-time rule

Heavy native game tests must run one at a time and shut down after the smoke unless an admin explicitly keeps the service running. The smoke lock is:

```text
/tmp/lan-arcade-native-service-smoke.lock
```

The current reusable script is:

```bash
scripts/native_service_smoke.sh <service-id>
```

It records under `qa/reports/service-smoke/` and currently supports `openttd-lan`, `freeciv-lan`, `wesnoth-lan`, `stendhal-lan`, and `veloren-lan`.

## Current evidence, 2026-06-14

| Game | Current status | Evidence | What it does not prove yet |
| --- | --- | --- | --- |
| OpenTTD | Server TCP smoke passed; VM client launch screenshot passed. | `qa/reports/service-smoke/openttd-lan-20260614T053239Z/report.txt`; `qa/reports/native-client-launch/openttd-lan-20260614T054903Z/report.txt`. | A real player joining the server and playing a route. |
| Freeciv | Server TCP smoke passed; VM GTK client launch screenshot passed. | `qa/reports/service-smoke/freeciv-lan-20260614T053247Z/report.txt`; `qa/reports/native-client-launch/freeciv-lan-20260614T054915Z/report.txt`. | A real multi-client game, tutorial start, or LAN client join. |
| Battle for Wesnoth | Server TCP smoke passed. | `qa/reports/service-smoke/wesnoth-lan-20260614T053253Z/report.txt`. | Native client install/launch, hotseat, lobby join, or match play. |
| Stendhal | Cached ZIP integrity passed. | `qa/reports/service-smoke/stendhal-lan-20260614T053259Z/report.txt`. | Local server launch, account creation, or two-client world join. |
| Veloren | Official Airshipper Linux ZIP cached and checksummed, but VM execution is blocked by glibc. | `qa/reports/service-smoke/veloren-lan-20260614T053300Z/report.txt`; `/var/www/html/mirrors/veloren/downloads/SHA256SUMS.txt`. | Full game assets, local server, or client join. |
| FreeCol | Hub page exists; Java package is available but not smoke-tested in this pass. | Existing `/mirrors/freecol-lan/` hub and mirror. | Java client launch/play. |
| 0 A.D. | Hub page exists; Debian package is available but heavy. | Existing `/mirrors/zero-ad-lan/` hub and mirror. | Client install/launch/LAN match. |

## Next tests

1. Add a reusable native client launch script so Xvfb screenshot smokes are not one-off shell snippets.
2. For OpenTTD, start the dedicated server and launch one local client against `127.0.0.1:3979` under Xvfb.
3. For Freeciv, start `freeciv-server` and launch `freeciv-gtk3.22` into the local server/tutorial path.
4. Install the Wesnoth client package after checking size, then run a client launch screenshot and a local server lobby join.
5. Inspect Stendhal server packaging; the cached ZIP appears client-focused.
6. For Veloren, avoid claiming Debian 12 support from the latest Airshipper ZIP. Find a Docker/server path, older compatible release, or build-from-source path before the next smoke.
