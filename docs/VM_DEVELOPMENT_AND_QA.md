# VM Development and QA

This project is currently a script-driven LAN arcade, not a conventional app server.

## Current Architecture

- `games.meta.sh` is the source of truth for game source URLs, card metadata, and categories.
- `setup_lan_arcade.sh` installs host packages when run normally, mirrors games into `/var/www/html/mirrors/<game>/`, and generates the public arcade pages under `/var/www/html/mirrors/games/`.
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

Useful options:

```sh
npm run qa:smoke -- --base-url http://127.0.0.1/mirrors/games/
npm run qa:smoke -- --catalog --report-dir qa/reports/latest-regenerated
npm run qa:smoke -- --mobile --report-dir qa/reports/latest-visible-mobile
npm run qa:smoke -- --game tetris
npm run qa:smoke -- --limit 10
npm run qa:smoke -- --allow-external
```

By default the smoke runner blocks outbound HTTP/HTTPS requests that do not target the arcade host. This is intentional: the camping build must work without internet.

Reports are written to:

```text
qa/reports/latest/smoke-report.md
qa/reports/latest/smoke-report.json
qa/reports/latest/screenshots/
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

Common failure types:

- missing local JavaScript, CSS, image, sound, or template files
- CDN dependencies blocked during offline mode
- pages that render mostly blank
- JavaScript errors after starting or interacting
- stale links in the generated arcade index, such as missing game folders

## Game Admission Process

Do not add new games directly to the camping build.

Use this flow instead:

1. Add the candidate to `games.meta.sh`.
2. Mirror it into a test/staging mirror directory.
3. Run `npm run qa:static`.
4. Run `npm run qa:smoke -- --game <id>`.
5. Confirm no external runtime dependencies.
6. Confirm the license is acceptable.
7. Check Pi 4 suitability: lightweight assets, no heavy WebGL, no server dependency unless intentionally supported.
8. Add or improve a game-specific smoke recipe if the game needs a `Start`, `New Game`, or first-move click.
9. Promote only after it passes offline smoke.

For young-kid educational games, prefer small locally controlled games where possible. Counting, number matching, shape matching, memory cards, and simple arithmetic games are easier to test and maintain than large mirrored third-party apps.

## Next Engineering Steps

1. Clean the 37 public warning games by localizing runtime assets, removing tracking/CDN calls, and fixing query-string filename mirror issues.
2. Add per-game QA recipes for high-value games whose first meaningful action is not covered by generic clicks/keys.
3. Triage remaining warning games by value:
   - keep and repair high-value games
   - disable or remove brittle games with remote dependencies
   - replace questionable games with simpler verified alternatives
4. Design local profiles and high scores around a small local database, likely SQLite, rather than browser-only storage.
5. Add a QA summary page that separates strict offline-clean, playable-with-warning, and blocker results.
6. Start a separate camping companion app investigation for more impressive games that use the Pi as a LAN server.

## Offline Validation Checklist

Before a camping trip build:

- `npm run qa:static` passes
- `npm run qa:smoke` passes for every enabled game
- smoke test is run with external requests blocked
- admin filters hide any known-bad games
- Pi 4 deployment is tested from at least one phone/tablet and one laptop
- high scores survive service restart
- no game requires login, CDN, analytics, remote fonts, or remote scripts
- latest smoke report is saved for reference
