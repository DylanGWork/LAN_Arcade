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

It records under `qa/reports/service-smoke/` and currently supports `openttd-lan`, `freeciv-lan`, `wesnoth-lan`, `teeworlds-ddnet-lan`, `luanti-lan`, `hedgewars-lan`, `widelands-lan`, `warzone2100-lan`, `stendhal-lan`, and `veloren-lan`.

## Current evidence, 2026-06-14

| Game | Current status | Evidence | What it does not prove yet |
| --- | --- | --- | --- |
| OpenTTD | Server TCP smoke passed; VM client launch screenshot passed; native downloads and curated manual cache passed desktop/mobile hub smoke. | `qa/reports/service-smoke/openttd-lan-20260614T053239Z/report.txt`; `qa/reports/native-client-launch/openttd-lan-20260614T054903Z/report.txt`; `qa/reports/native-download-hubs/openttd-lan-20260615T105138Z-*`. | A real player joining the server and playing a route. |
| Freeciv | Server TCP smoke passed; VM GTK client launch screenshot passed; native downloads/docs hub passed desktop/mobile smoke. | `qa/reports/service-smoke/freeciv-lan-20260614T053247Z/report.txt`; `qa/reports/native-client-launch/freeciv-lan-20260614T054915Z/report.txt`; `qa/reports/native-download-hubs/freeciv-lan-20260615T105138Z-*`. | A real multi-client game, tutorial start, or LAN client join. |
| Battle for Wesnoth | Server TCP smoke passed; Windows/macOS installers cached and hub smoke passed. | `qa/reports/service-smoke/wesnoth-lan-20260614T053253Z/report.txt`; `qa/reports/native-download-hubs/wesnoth-lan-20260615T105138Z-*`. | Native client install/launch, hotseat, lobby join, or match play. |
| Stendhal | Cached ZIP integrity passed; Java client, Android APK, and server ZIP shelf passed hub smoke. | `qa/reports/service-smoke/stendhal-lan-20260614T053259Z/report.txt`; `qa/reports/native-download-hubs/stendhal-lan-20260615T105138Z-*`. | Local server launch, account creation, or two-client world join. |
| Veloren | Airshipper launchers/server binary cached and hub smoke passed, but VM execution is blocked by glibc and the full game profile is not yet cached. | `qa/reports/service-smoke/veloren-lan-20260614T053300Z/report.txt`; `qa/reports/native-download-hubs/veloren-lan-20260615T105138Z-*`; `/var/www/html/mirrors/games/downloads/native/veloren/`. | Full game assets, local server, or client join. |
| FreeCol | Hub page, manual mirror, and native release shelf exist; desktop/mobile hub smoke passed. | `/mirrors/freecol-lan/`; `/mirrors/games/downloads/native/freecol/`; `qa/reports/native-download-hubs/freecol-lan-20260615T105138Z-*`. | Java client launch/play. |
| 0 A.D. | Hub page exists; Release 28 Windows/Linux/macOS packages cached; desktop/mobile hub smoke passed. | `/mirrors/zero-ad-lan/`; `/mirrors/games/downloads/native/zero-ad/`; `qa/reports/native-download-hubs/zero-ad-lan-20260615T105138Z-*`. | Client install/launch/LAN match. |

## Next tests

1. Add a reusable native client launch script so Xvfb screenshot smokes are not one-off shell snippets.
2. For OpenTTD, start the dedicated server and launch one local client against `127.0.0.1:3979` under Xvfb.
3. For Freeciv, start `freeciv-server` and launch `freeciv-gtk3.22` into the local server/tutorial path.
4. Install the Wesnoth client package after checking size, then run a client launch screenshot and a local server lobby join.
5. Inspect Stendhal server packaging; the cached ZIP appears client-focused.
6. For Veloren, avoid claiming Debian 12 support from the latest Airshipper ZIP. Find a Docker/server path, older compatible release, or build-from-source path before the next smoke.

## Next native intake, 2026-06-16

| Game | Current status | Evidence | What it does not prove yet |
| --- | --- | --- | --- |
| Teeworlds / DDNet | Downloads/docs hub cached; DDNet UDP server smoke passed; VM client launch passed; desktop/mobile hub smoke passed. | `qa/reports/service-smoke/teeworlds-ddnet-lan-20260615T235745Z/report.txt`; `qa/reports/native-client-launch/teeworlds-ddnet-lan-20260615T235831Z/report.txt`; `qa/reports/native-next-five/teeworlds-ddnet-lan-20260616T000637Z-*`. | A two-client LAN join/play loop. |
| Hedgewars | Downloads/docs cached; VM client launch passed; desktop/mobile hub smoke passed. | `qa/reports/service-smoke/hedgewars-lan-20260615T235758Z/report.txt`; `qa/reports/native-client-launch/hedgewars-lan-20260615T235847Z/report.txt`; `qa/reports/native-next-five/hedgewars-lan-20260616T000637Z-*`. | Hotseat or LAN match play. |
| Widelands | Official 1.3.1 downloads cached; VM client launch passed after launch-smoke temp-home fix; desktop/mobile hub smoke passed. | `qa/reports/service-smoke/widelands-lan-20260615T235758Z/report.txt`; `qa/reports/native-client-launch/widelands-lan-20260616T000117Z/report.txt`; `qa/reports/native-next-five/widelands-lan-20260616T000637Z-*`. | Two-client economy start; full docs mirror, because upstream site was anti-bot blocked. |
| Warzone 2100 | Official 4.6.3 downloads/site pages cached; VM client launch passed; desktop/mobile hub smoke passed. | `qa/reports/service-smoke/warzone2100-lan-20260615T235758Z/report.txt`; `qa/reports/native-client-launch/warzone2100-lan-20260615T235910Z/report.txt`; `qa/reports/native-next-five/warzone2100-lan-20260616T000637Z-*`. | Headless/autohost saved settings and a LAN join/play proof. |
| Luanti | Official 5.16.1 clients/APKs and docs cached; UDP server smoke passed; VM client launch passed; desktop/mobile hub smoke passed. | `qa/reports/service-smoke/luanti-lan-20260615T235751Z/report.txt`; `qa/reports/native-client-launch/luanti-lan-20260615T235922Z/report.txt`; `qa/reports/native-next-five/luanti-lan-20260616T000637Z-*`. | Real laptop/phone join into a local world. |
