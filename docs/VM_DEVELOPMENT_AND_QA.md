# VM Development and QA

This project is currently a script-driven LAN arcade, not a conventional app server.

## Current Architecture

- `games.meta.sh` is the source of truth for game source URLs, card metadata, and categories.
- Original bundled games can use `LOCAL_DIR::<repo-relative-folder>` sources in `games.meta.sh`; setup copies them into the mirror like any other game.
- `setup_lan_arcade.sh` installs host packages when run normally, mirrors games into `/var/www/html/mirrors/<game>/`, and generates the public arcade pages under `/var/www/html/mirrors/games/`.
- `services/lan-tank-arena/server.mjs` is the first original browser multiplayer service. The client is mirrored like other games, while the host runs a local WebSocket server on port `8787`.
- `audit_mirrors.sh` performs static checks against mirrored HTML entrypoints and local asset references.
- The deployed VM currently serves `/var/www/html/mirrors` through the existing nginx container at `/mirrors/`.
- The README installer path assumes Apache. On this VM, nginx is already bound to port 80, so use the safe regeneration command below unless you intentionally want to alter host web-server packages.

## Safe VM Regeneration

Regenerate catalog/pages against already mirrored games without installing packages, configuring Apache, or touching nginx:

```sh
ARCADE_NAME="GannanNet" \
LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 \
LAN_ARCADE_SKIP_ADMIN_AUTH=1 \
LAN_ARCADE_SKIP_MIRROR=1 \
LAN_ARCADE_CATALOG_SOURCE=metadata-existing \
bash ./setup_lan_arcade.sh
```

To also download or refresh mirrored games from metadata while still leaving nginx/Apache alone, remove only `LAN_ARCADE_SKIP_MIRROR=1`.

The generated public files are browser-readable:

```text
/var/www/html/mirrors/games/catalog.json
/var/www/html/mirrors/games/admin.filters.json
/var/www/html/mirrors/games/index.html
/var/www/html/mirrors/games/wiki/index.html
/var/www/html/mirrors/games/admin/index.html
```

## QA Commands

Install QA dependencies:

```sh
npm install
npx playwright install chromium
```

Run static mirror validation:

```sh
npm run qa:static
```

Run browser-driven smoke validation:

```sh
npm run qa:smoke
```

Run every catalog entry, including games hidden by admin filters:

```sh
npm run qa:smoke:catalog
```

Run a mobile/touch smoke pass:

```sh
npm run qa:smoke:mobile
```

Run a small sample while developing the QA harness:

```sh
npm run qa:smoke:sample
```

Patch mirrored HTML entrypoints for common offline-hostile CDN/tracker references:

```sh
npm run qa:patch-mirrors
```

Generate a triage summary from a smoke report:

```sh
npm run qa:summary -- --report qa/reports/latest-visible/smoke-report.json --output-dir qa/reports/latest-visible
```

Run the focused promotion gate for one game:

```sh
npm run qa:game -- outpost-siege
```

Run the LAN Tank Arena two-client multiplayer smoke test:

```sh
npm run qa:tank
```

Useful options:

```sh
npm run qa:smoke -- --base-url http://127.0.0.1/mirrors/games/
npm run qa:smoke -- --catalog --report-dir qa/reports/latest-regenerated
npm run qa:smoke -- --mobile --report-dir qa/reports/latest-visible-mobile
npm run qa:smoke -- --game tetris
npm run qa:smoke -- --limit 10
npm run qa:smoke -- --catalog --offset 20 --limit 20 --report-dir qa/reports/catalog-batch-2
npm run qa:smoke -- --allow-external
```

By default the smoke runner blocks outbound HTTP/HTTPS requests that do not target the arcade host. This is intentional: the camping build must work without internet.
The smoke runner writes reports after each game, so a long catalog pass still leaves a partial report if the browser process is killed.

Reports are written to:

```text
qa/reports/latest/smoke-report.md
qa/reports/latest/smoke-report.json
qa/reports/latest/screenshots/
qa/reports/latest/qa-summary.md
qa/reports/latest/qa-summary.html
```

The report directory is git-ignored.

Known blockers can be hidden from the public arcade after a smoke run:

```sh
node qa/quarantine-blockers.mjs \
  --report qa/reports/latest-regenerated/smoke-report.json \
  --filters /var/www/html/mirrors/games/admin.filters.json
```

## Current VM Baseline

Baseline taken after regenerating the metadata catalog on 2026-04-26 against:

```text
http://127.0.0.1/mirrors/games/
```

Static audit:

- 54 catalog games scanned
- 38 OK
- 16 need attention
- 39 have external dependency references in entry HTML

Catalog desktop smoke, before quarantine:

- 54 catalog games discovered
- 12 strict passes
- 37 playable-with-warning results
- 5 blockers

Catalog mobile smoke, before quarantine:

- 54 catalog games discovered
- 12 strict passes
- 37 playable-with-warning results
- 5 blockers

Blockers quarantined from the public arcade:

- `farm-clicker`
- `koutoftimer-idle-miner`
- `racing-clicker`
- `second-derivative-clicker`
- `solaris`

Public visible desktop smoke, after quarantine:

- 49 public games discovered
- 12 strict passes
- 37 playable-with-warning results
- 0 blockers

Public visible mobile smoke, after quarantine:

- 49 public games discovered
- 12 strict passes
- 37 playable-with-warning results
- 0 blockers

Latest report locations from this pass:

```text
qa/reports/latest-regenerated/smoke-report.md
qa/reports/latest-mobile/smoke-report.md
qa/reports/latest-visible/smoke-report.md
qa/reports/latest-visible-mobile/smoke-report.md
```

Follow-up offline patch pass on 2026-05-05:

- `npm run qa:patch-mirrors` applied offline shims, cached reachable runtime assets, and added safe placeholders for noncritical icons/polyfills/ad scripts.
- Static audit improved to 54 OK / 0 needing attention.
- Public visible desktop smoke improved to 15 strict passes, 34 playable-with-warning results, 0 blockers.
- Public visible mobile smoke matched desktop at 15 strict passes, 34 playable-with-warning results, 0 blockers.
- Remaining warning triage: 1 replace-or-deep-repair, 8 repair-assets-and-runtime, 14 repair-missing-assets, 2 runtime-shim/recipe, 9 external cleanup.

Latest follow-up report locations:

```text
qa/reports/latest-visible-patched-2/smoke-report.md
qa/reports/latest-visible-patched-2/qa-summary.md
qa/reports/latest-visible-patched-2/qa-summary.html
qa/reports/latest-visible-patched-mobile/smoke-report.md
qa/reports/latest-visible-patched-mobile/qa-summary.md
```

Full catalog repair/playthrough on 2026-05-05:

- Re-ran the full hidden+visible catalog after repairing missing runtime assets and applying game-specific offline patches.
- Static audit is fully clean: 54 OK / 0 needing attention / 0 entrypoint external dependency refs.
- Desktop catalog smoke result: 54 catalog games discovered, 54 strict passes, 54 playable, 0 warnings, 0 blockers.
- Mobile/touch catalog smoke result: 54 catalog games discovered, 54 strict passes, 54 playable, 0 warnings, 0 blockers.
- Previously blocked games now render and play: `farm-clicker`, `koutoftimer-idle-miner`, `racing-clicker`, `second-derivative-clicker`, and `solaris`.
- User-visible fixes included CityGame Clicker sprite atlases, CSGO Clicker remote image localization, C64 Clicker ROM/dependency caching, Farm Clicker templates/images/path fixes, Idle Miner templates/config, Level 13 source repair, Solaris source rebuild, Water Company runtime fixes, Sudoku service-worker/analytics disablement, Second Derivative template path/font fixes, Particle Clicker mobile retina icons, and additional arcade asset repairs for Snake, Tetris, Pac-Man, Incremancer, and others.
- Desktop evidence includes screenshots for every catalog game. The full mobile pass intentionally used the no-screenshot mode after screenshot-heavy mobile runs proved memory-intensive; focused mobile repair checks were also run for the final touched games.

Latest full-catalog repair report locations:

```text
qa/reports/full-catalog-review-desktop-final-6/smoke-report.md
qa/reports/full-catalog-review-desktop-final-6/qa-summary.md
qa/reports/full-catalog-review-desktop-final-6/qa-summary.html
qa/reports/full-catalog-review-mobile-final-4-noscreens/smoke-report.md
qa/reports/full-catalog-review-mobile-final-4-noscreens/qa-summary.md
qa/reports/full-catalog-review-mobile-final-4-noscreens/qa-summary.html
```

Outpost Siege addition on 2026-05-06:

- Added `outpost-siege` as an original bundled `LOCAL_DIR` tower-defense game.
- Added `npm run qa:game -- <id>` as the focused promotion gate for new or touched games.
- Static audit after catalog regeneration: 55 OK / 0 needing attention / 0 entrypoint external dependency refs.
- Focused Outpost Siege desktop and mobile regression: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Full desktop catalog regression: 55/55 strict passes, 55 playable, 0 warnings, 0 blockers.
- Full mobile catalog regression: 55/55 strict passes, 55 playable, 0 warnings, 0 blockers.

Latest Outpost/full-catalog report locations:

```text
qa/reports/game-regression/outpost-siege-20260506T123449Z-desktop/smoke-report.md
qa/reports/game-regression/outpost-siege-20260506T123449Z-desktop/qa-summary.md
qa/reports/game-regression/outpost-siege-20260506T123449Z-mobile/smoke-report.md
qa/reports/game-regression/outpost-siege-20260506T123449Z-mobile/qa-summary.md
qa/reports/full-catalog-with-outpost-desktop-2/smoke-report.md
qa/reports/full-catalog-with-outpost-desktop-2/qa-summary.md
qa/reports/full-catalog-with-outpost-mobile-2/smoke-report.md
qa/reports/full-catalog-with-outpost-mobile-2/qa-summary.md
```

Breachline Tactics and Circuit Foundry addition on 2026-05-06:

- Added `breachline-tactics` as an original bundled `LOCAL_DIR` turn-based tactical roguelite.
- Added `circuit-foundry` as an original bundled `LOCAL_DIR` mini factory automation game.
- Added game-specific smoke recipes that exercise real gameplay through local QA hooks before screenshots are captured.
- Static audit after catalog regeneration: 57 OK / 0 needing attention / 0 entrypoint external dependency refs.
- Focused Breachline Tactics desktop and mobile regression: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Focused Circuit Foundry desktop and mobile regression: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Full desktop catalog regression: 57/57 strict passes, 57 playable, 0 warnings, 0 blockers.
- Full mobile catalog regression: 57/57 strict passes, 57 playable, 0 warnings, 0 blockers.

Latest two-game addition report locations:

```text
qa/reports/game-regression/breachline-tactics-20260506T135211Z-desktop/smoke-report.md
qa/reports/game-regression/breachline-tactics-20260506T135211Z-desktop/qa-summary.md
qa/reports/game-regression/breachline-tactics-20260506T135211Z-mobile/smoke-report.md
qa/reports/game-regression/breachline-tactics-20260506T135211Z-mobile/qa-summary.md
qa/reports/game-regression/circuit-foundry-20260506T135449Z-desktop/smoke-report.md
qa/reports/game-regression/circuit-foundry-20260506T135449Z-desktop/qa-summary.md
qa/reports/game-regression/circuit-foundry-20260506T135449Z-mobile/smoke-report.md
qa/reports/game-regression/circuit-foundry-20260506T135449Z-mobile/qa-summary.md
qa/reports/full-catalog-with-breachline-circuit-desktop/smoke-report.md
qa/reports/full-catalog-with-breachline-circuit-desktop/qa-summary.md
qa/reports/full-catalog-with-breachline-circuit-mobile/smoke-report.md
qa/reports/full-catalog-with-breachline-circuit-mobile/qa-summary.md
```

LAN Tank Arena addition on 2026-05-07:

- Added `lan-tank-arena` as an original bundled `LOCAL_DIR` browser multiplayer game.
- Added `services/lan-tank-arena`, a dependency-free local WebSocket match server with room codes, 2-8 players, shared arena state, bullets, pickups, respawns, and health/score telemetry.
- The full installer now installs Node.js and enables `lan-tank-arena.service` through systemd, listening on port `8787`. Safe VM regeneration skips this because `LAN_ARCADE_SKIP_PACKAGE_INSTALL=1`.
- Static audit after catalog regeneration: 58 OK / 0 needing attention / 0 entrypoint external dependency refs.
- Focused LAN Tank Arena lobby smoke: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Dedicated multiplayer smoke: pass, with two browser clients joining room `QA`, observing 2 players, sending movement/fire input, and writing desktop plus mobile gameplay screenshots.
- Added `--offset` to the browser smoke runner and incremental report writes after each game, so long catalog passes can be chunked and still leave partial evidence if Chromium is killed.
- Full desktop catalog regression: 58/58 strict passes, 58 playable, 0 warnings, 0 blockers across three chunks.
- Full mobile catalog regression: 58/58 strict passes, 58 playable, 0 warnings, 0 blockers across twelve five-game chunks.

Latest LAN Tank Arena report locations:

```text
qa/reports/game-regression/lan-tank-arena-lobby/smoke-report.md
qa/reports/game-regression/lan-tank-arena-lobby/screenshots/lan-tank-arena.png
qa/reports/tank-arena/20260507T131647Z/tank-smoke.md
qa/reports/tank-arena/20260507T131647Z/screenshots/lan-tank-arena-alpha.png
qa/reports/tank-arena/20260507T131647Z/screenshots/lan-tank-arena-bravo.png
qa/reports/full-catalog-with-lan-tank-arena-desktop-batch-1/smoke-report.md
qa/reports/full-catalog-with-lan-tank-arena-desktop-batch-2/smoke-report.md
qa/reports/full-catalog-with-lan-tank-arena-desktop-batch-3/smoke-report.md
qa/reports/full-catalog-with-lan-tank-arena-mobile-batch-1/smoke-report.md
...
qa/reports/full-catalog-with-lan-tank-arena-mobile-batch-12/smoke-report.md
```

Common failure types:

- missing local JavaScript, CSS, image, sound, or template files
- CDN dependencies blocked during offline mode
- pages that render mostly blank
- JavaScript errors after starting or interacting
- stale links in the generated arcade index, such as missing game folders

## Game Admission Process

Do not add new games directly to the camping build.

Use this flow instead:

1. Add the candidate to `games.meta.sh`. For original bundled games, use `LOCAL_DIR::<repo-relative-folder>`.
2. Mirror/regenerate with the safe VM command.
3. Add or improve a game-specific smoke recipe if the game needs a meaningful first action.
4. Run `npm run qa:game -- <id>`. For LAN Tank Arena, also run `npm run qa:tank`.
5. Confirm the generated desktop and mobile reports both show strict pass, no warnings, no blockers.
6. Confirm the license is acceptable.
7. Check Pi 4 suitability: lightweight assets, no heavy WebGL, no server dependency unless intentionally supported.
8. Promote only after the focused regression gate passes.

The focused gate runs the static audit, desktop smoke with screenshots, mobile smoke with screenshots, and QA summaries. It fails if the game emits blocked external requests, local asset failures, page errors, warnings, or blockers.

For young-kid educational games, prefer small locally controlled games where possible. Counting, number matching, shape matching, memory cards, and simple arithmetic games are easier to test and maintain than large mirrored third-party apps.

## Next Engineering Steps

1. Keep the catalog at zero static warnings and zero blocked external runtime requests.
2. Run `npm run qa:patch-mirrors` after mirroring third-party games, then rerun desktop and mobile smoke checks.
3. Add or tune per-game QA recipes for high-value games whose first meaningful action is not covered by generic clicks/keys.
4. Prefer original `LOCAL_DIR` games for advanced additions when that gives better offline control than third-party mirrors.
5. Design local profiles and high scores around a small local database, likely SQLite, rather than browser-only storage.
6. Keep improving the QA summary page so strict offline-clean, playable-with-warning, and blocker results are easy to compare.
7. Continue the camping companion app investigation for more impressive games that use the Pi as a LAN server.

## Offline Validation Checklist

Before a camping trip build:

- `npm run qa:static` passes
- `npm run qa:game -- <new-or-touched-game>` passes for every changed game
- `npm run qa:smoke` passes for every enabled game
- smoke test is run with external requests blocked
- admin filters hide any known-bad games
- Pi 4 deployment is tested from at least one phone/tablet and one laptop
- high scores survive service restart
- no game requires login, CDN, analytics, remote fonts, or remote scripts
- latest smoke report is saved for reference
