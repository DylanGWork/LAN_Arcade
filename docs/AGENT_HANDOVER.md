# LAN Arcade Agent Handover

You are helping Dylan work on LAN Arcade, an offline-friendly browser game arcade hosted on the GannanNet VM.

LAN Arcade is meant to be a local kids/family game portal: ad-free, no accounts, no tracking, usable on the home network and potentially useful for holidays/offline situations.

## VM Access

- VM name: `GannanNet`
- SSH: `dylan@192.168.1.106`
- Password: Dylan will provide the usual VM password separately.
- OS: Debian 12
- Repo path: `/home/dylan/LAN_Arcade`
- Git remote: `https://github.com/DylanGWork/LAN_Arcade.git`

## Current Git State

Checked on 2026-06-12:

- Branch: `main`
- Local HEAD: `25de93867308a21d2af8e6a4fba46376ed36b781`
- Remote `origin/main`: `25de93867308a21d2af8e6a4fba46376ed36b781`
- Last commit: `Add companion APK downloads section`
- Worktree was clean before this handover file was added.

After this handover, expect these new uncommitted documentation files:

```text
AGENTS.md
docs/AGENT_HANDOVER.md
```

Do not commit unless Dylan asks.

## Deployed URLs

These responded with HTTP `200` on 2026-06-12:

```text
http://192.168.1.106/mirrors/games/
http://192.168.1.106/mirrors/games/wiki/
http://192.168.1.106/mirrors/games/downloads/
http://192.168.1.106/mirrors/lan-tank-arena/
```

The public catalog at `/var/www/html/mirrors/games/catalog.json` had 58 games.

Browser check on 2026-06-12:

- Arcade page rendered successfully after catalog load.
- 53 of 58 games were visible.
- 5 games were hidden by admin filters.

## Important Architecture Notes

This project is not a normal always-running web app. It is mostly script-driven mirror/deployment tooling.

Important files/folders:

```text
/home/dylan/LAN_Arcade/README.md
/home/dylan/LAN_Arcade/setup_lan_arcade.sh
/home/dylan/LAN_Arcade/games.meta.sh
/home/dylan/LAN_Arcade/local-games/
/home/dylan/LAN_Arcade/apps/companion/
/home/dylan/LAN_Arcade/services/arcade-api/
/home/dylan/LAN_Arcade/services/lan-tank-arena/
/home/dylan/LAN_Arcade/services/mindustry/
/home/dylan/LAN_Arcade/services/unciv/
/home/dylan/LAN_Arcade/packages/shared/
/home/dylan/LAN_Arcade/qa/
```

Deployed mirror files:

```text
/var/www/html/mirrors/games/catalog.json
/var/www/html/mirrors/games/admin.filters.json
/var/www/html/mirrors/games/index.html
/var/www/html/mirrors/games/wiki/index.html
/var/www/html/mirrors/games/admin/index.html
```

GannanNet serves `/var/www/html/mirrors` through the existing nginx `webserver` container at:

```text
http://192.168.1.106/mirrors/
```

## VM-Specific Deployment Warning

The README describes a full Apache-first install path.

On GannanNet, nginx already owns port 80 through the existing `webserver` container, so do not casually run:

```bash
sudo ./setup_lan_arcade.sh
```

Read this first:

```text
/home/dylan/LAN_Arcade/docs/VM_DEVELOPMENT_AND_QA.md
```

Safe metadata/page regeneration command on GannanNet:

```bash
cd /home/dylan/LAN_Arcade
ARCADE_NAME="GannanNet" \
LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 \
LAN_ARCADE_SKIP_ADMIN_AUTH=1 \
LAN_ARCADE_SKIP_MIRROR=1 \
LAN_ARCADE_CATALOG_SOURCE=metadata-existing \
bash ./setup_lan_arcade.sh
```

To refresh mirrored games while still leaving nginx/Apache alone, remove only:

```text
LAN_ARCADE_SKIP_MIRROR=1
```

Be careful: refreshing mirrors can touch lots of files under `/var/www/html/mirrors`.

## QA Commands

From the repo:

```bash
cd /home/dylan/LAN_Arcade
npm install
npx playwright install chromium
npm run qa:static
npm run qa:smoke
npm run qa:smoke:catalog
npm run qa:smoke:mobile
npm run qa:tank
```

Useful smaller checks:

```bash
npm run qa:smoke:sample
npm run qa:summary -- --report qa/reports/latest-visible/smoke-report.json --output-dir qa/reports/latest-visible
npm run qa:game -- outpost-siege
```

Reports are written under:

```text
qa/reports/
```

The report directory is git-ignored.

## Recent Life Engine Addition

On 2026-06-13, `life-engine` was added as a bundled `LOCAL_DIR` game from `MaxRobinsonTheGreat/LifeEngine` commit `15bb2fe444d3c5c0024dc92183fbda8249813fbb`.

Important details:

```text
local-games/life-engine/
/var/www/html/mirrors/life-engine/
http://192.168.1.106/mirrors/life-engine/
```

The upstream build was offline-patched for LAN Arcade:

- local icon CSS instead of CDN Font Awesome
- local CanvasJS-compatible chart shim
- YouTube/community-link embed removed from the About panel
- remote mod links disabled
- LAN Arcade QA hooks added for focused smoke testing

Deployment backup:

```text
tmp/deploy-backups/life-engine-20260612T145104Z
```

Focused regression passed:

```text
npm run qa:static
npm run qa:game -- life-engine
```

Results:

- Catalog now has 59 games.
- Static audit: 59 OK, 0 needing attention, 0 entrypoint external dependency refs.
- Desktop: 1/1 strict pass, playable, 0 warnings, 0 blockers.
- Mobile: 1/1 strict pass, playable, 0 warnings, 0 blockers.

Reports:

```text
qa/reports/game-regression/life-engine-20260612T145201Z-desktop/
qa/reports/game-regression/life-engine-20260612T145201Z-mobile/
```

A temporary 20-minute headless agent-play run was started at:

```text
http://192.168.1.106/mirrors/agent-runs/life-engine/
```

It publishes `latest.png` and `status.json`. Initial runner PID was `204658`; it is expected to exit after the timed run.

## EvoLab Added

EvoLab is now deployed at:

```text
http://192.168.1.106/mirrors/evolab/
```

It is based on `simongonzalezdc/EvoLab` commit `ad46b78e65d07de022b67d7081847ef420a0564e` and is MIT licensed. The bundled copy keeps `LICENSE`, `SOURCE.md`, and source context under `local-games/evolab/`.

Important offline/QA changes:

- Build used scoped Node 22; VM global Node 18 is too old for Vite 8.
- Installed the missing Rolldown native binding and aligned `react-dom` to `19.2.7`.
- Built with Vite `--base ./` to keep dynamic chunk loading relative under `/mirrors/evolab/`.
- Removed the remote OpenDyslexic font dependency.
- Defaulted background music off and guarded Tone.js startup errors after a mobile QA page error.
- Added a smoke recipe that skips the onboarding tutorial, starts a simulation, opens stats, and sends movement keys.

Safe deploy backup:

```text
tmp/deploy-backups/evolab-20260612T155758Z
```

Passing focused regression reports:

```text
qa/reports/game-regression/evolab-20260612T155839Z-desktop/
qa/reports/game-regression/evolab-20260612T155839Z-mobile/
```

Both desktop and mobile passed strict/playable with 0 warnings and 0 blockers. Static audit reported 60 games OK and 0 entrypoint external dependency refs.

A temporary 45-minute headless agent-play run is available at:

```text
http://192.168.1.106/mirrors/agent-runs/evolab/
```

It publishes `latest.png` and `status.json`. Initial runner PID: `263421`. Planned end: `2026-06-12T16:51:46Z`. Runner log: `qa/reports/agent-evolab-runlogs/evolab-agent-20260612T160645Z.log`. Report dir: `qa/reports/agent-evolab-20260612T160646Z`.

Some-Life was evaluated in `tmp/some-life-eval` at commit `65b09473864e16e665a85765866907bd87a21eea`, but no license file was found. Do not mirror/publish it unless Dylan gets permission or an upstream license is added. It can still be used as design inspiration for an original LAN Arcade-safe artificial-life game.

## Gene Garden Added

Gene Garden is now deployed at:

```text
http://192.168.1.106/mirrors/gene-garden/
```

This is an original LAN Arcade artificial-life game built in the Some-Life-ish genre, not a Some-Life mirror or port. It uses first-party HTML/CSS/JS only and keeps a source note at `local-games/gene-garden/SOURCE.md`.

Implemented systems:

- Grid grass growth with Spring/Winter pressure.
- Critter family lines with visible colors.
- Eight inherited genes: sense, appetite, thrift, fertility, speed, wander, longevity, and boldness.
- Mutation, mating/asexual fallback, generation tracking, gene bars, walls, paddocks, corridor layout, storms, and mobile-friendly canvas interaction.
- `window.__lanArcadeGame` QA hooks for deterministic smoke actions.

Safe deploy backup:

```text
tmp/deploy-backups/gene-garden-20260612T163557Z
```

Passing focused regression reports:

```text
qa/reports/game-regression/gene-garden-20260612T163611Z-desktop/
qa/reports/game-regression/gene-garden-20260612T163611Z-mobile/
```

Both desktop and mobile passed strict/playable with 0 warnings and 0 blockers. Static audit reported 61 games OK and 0 entrypoint external dependency refs.

Reminder: the actual Some-Life repo in `tmp/some-life-eval` still has no license file. Do not mirror/publish it unless permission or an upstream license is added. Gene Garden exists as the arcade-safe original alternative.

## Mobile UX Check

Dylan reported EvoLab menu overlap from a real phone browser screenshot. A visual mobile UX check was run for EvoLab, Gene Garden, and Life Engine.

Reports:

```text
qa/reports/mobile-ux-check-20260612T170522Z/
qa/reports/evolab-layout-check-20260612T171124Z/
```

Verdict:

- `gene-garden`: genuinely mobile friendly.
- `life-engine`: mobile tolerant, but tiny and desktop-ish.
- `evolab`: not mobile friendly despite passing the automated mobile smoke gate; fixed-position menus, setup panels, and bottom controls overlap/run off-screen.

Action taken: removed `mobile-friendly` from EvoLab categories and safely regenerated the catalog. Backup: `tmp/deploy-backups/mobile-labels-20260612T171416Z`. Static audit after relabel: 61 OK, 0 entrypoint external dependency refs.

Follow-up fix on 2026-06-13 after Dylan reported that Auto Mode OFF still felt the same:

- Root cause: EvoLab's update path was still forcing player species auto movement, and the species manager ignored the `autoMode` flag.
- Manual Mode now passes WASD/arrow-key direction through to the player species and visibly nudges the cyan player species cluster.
- Player species now starts clustered near the center and is cyan instead of green, so it is easy to distinguish from AI species.
- Biome legend starts collapsed and the main menu has a `Menu` / `Close Menu` toggle.
- Narrow-screen layout guards shrink the HUD, hide the keyboard hint and zoom widget on phones, and make the time controls a bottom strip so panels do not pile up over the playfield.

Safe deploy backups:

```text
tmp/deploy-backups/evolab-controls-20260613T002954Z
tmp/deploy-backups/evolab-mobile-controls-20260613T004507Z
tmp/deploy-backups/evolab-meta-cleanup-20260613T005412Z
```

Passing focused regression reports after the fix:

```text
qa/reports/game-regression/evolab-20260613T004528Z-desktop/
qa/reports/game-regression/evolab-20260613T004528Z-mobile/
```

Visual/layout report after the fix:

```text
qa/reports/evolab-controls-20260613T004823Z/
```

Current judgment: EvoLab is now usable on laptop and tolerable on phone, but keep it out of `mobile-friendly` until it has deliberate touch controls and a more compact mobile-first HUD.

Metadata cleanup: removed a duplicate stale EvoLab category line that still included `mobile-friendly`. Static audit after cleanup: 61 OK, 0 entrypoint external dependency refs.


## Current Known Issue

LAN Tank Arena static page responds:

```text
http://192.168.1.106/mirrors/lan-tank-arena/
```

But on 2026-06-12:

```text
systemctl is-active lan-tank-arena.service
```

returned:

```text
inactive
```

And:

```text
curl http://127.0.0.1:8787/tank-arena/healthz
```

did not respond.

Treat LAN Tank Arena multiplayer backend as not currently working until you inspect/start/fix the service. Do not claim multiplayer works just because the static page loads.

## Product Direction

Useful next work may include:

- Fix or restart LAN Tank Arena backend.
- Add a clearer homepage/service card on GannanNet if not already present.
- Improve child/family UX for browsing games.
- Improve offline reliability by removing remaining remote dependencies.
- Improve mobile/touch QA.
- Add more original/local games rather than depending on mirrored third-party sites.
- Improve companion app downloads/setup instructions.
- Add curated age modes and safer default filters.
- Add a "holiday/offline kit" mode with instructions for running it from a small VM/Raspberry Pi.

## Safety And Boundaries

Stay inside:

```text
/home/dylan/LAN_Arcade
```

unless Dylan explicitly asks otherwise.

Do not touch:

```text
/opt/asx-platform
/home/dylan/wordpress
/home/dylan/mealie
/srv/reticulum-services/actual-budget
/home/dylan/financial-planner
/home/dylan/task-hub
/home/dylan/inventory-hub
/home/dylan/garden-hub
/home/dylan/house-map
/srv/maps
/srv/kiwix
/mnt/tank/*
```

Do not stop Docker globally.

If you need to alter `/var/www/html/mirrors`, make a backup or export first and document exactly what changed.

## First Suggested Agent Task

Start with a read-only orientation:

```bash
cd /home/dylan/LAN_Arcade
git status --short --branch
git log -1 --oneline --decorate
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1/mirrors/games/
python3 - <<'PY'
import json
p='/var/www/html/mirrors/games/catalog.json'
with open(p) as f:
    data=json.load(f)
items=data if isinstance(data, list) else data.get('games', [])
print(len(items), 'catalog games')
PY
systemctl is-active lan-tank-arena.service || true
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8787/tank-arena/healthz || true
```

Then report:

- repo clean/dirty state
- deployed page status
- game count
- Tank Arena backend status
- recommended next action


## EvoLab Playability Patch - 2026-06-13

Dylan reported that cyan cells appeared to glide over food without visible ATP gain, and that the trait editor was too fiddly because slider-only controls and a flat �2 limit made Vision Range almost impossible to adjust.

Changes deployed on GannanNet:

- Species-mode glucose pickup radius increased from 30 to 44 world units.
- Player-species glucose pickups now create eating sparkles and floating +ATP labels.
- HUD now includes a Food Eaten counter so species-level collection is visible even when Avg ATP only moves slightly.
- Trait editor now has sliders, +/- buttons, and numeric inputs.
- Vision Range now has a trait-specific per-generation range of �100 with 5-unit steps; ordinary 0-10 traits still use tighter ranges.
- Trait editor now shows inline DNA budget feedback instead of repeated alert popups.
- Remote OpenDyslexic font links were removed again from the rebuilt upstream index so the static audit stays offline-clean.

Safe deploy backups:

```text
tmp/deploy-backups/evolab-playability-20260613T080406Z
tmp/deploy-backups/evolab-playability-clean-20260613T080655Z
tmp/deploy-backups/evolab-playability-traitfix-20260613T082034Z
```

Passing focused regression:

```text
qa/reports/game-regression/evolab-20260613T082100Z-desktop/
qa/reports/game-regression/evolab-20260613T082100Z-mobile/
```

Extra VM-side browser checks:

```text
qa/reports/evolab-playability-check-20260613T082607Z/  # Food Eaten reached 8, no runtime errors.
qa/reports/evolab-trait-editor-check-20260613T083210Z/ # Trait editor visible; Vision Range input accepted 150 -> 200, no runtime errors.
```

Static audit after final deploy: 61 games OK, 0 entrypoint external dependency refs.
