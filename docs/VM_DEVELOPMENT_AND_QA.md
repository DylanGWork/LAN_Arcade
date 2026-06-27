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

### LAN-Origin Regression Rule

Do not certify a new or repaired game from HTTP status alone. For browser games
or launcher pages, at minimum run the smoke test against the real LAN origin and
repeat with the mobile profile:

```sh
node qa/arcade-smoke.mjs --catalog --base-url https://192.168.1.106/mirrors/games/ --game <game-id> --screenshot-all --report-dir qa/reports/<name>-desktop
node qa/arcade-smoke.mjs --catalog --base-url https://192.168.1.106/mirrors/games/ --game <game-id> --mobile --screenshot-all --report-dir qa/reports/<name>-mobile
```

Localhost-only browser tests are useful for quick iteration but are not a
promotion gate. Browsers treat `localhost` as a secure context, so APIs such as
OPFS storage, `crypto.randomUUID`, service workers, clipboard, fullscreen, and
some worker/storage paths can behave differently on `http://192.168.1.106`.
If the game has a first-run flow, the focused smoke must click through the first
meaningful action: create a world, start a match, open the emulator canvas, join
the local server, or reach the playable screen. Record that report path in the
handover or intake document.

Pillage First is the current example: `qa/pillage-first-live-smoke.mjs` tests
both localhost and the HTTPS LAN origin and creates a world before passing.

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

Life Engine addition on 2026-06-13:

- Added `life-engine` as a bundled `LOCAL_DIR` browser artificial-life/evolution sandbox based on `MaxRobinsonTheGreat/LifeEngine` commit `15bb2fe444d3c5c0024dc92183fbda8249813fbb`.
- Kept GPL-3.0 license/source context under `local-games/life-engine/`.
- Offline-patched the upstream build by replacing CDN Font Awesome with local icon CSS, replacing remote CanvasJS with a small local chart shim, removing the YouTube/community-link embed, disabling remote mod links, and adding LAN Arcade QA hooks.
- Deployed by copying only `/var/www/html/mirrors/life-engine`, then running the safe no-mirror/no-package regeneration command. Backup: `tmp/deploy-backups/life-engine-20260612T145104Z`.
- Catalog after regeneration: 59 games.
- Static audit: 59 OK / 0 needing attention / 0 entrypoint external dependency refs.
- Focused Life Engine desktop regression: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Focused Life Engine mobile regression: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Reports:
  - `qa/reports/game-regression/life-engine-20260612T145201Z-desktop/smoke-report.md`
  - `qa/reports/game-regression/life-engine-20260612T145201Z-desktop/qa-summary.md`
  - `qa/reports/game-regression/life-engine-20260612T145201Z-mobile/smoke-report.md`
  - `qa/reports/game-regression/life-engine-20260612T145201Z-mobile/qa-summary.md`
- A temporary agent-play/watch session was started for 20 minutes at `/mirrors/agent-runs/life-engine/`, with screenshots/status copied from a headless Playwright run. Initial PID: `204658`.

EvoLab addition on 2026-06-13:

- Added `evolab` as a bundled `LOCAL_DIR` browser evolution game based on `simongonzalezdc/EvoLab` commit `ad46b78e65d07de022b67d7081847ef420a0564e`.
- Kept MIT license/source context under `local-games/evolab/`.
- Built with scoped Node 22 because the VM global Node is 18 and Vite 8 requires Node 20.19+.
- Installed the missing Rolldown native binding and aligned `react-dom` to `19.2.7` to match React before building.
- Built with Vite `--base ./` so dynamic chunks load under `/mirrors/evolab/` instead of `/assets/`.
- Offline-patched the build by removing the remote OpenDyslexic font, defaulting background music off, and guarding Tone.js startup errors for mobile/autoplay stability.
- Deployed by copying only `/var/www/html/mirrors/evolab`, then running the safe no-mirror/no-package regeneration command. Backup: `tmp/deploy-backups/evolab-20260612T155758Z`.
- Catalog after regeneration: 60 games.
- Static audit: 60 OK / 0 needing attention / 0 entrypoint external dependency refs.
- Focused EvoLab desktop regression: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Focused EvoLab mobile regression: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Reports:
  - `qa/reports/game-regression/evolab-20260612T155839Z-desktop/smoke-report.md`
  - `qa/reports/game-regression/evolab-20260612T155839Z-desktop/qa-summary.md`
  - `qa/reports/game-regression/evolab-20260612T155839Z-mobile/smoke-report.md`
  - `qa/reports/game-regression/evolab-20260612T155839Z-mobile/qa-summary.md`
- A temporary 45-minute headless agent-play run was started at `/mirrors/agent-runs/evolab/`, with screenshots/status copied from a Playwright run. Initial PID: `263421`. Planned end: `2026-06-12T16:51:46Z`. Report dir: `qa/reports/agent-evolab-20260612T160646Z`.

Gene Garden addition on 2026-06-13:

- Added `gene-garden` as an original bundled `LOCAL_DIR` artificial-life genetics sandbox inspired by the broader Some-Life style/genre, without copying Some-Life code, assets, layout, or text.
- Kept source note under `local-games/gene-garden/SOURCE.md`. The game is first-party LAN Arcade HTML/CSS/JS with no external runtime dependencies.
- Core systems: grid grass growth, Spring/Winter pressure, critter family lines, eight inheritable genes, mutation, reproduction, walls, paddocks/corridor layouts, storm pressure, gene bars, and QA hooks.
- Added `gene-garden` metadata to `games.meta.sh` and a smoke recipe that pauses, paints grass, places a wall, adds critters, runs, storms, and fast-forwards evolution.
- Deployed by copying only `/var/www/html/mirrors/gene-garden`, then running the safe no-mirror/no-package regeneration command. Backup: `tmp/deploy-backups/gene-garden-20260612T163557Z`.
- Catalog after regeneration: 61 games.
- Static audit: 61 OK / 0 needing attention / 0 entrypoint external dependency refs.
- Focused Gene Garden desktop regression: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Focused Gene Garden mobile regression: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Reports:
  - `qa/reports/game-regression/gene-garden-20260612T163611Z-desktop/smoke-report.md`
  - `qa/reports/game-regression/gene-garden-20260612T163611Z-desktop/qa-summary.md`
  - `qa/reports/game-regression/gene-garden-20260612T163611Z-mobile/smoke-report.md`
  - `qa/reports/game-regression/gene-garden-20260612T163611Z-mobile/qa-summary.md`

Mobile UX check on 2026-06-13:

- Checked the evolution/life games in a phone viewport after Dylan reported EvoLab menu overlap from a real phone screenshot.
- Visual reports:
  - `qa/reports/mobile-ux-check-20260612T170522Z/`
  - `qa/reports/evolab-layout-check-20260612T171124Z/`
- Verdict: `gene-garden` is genuinely mobile friendly; `life-engine` is mobile tolerant but tiny/desktop-ish; `evolab` is not mobile friendly because fixed side menus, setup panels, and bottom controls overlap or run off-screen on phone-sized viewports.
- Removed `mobile-friendly` from EvoLab categories and regenerated the catalog safely. Backup: `tmp/deploy-backups/mobile-labels-20260612T171416Z`.
- Static audit after relabel: 61 OK / 0 needing attention / 0 entrypoint external dependency refs.


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

## Native Board-Game Smoke Gates

Native board games need a separate gameplay gate because a hub page can be
offline-clean while the real native client is still only partial or blocked.

Run the current board-game smoke suites one game at a time or as a batch:

```sh
scripts/native_board_game_play_smoke.sh
scripts/native_board_game_expanded_smoke.sh
scripts/native_board_game_play_smoke.sh pioneers-lan
scripts/native_board_game_expanded_smoke.sh kigo-lan
```

The scripts run the native game in a `bwrap --unshare-net` no-internet namespace
where practical and write one report directory per game. They intentionally
record `PASS`, `PARTIAL`, or `BLOCKED` instead of treating a window launch as a
successful game test.

Promotion meanings:

- `PASS`: the game reached a meaningful board/gameplay state under no-internet
  conditions and has screenshot/log evidence.
- `PARTIAL`: a local launch/server path works, but another client, battle turn,
  or gameplay step still needs proof.
- `BLOCKED`: the game fails before playability or attempts external network
  paths that violate offline use.

Document the report path in the relevant intake document. Current board-game
intake details live in:

```text
docs/BOARD_GAME_INTAKE_2026-06-19.md
```

## Native Downloads And NFS Shelf

Large client installers, Debian package closures, and mirrored manuals belong on
the NFS-backed native shelf, not in Git:

```text
/srv/lan-arcade/native-downloads
/var/www/html/mirrors/games/downloads/native
```

Use per-game or per-batch cache scripts to populate the shelf, then link hubs to
the local shelf. A public arcade game must not require the player to have known
about the game before the internet went down.

## Windows SSH And Rsync Guardrails

Most agent work happens on the Debian VM, but Codex may connect from a Windows
host. Be careful with PowerShell interpolation and CRLF when sending remote shell
scripts.

Rules:

- Prefer LF-only temp scripts sent with `plink -m` or a single-quoted SSH command
  for complex remote work.
- Do not use double-quoted PowerShell remote loops containing variables such as
  `$s`; PowerShell expands them locally before SSH sees the command.
- Do not run `rsync --delete` against `/var/www/html/mirrors/` as a root target
  unless the whole mirror tree is intentionally being rebuilt from a verified
  source.
- Prefer per-game deploys such as
  `rsync -a --delete local-games/<id>/ /var/www/html/mirrors/<id>/`.
- Use `rsync --dry-run` first for anything broad or computed.
- If a mirror tree looks suspiciously empty, repair with the safe VM regeneration
  flags and omit only `LAN_ARCADE_SKIP_MIRROR=1` when the mirror content itself
  needs to be restored.

## Emulator Shelves And DOSBox Pure

Large emulator collections should be exposed as nested shelves instead of as
hundreds of top-level catalog cards. The current VM-local shelves are:

```text
/var/www/html/mirrors/private-rom-vault   # generated Game Boy/GBC shelf
/var/www/html/mirrors/private-dos-vault   # generated DOSBox Pure shelf
```

Keep ROMs, DOS packages, screenshots, and generated manifests out of Git unless
Dylan explicitly changes the storage policy. Git should contain only wrappers,
builder scripts, and intake notes.

The DOSBox Pure EmulatorJS core requires threaded WebAssembly, so the DOS vault
must be served over HTTPS with cross-origin isolation headers. On GannanNet the
active host-side nginx config is:

```text
/home/dylan/wordpress/nginx-conf/nginx.conf
```

The scoped `/mirrors/private-dos-vault/` block should include:

```nginx
add_header Cross-Origin-Opener-Policy same-origin always;
add_header Cross-Origin-Embedder-Policy require-corp always;
add_header Cross-Origin-Resource-Policy same-origin always;
```

The `/mirrors/emulatorjs-runtime/` block should at least provide
`Cross-Origin-Resource-Policy: same-origin`. Without these headers, the browser
will show an EmulatorJS error and will not request the DOS package.


## Recent Library And Emulator Regression Lessons

Lessons from the June 2026 Classic PC/Game Library regressions:

- Main library search must include nested shelves. The home page should not render hundreds of ROM/DOS/board entries by default, but a title search such as `simant` must return the actual playable entry, not only the parent shelf card.
- Count labels must be precise. Use `cards`, `shelf entries`, `playable links`, or `research rows` as appropriate. Do not imply the top-level catalog count is the total playable-game count.
- Keep user-facing pages in player language. Intake states such as `source-ready`, `candidate`, `package missing`, `partial`, and `blocked` are useful for admin/intake views, but the public library should say what the player can do next: `Play`, `Open shelf`, `Download game ZIP`, `Needs local files`, or `Review before play`.
- Classic PC/DOS entries have separate states: listed metadata, local ZIP package, browser `.jsdos` bundle, QA smoke result, and manual/website mirror. Do not collapse these into one ambiguous status.
- Browser DOS emulation can use hundreds of MB per tab even for tiny games. The Classic PC player should use js-dos worker/canvas mode, avoid direct WebGL where possible, call the player stop hook on unload, and document local DOSBox as the fallback for weak laptops.
- Recently played has two modes: guests use browser `localStorage`; signed-in accounts use the account API and should be treated as the stronger cross-browser source where the account session is active. Do not claim full cross-device save persistence for emulator/DOS/native games until their specific save adapters are implemented.

Minimum checks after changing the public library/search/recently-played layer:

```bash
npm run qa:static
npm run qa:library-discovery
```

`qa:library-discovery` is the required regression for the nested-shelf search path. It verifies that a `simant` search returns the direct Classic PC play card, that stale operator wording such as `top-level cards` and `Native / services` is absent, and that browser-local Recently played appears after launch. Use additional mobile/narrow Playwright checks when layout or CSS changed.

## Pillage First SPA Fallback And Deploy Safety

Pillage First is a static SPA under:

```text
/var/www/html/mirrors/pillage-first
```

Deep routes such as `/mirrors/pillage-first/game/<world>/<village>/resources`
must serve `/mirrors/pillage-first/index.html`. If `index.html` is missing, nginx
can return `500 Internal Server Error` with this log message:

```text
rewrite or internal redirection cycle while internally redirecting to "/mirrors/pillage-first/index.html"
```

On GannanNet, the active nginx config is:

```text
/home/dylan/wordpress/nginx-conf/nginx.conf
```

The Pillage First block should use `root /`, not an `alias` fallback, so the SPA
fallback resolves against the container's `/mirrors` bind mount:

```nginx
location ^~ /mirrors/pillage-first/ {
    if ($scheme = http) {
        return 302 https://$host$request_uri;
    }
    root /;
    index index.html;
    try_files $uri $uri/ /mirrors/pillage-first/index.html;
}
```

Use `scripts/build_pillage_first_mirror.sh` for rebuilds. It stages the complete
client tree, verifies `index.html` and JS assets exist, then swaps the staged tree
into place. Do not manually repair only `landing/`; that creates a broken app
that still passes shallow screenshot-asset checks.

Required checks after Pillage First repair or nginx edits:

```bash
curl -skI https://127.0.0.1/mirrors/pillage-first/game/s-test/v-1/resources
PILLAGE_FIRST_BASE_URLS="https://127.0.0.1/mirrors/pillage-first/,https://192.168.1.106/mirrors/pillage-first/" node qa/pillage-first-live-smoke.mjs
npm run qa:static
```
