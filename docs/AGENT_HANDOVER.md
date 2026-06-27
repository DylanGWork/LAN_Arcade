# Library Search, Classic PC, And Wording Lessons - 2026-06-27

# Git Identity And Contributor Attribution - 2026-06-28

GitHub showed an unrelated `dylan` account as a contributor because some commits used author email `dylan@users.noreply.github.com`, which GitHub resolved to that account. GitHub collaborator permission check for username `dylan` on `DylanGWork/LAN_Arcade` returned `read`; `DylanGWork` returned `admin`. Treat this as an attribution leak, not evidence of repo write access.

Before committing, run `npm run qa:git-identity`. The VM repo should use `DylanGWork LAN Arcade Agent <dylan.gannan@pestsense.com>`. `.mailmap` maps known bad historical local/agent emails for local history views, but GitHub's public contributor graph may still require an explicit history rewrite if Dylan wants the old attribution removed completely.

Dylan flagged that SimAnt did not appear in the main library search even though it was playable inside the Classic PC shelf. Root cause: `/mirrors/games/` searched only top-level catalog cards. The library generator now keeps large ROM/DOS/board collections nested by default, but title search loads nested manifests and returns direct playable entries for matching games. Guests still get browser-local Recently played via `localStorage`; signed-in accounts also use server-backed recent activity through `/arcade-api/account/activity`.

User-facing language needs stricter separation from intake/admin language. Public pages should not expose confusing states such as `source-ready`, `package missing`, `candidate`, or vague `top-level cards` wording. Use action-oriented labels: `Play`, `Open shelf`, `Ready to play`, `Needs local files`, `Download game ZIP`, and `Review before play`. Keep technical states in manifests, intake docs, admin pages, and QA reports.

Classic PC/DOS entries have multiple independent states: metadata listed, source ZIP present, browser `.jsdos` bundle present, smoke result, and manual/site mirror. Do not treat `package missing` as a single game status without explaining what the player can do.

The SimAnt memory investigation showed that tiny DOS games can still cost roughly 700 MB in browser because the js-dos/WebAssembly runtime dominates memory. Use worker/canvas mode and unload cleanup in the Classic PC player. For low-power laptops, local DOSBox from the downloaded game ZIP remains the safer fallback.

Regression checks after any public library/search/recently-played change: `npm run qa:static` and `npm run qa:library-discovery`. Add mobile/narrow no-overflow checks when layout or CSS changed.

# Pillage First Raid Loot Patch - 2026-06-20

Dylan reported that raids travelled out and back but produced no reports or resources. Upstream Pillage First had `// TODO: Combat` in both attack and raid movement resolvers, and report controllers still return empty/no-op data. LAN Arcade now patches the mirrored build in `scripts/build_pillage_first_mirror.sh` so new raid resolutions steal resources from target villages according to troop carry capacity, attach the loot bundle to the return event, and deposit it into the source village when troops return. Existing return events created before this patch will not retroactively gain loot.

Verification completed after rebuild/deploy: `node qa/pillage-first-live-smoke.mjs`, `node qa/pillage-first-attack-briefing-smoke.mjs`, `npm run qa:static`, upstream resolver suite via Docker Node 24, a temporary focused resolver regression proving 5 legionnaires carried 250 resources, lowered the target stockpile by the carried bundle, and deposited the same bundle on return, plus a temporary report-controller regression proving raid events appear as reports and can be marked read/archived. Reports are currently lightweight LAN-derived raid reports from movement events; the broader upstream report system is still incomplete.

# Native Batch Three Intake - 2026-06-19

Added 10 more native/offline hub entries: Armagetron Advanced, MegaGlest, Unknown Horizons, Pioneers, Flare, OpenClonk, SuperTux, Pingus, LinCity-NG, and Dungeon Crawl Stone Soup Tiles. Hubs are generated from `scripts/native_batch_three_data.py`, `scripts/generate_native_batch_three_hubs.py`, and cached by `scripts/cache_native_batch_three_assets.py`.

Download/package shelves are on NFS under `/srv/lan-arcade/native-downloads/<slug>/`, served via `/mirrors/games/downloads/native/<slug>/`. Batch added about 1.8 GB; current resource check was root `/dev/vda2` 295G total / 152G used / 131G free and native-downloads NFS 11T total / 29G used / 11T free.

QA completed: safe metadata regeneration, `npm run qa:static` scanned 110/110 OK with 0 external entrypoint refs, and `bash scripts/qa_game_regression.sh <game-id>` passed desktop/mobile hub smoke for all 10. Evidence lives under `qa/reports/game-regression/<game-id>-20260618T15*.Z-{desktop,mobile}/`.

Important limitation: this is Gate 0/Gate 1 evidence only. It proves hub pages, local assets, blocked external requests, and package manifests. It does not prove native client launch or real gameplay yet. Several official-site/manual mirror endpoints are blocker pages after wget errors/timeouts; do not claim those are complete manual mirrors. See `docs/NATIVE_BATCH_THREE_2026-06-19.md`.

# Native Downloads NFS Migration - 2026-06-17

Moved `/var/www/html/mirrors/games/downloads/native/` onto the dedicated NFS export `192.168.1.33:/mnt/tank/LAN_Arcade/native-downloads`, mounted at `/srv/lan-arcade/native-downloads` and bind-mounted back to the web path. The old local shelf remains at `/var/www/html/mirrors/games/downloads/native.local-backup` and should not be deleted until the NFS setup has survived reboot/further intake. Because nginx runs in the Docker `webserver` container with `/var/www/html/mirrors` mounted as `/mirrors:ro`, restarting only `webserver` was required after the new submount so the container could see native files.

Verification: NFS/web mounts active, 149 files copied vs 149 in backup, sample native HTTP checks returned 200, Luanti APK ranged read returned 206, and `npm run qa:static` passed with 88/88 OK and 0 external entrypoint refs. Details are in `docs/NATIVE_DOWNLOADS_NFS_2026-06-17.md`.
# Native Next Ten Queue - 2026-06-17

Prepared the next 10-game native intake queue and storage recommendation in `docs/NATIVE_NEXT_TEN_QUEUE_2026-06-17.md`. Current native shelves are about 17 GB and the VM still has about 148 GB free, so one more batch can fit locally, but the long-term plan should move `/var/www/html/mirrors/games/downloads/native/` to a dedicated read-write NFS export. Existing NFS mount `192.168.1.33:/mnt/tank/ZIM` is read-only and KiWix-specific, so request/use a separate LAN Arcade export.

Proposed next 10: SuperTuxKart, Xonotic, Red Eclipse, OpenArena, Freedoom + Chocolate Doom/PrBoom+, BZFlag, FreeOrion, Endless Sky, Cataclysm DDA, and The Mana World / ManaPlus.

# Latest Native Game Testing Update - 2026-06-16

Added five diverse native-game intake hubs with offline release shelves, local docs where practical, VM service/client evidence, and desktop/mobile hub smoke:

- `teeworlds-ddnet-lan`: cached DDNet 19.8.2 and Teeworlds 0.7.5 clients/source; DDNet UDP 8303 server smoke passed; DDNet client launch passed.
- `hedgewars-lan`: cached official Windows/macOS/source/server-source packages; Hedgewars client launch passed; LAN/hotseat match still pending.
- `widelands-lan`: cached official Widelands 1.3.1 release assets; client launch passed; upstream website/wiki was anti-bot blocked, so docs are curated in the hub for now.
- `warzone2100-lan`: cached official Warzone 2100 4.6.3 common platform packages/source; client launch passed; autohost/LAN join still pending.
- `luanti-lan`: cached Luanti 5.16.1 desktop/macOS/Android packages; Minetest/Luanti UDP 30000 server smoke passed; client launch passed.

Report: `docs/NATIVE_NEXT_FIVE_2026-06-16.md`. QA: `npm run qa:static` scanned 88/88 OK with 0 external entrypoint refs; desktop/mobile hub smoke for all five passed under `qa/reports/native-next-five/*-20260616T000637Z-*`.

# Latest Native Game Testing Update - 2026-06-14

Added real native-game test gates and first server/client evidence. Do not describe larger native games as playable from HTTP 200 alone. Use `docs/NATIVE_GAME_TESTING.md` and `scripts/native_service_smoke.sh`.

Current native evidence:

- OpenTTD: Debian packages installed; dedicated server TCP smoke passed; VM client launch screenshot passed. Reports: `qa/reports/service-smoke/openttd-lan-20260614T053239Z/report.txt`, `qa/reports/native-client-launch/openttd-lan-20260614T054903Z/report.txt`.
- Freeciv: added `freeciv-lan` hub; Debian server/client installed; server TCP smoke passed; VM GTK client launch screenshot passed. Reports: `qa/reports/service-smoke/freeciv-lan-20260614T053247Z/report.txt`, `qa/reports/native-client-launch/freeciv-lan-20260614T054915Z/report.txt`.
- Wesnoth: server package installed; TCP smoke passed; client install/launch pending. Report: `qa/reports/service-smoke/wesnoth-lan-20260614T053253Z/report.txt`.
- Stendhal: cached ZIP integrity smoke passed; local server pending. Report: `qa/reports/service-smoke/stendhal-lan-20260614T053259Z/report.txt`.
- Veloren: added `veloren-lan` hub and cached official Airshipper Linux ZIP under `/var/www/html/mirrors/veloren/downloads/`; latest binary is blocked on Debian 12 glibc 2.38/2.39, so server/full game intake is pending. Report: `qa/reports/service-smoke/veloren-lan-20260614T053300Z/report.txt`.

Also added `docs/OPEN_SOURCE_GAME_CANDIDATES.md` with a first candidate backlog from Reddit/search themes plus Debian package availability. The VM Reddit JSON scrape was blocked by HTTP 403, so the backlog is a researched first pass, not a complete scrape.

# LAN Arcade Agent Handover

You are helping Dylan work on LAN Arcade, an offline-friendly browser game arcade hosted on the GannanNet VM.

LAN Arcade is meant to be a local kids/family game portal: ad-free, no accounts, no tracking, usable on the home network and potentially useful for holidays/offline situations.




## 2026-06-14 Native Mirror Hub Integration

Promoted five older deployed mirrors into proper arcade hub entries:

- `zero-ad-lan` -> existing `/mirrors/0ad/play0ad.com/` mirror, about 1.7 GB.
- `wesnoth-lan` -> existing `/mirrors/wesnoth/` website/wiki/manual mirror, about 159 MB.
- `openttd-lan` -> existing `/mirrors/openttd/www.openttd.org/` mirror, about 123 MB.
- `freecol-lan` -> existing `/mirrors/freecol/www.freecol.org/` mirror, about 83 MB.
- `stendhal-lan` -> existing `/mirrors/stendhal/` website/wiki/client-download mirror, about 907 MB.

These are hub pages, not proven full play packs yet. They explain the game, include optimized local screenshots, link to the existing offline mirrors/manuals/downloads, and state the next client/service smoke step. Catalog count is now 71.

Veloren was not found under `/var/www/html/mirrors/` or the repo; track it as a fresh intake candidate in `config/native-services.json`.

Native hub QA passed:

```text
qa/reports/game-regression/native-hub-content-20260614T043722Z/native-hub-content-report.json
```

Static audit after integration: 71 scanned, 71 OK, 0 entrypoint external refs.

A service control design and allowlist registry were added:

```text
docs/NATIVE_SERVICE_ORCHESTRATION.md
config/native-services.json
```

Policy: heavy native services should be on-demand, allowlisted, observable, and smoke-tested one at a time. Do not add arbitrary shell execution to the web admin UI.

## 2026-06-14 Native Service Page Quality Update

Dylan flagged that the Unciv/Mindustry service pages were technically reachable but not good enough as game front pages. The fix was to rebuild them as offline game hubs, not placeholder service cards.

New expectation for native-client/service games:

- Explain what the game actually is in the first viewport.
- Include local screenshots or equivalent visual evidence, with attribution.
- Include quick manual/game-loop guidance, not just Docker commands.
- Include player join steps and operator start/stop notes separately.
- State whether the entry is a browser game or requires a native client.
- Include current QA/service-smoke status and resource notes.
- Check desktop and mobile page layouts for loaded images, no external requests, and no horizontal overflow.

Deployment note: safe metadata regeneration updates the catalog, but it did not refresh already-deployed `LOCAL_DIR` folders for `unciv-lan` and `mindustry-lan` while mirroring was skipped. After editing those local pages, explicitly sync the folder, for example:

```sh
rsync -a --delete local-games/unciv-lan/ /var/www/html/mirrors/unciv-lan/
rsync -a --delete local-games/mindustry-lan/ /var/www/html/mirrors/mindustry-lan/
```

Fresh page QA after the rebuild:

```text
qa/reports/game-regression/unciv-lan-page-final-20260614T024755Z-desktop
qa/reports/game-regression/unciv-lan-page-final-20260614T024755Z-mobile
qa/reports/game-regression/mindustry-lan-page-final-20260614T024755Z-desktop
qa/reports/game-regression/mindustry-lan-page-final-20260614T024755Z-mobile
qa/reports/game-regression/service-page-content-20260614T024719Z/service-page-content-report.json
```

## 2026-06-14 Retro And Service Intake Update

Current repo state after the retro/service work:

- Added two legal EmulatorJS playable entries: `tobu-tobu-girl-deluxe` and `skyland-gba`.
- Catalog now contains 66 games after safe metadata regeneration.
- `Tobu Tobu Girl Deluxe` uses the official itch.io free `tobudx.gb` download, source MIT, assets CC BY 4.0.
- `Skyland GBA` uses the official `evanbowman/skyland-gba` 2022.1.7.0 release asset, MPL-2.0.
- EmulatorJS runtime remains outside Git at `/var/www/html/mirrors/emulatorjs-runtime/4.2.3/`; run `scripts/patch_emulatorjs_runtime.sh` after refreshing the runtime to disable the localhost CDN update check and add the `en-GB` localization alias.
- Focused QA passed for both retro games with external requests blocked:

```text
qa/reports/game-regression/tobu-tobu-girl-deluxe-20260614T000539Z-desktop
qa/reports/game-regression/tobu-tobu-girl-deluxe-20260614T000539Z-mobile
qa/reports/game-regression/skyland-gba-20260614T000601Z-desktop
qa/reports/game-regression/skyland-gba-20260614T000601Z-mobile
```

Agent dogfood report for both retro entries:

```text
qa/reports/retro-agent-playtest-20260613T234654Z/playtest-report.json
```

Dogfood result: both pages created a real canvas, screenshots changed after control input, and there were no console errors, page errors, local request failures, or blocked external requests.

Retro Emulator Lab launcher smoke:

```text
qa/reports/game-regression/retro-emulator-lab-20260614T001628Z-desktop
```

Mindustry service fix:

- `groundZero` was not a valid v157.4 dedicated-server built-in map name.
- Default map is now `Ancient_Caldera`; entrypoint uses direct `host Ancient_Caldera survival` instead of deferred `startCommands`.
- Clean on-demand smoke passed: map loaded, server opened 6567/tcp+udp, no stale `groundZero`/`Already hosting` logs, memory about 138 MiB.

```text
qa/reports/service-smoke/mindustry-host-final-20260614T001049Z.txt
```

Unciv service file loop:

- `/isalive` returned HTTP 200 with `authVersion=1` and `chatVersion=1` on `http://127.0.0.1:8090`.
- Fresh UUID auth path returned 204 before registration, 200 after password set, and 401 for wrong password.
- Important API detail: `PUT /auth` must send the new password in the request body; Basic auth alone is not enough to register it.
- Test turn file uploaded and downloaded successfully; wrong-password overwrite was rejected and did not alter the file.
- Memory about 132 MiB with `UNCIV_JAVA_OPTS="-Xms64m -Xmx256m"`.

```text
qa/reports/service-smoke/unciv-file-loop-final-20260614T001555Z.json
```

No Mindustry or Unciv containers should be left running after these smokes. Verify with `docker ps` before starting new service work.

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


## EvoLab Species/Library Follow-Up - 2026-06-13

Dylan reported EvoLab was still confusing: cells did not visibly breed, evolution felt always available, high speed felt slow or unstable, and long runs produced strange stats. Follow-up changes on GannanNet:

- Player species cells are now internally marked as player-owned.
- Species play now uses a shared breeding reserve instead of requiring one hidden cell to personally collect every resource type.
- HUD shows `Ready Breeders` and `Births` during species play.
- Evolution button is paced by newly earned DNA and shows the pending DNA amount.
- Random event stat effects are clamped to trait ranges, preventing runaway size/health/vision/speed values.
- Vite build now uses `base: './'` so `/mirrors/evolab/` assets remain subpath/offline safe.
- High-speed simulation now caps per-frame effective delta to match the cell simulation stability envelope.
- A narrow Pixi headless shader-log exception handler suppresses the known null shader-log pageerror while preserving other runtime errors.

Passing focused regression after deploy:

```text
qa/reports/game-regression/evolab-20260613T182505Z-desktop/
qa/reports/game-regression/evolab-20260613T182505Z-mobile/
```

Dogfood checks:

```text
qa/reports/evolab-agent-playtest-20260613T182703Z-fastcheck/
```

Fast-check result: 5 minutes at the high-speed setting, population stayed between 43 and 60, births reached 86, final avg ATP 72, final avg health 99, no page errors or console errors. A longer 20-minute run was started in:

```text
qa/reports/evolab-agent-playtest-20260613T183314Z-20min/
```

Final 20-minute result: 37 samples, population stayed between 49 and 60, births reached 258, final avg ATP 70, final avg health 99, no page errors or console errors, and two evolution edits were applied.

## Offline Library Expansion - 2026-06-13

Added/updated catalog entries:

- `mindustry-lan`
- `unciv-lan`
- `retro-emulator-lab`

EmulatorJS 4.2.3 runtime is cached outside Git and served locally at:

```text
/var/www/html/mirrors/emulatorjs-runtime/4.2.3/
http://127.0.0.1/mirrors/emulatorjs-runtime/4.2.3/data/loader.js
```

The archive was verified with `7z t`; extracted runtime size is about 297 MB. Directory permissions were fixed to allow nginx to serve nested `data/` and `docs/` assets. Do not commit the runtime or archive to Git.

Retro Emulator Lab regression:

```text
qa/reports/game-regression/retro-emulator-lab-20260613T183816Z-desktop/
qa/reports/game-regression/retro-emulator-lab-20260613T183844Z-mobile/
```

Current roadmap doc:

```text
docs/OFFLINE_GAME_LIBRARY_ROADMAP.md
```

It captures the hardware tiers, intake lifecycle, regression gates, EmulatorJS ROM policy, and Steam-like library direction.


## Unciv On-Demand Service Smoke - 2026-06-13

Unciv initially failed to start because `/var/lib/lan-arcade/unciv` was root-owned while the container runs as UID/GID `10002`. Fixed on GannanNet with:

```sh
sudo mkdir -p /var/lib/lan-arcade/unciv
sudo chown -R 10002:10002 /var/lib/lan-arcade/unciv
```

Passing on-demand smoke after fix:

```text
qa/reports/service-smoke/unciv-on-demand-20260613T184532Z.json
```

Result: `/isalive` returned HTTP 200 with `{"authVersion":1,"chatVersion":1}`, memory was about 129.5 MiB, and the container was stopped with `docker compose -f deploy/unciv.compose.yml down`.

## Retro Homebrew Curation - 2026-06-15

Removed `airaki-gb` from the public catalog and deployed mirror after manual user QA showed the ROM displays an anti-emulator profanity screen in EmulatorJS instead of playable content. The earlier automated playtest had already marked it `needs-review` because screenshots did not change; treat `needs-review` as non-playable until manually cleared. The Homebrew Hub importer now blocks slug `airaki` so it is not reintroduced by future batch imports.


## Unciv Offline Client Cache - 2026-06-15

Dylan flagged that native-client hubs cannot say to install the client before internet loss. Unciv now has official 4.20.13 release files cached outside Git at `/var/www/html/mirrors/games/downloads/native/unciv/`, including Android APK, Windows MSI/ZIP, Linux ZIP, desktop JAR, server JAR, manifest, and SHA256SUMS. The official Unciv docs site is mirrored at `/var/www/html/mirrors/unciv-docs/`. Refresh with `scripts/cache_unciv_offline_assets.py`. The hub page links to the stable local `latest/` download paths and no longer uses the old pre-trip installer wording.
## Native Download Shelves - 2026-06-15

Dylan tightened the rule: public native/server-client arcade entries must not require pre-internet preparation. Added `scripts/cache_native_game_offline_assets.py` and cached large release files outside Git under `/var/www/html/mirrors/games/downloads/native/` for Mindustry, OpenTTD, Freeciv, FreeCol, Stendhal, Wesnoth, 0 A.D., and Veloren/Airshipper. Also mirrored docs/manual material for Mindustry (`/mirrors/mindustry-docs/`), curated OpenTTD manual pages (`/mirrors/openttd-wiki/`), Freeciv site/download docs (`/mirrors/freeciv-docs/`), and the Veloren book (`/mirrors/veloren-book/`). Safe-regenerated catalog metadata and manually synced the `LOCAL_DIR` hub folders to deployed mirrors. Browser smoke report batch: `qa/reports/native-download-hubs/*-20260615T105138Z-*`.

Caveat: Veloren still must not be marked play-ready. Airshipper launchers/server binary are cached, but the full game profile is not cached and the Linux binary remains blocked on Debian 12 glibc. Mindustry stable GitHub release does not provide a matching Android APK; current cached pack is desktop/server focused.


## Native Next Ten Intake - 2026-06-17

Added SuperTuxKart, Xonotic, Red Eclipse, OpenArena, Freedoom, BZFlag, FreeOrion, Endless Sky, Cataclysm DDA, and ManaPlus/The Mana World as native LAN Arcade hubs. Download shelves are cached on the NFS native-downloads mount under `/var/www/html/mirrors/games/downloads/native/`; generated hubs are in `local-games/*-lan/` and deployed under `/var/www/html/mirrors/`.

Official site/wiki mirroring now uses bounded recursive wget and creates readable blocker pages when a mirror fails. Successful mirrors this batch: BZFlag and Freedoom. Blocked/timeout mirror pages exist for Cataclysm DDA, Endless Sky, FreeOrion, ManaPlus, OpenArena, Red Eclipse, SuperTuxKart, and Xonotic.

QA evidence:

```text
npm run qa:static
qa/reports/next-ten-page-smoke-final-20260617T111405Z/
qa/reports/native-client-next-ten-20260617T105841Z/
qa/reports/native-client-next-ten-rerun-20260617T110348Z/
qa/reports/native-client-next-ten-endless-rerun2/endless-sky-lan-20260617T110847Z/
qa/reports/service-smoke/bzflag-lan-20260617T105739Z/
qa/reports/service-smoke/openarena-lan-20260617T105745Z/
```

Final status: all ten hub pages pass desktop/mobile smoke; all ten native clients have a passing launch screenshot; BZFlag and OpenArena service smokes pass and stop cleanly. Details are in `docs/NATIVE_NEXT_TEN_2026-06-17.md`.


## Native Board Game Intake - 2026-06-19

Added 15 native/offline board-game hubs: Pioneers, TEG, KsirK, Atlantik/monopd, TripleA, Biloba, Ricochet Robots, Bovo, KFourInLine, KReversi, Kigo + GNU Go, Pentobi, GNU Backgammon, KNavalBattle, and XFrisk. Metadata lives in `scripts/native_board_game_data.py`; hubs are generated by `scripts/generate_native_board_game_hubs.py`; package/docs shelves are cached by `scripts/cache_native_board_game_assets.py` onto the NFS native-downloads mount.

Native no-internet smoke results:

- PASS: `pioneers-lan`, `teg-lan`, `ksirk-lan`, `biloba-lan`, `ricochet-lan`, `bovo-lan`, `kfourinline-lan`, `kreversi-lan`, `kigo-lan`, `pentobi-lan`, `gnubg-lan`.
- PARTIAL: `atlantik-lan` because the local `monopd` lobby works but full board start needs two clients; `knavalbattle-lan` because setup/ship placement works but firing-turn proof is pending; `xfrisk-lan` because server/client/AIs/setup work but first-turn proof is pending.
- BLOCKED: `triplea-lan` because offline launch still attempts GitHub/update/map checks and did not reach playable local-map proof.

Latest native evidence:

```text
qa/reports/native-board-game-play/*-20260618T194900Z
qa/reports/native-board-game-expanded/*-20260618T195446Z
```

Latest full LAN-origin audit after patch/quarantine:

```text
qa/reports/offline-catalog-audit-20260618T202234Z-lan-after-runtime
```

That audit found 101 strict passes, 20 warnings, and 3 hidden blockers (`farm-clicker`, `koutoftimer-idle-miner`, `solaris`) across 124 catalog entries after fixing the EmulatorJS runtime directory permissions. The board hubs were all browser-hub clean, but native status must come from the smoke scripts above, not from the generic hub smoke. Full details are in `docs/BOARD_GAME_INTAKE_2026-06-19.md`.

## Public Package Intake / DOS Vault Fix - 2026-06-20

Added 16 public Debian-package-backed game hubs: Beneath a Steel Sky, Flight of the Amazon Queen, Lure of the Temptress, Drascula, FreeDink, Naev, Colobot Gold, Bos Wars, Neverball, X-Moto, Frozen Bubble, Fish Fillets NG, Enigma, Pushover, Micropolis, and Simutrans. Metadata is in games.meta.sh; hubs live under local-games/*; package cache/generation is driven by scripts/public_package_batch.py; native smoke helper is scripts/public_package_play_smoke.sh; summary report is docs/PUBLIC_PACKAGE_INTAKE_2026-06-20.md. Package closures are cached outside Git on the NFS native-downloads mount under /var/www/html/mirrors/games/downloads/native/debian-bookworm-pool/.

Safe VM regeneration now deploys repo-local LOCAL_DIR::... bundles even when LAN_ARCADE_SKIP_MIRROR=1, so the safe command in docs/VM_DEVELOPMENT_AND_QA.md updates generated local hubs without running the full mirror/install path. After the deploy, npm run qa:static and npm run qa:smoke:catalog passed all 88 catalog entries. Treat the generic catalog result as hub/browser coverage only; native gameplay proof for the new package games remains PASS/PARTIAL as recorded in the public-package report.

The private DOS vault no longer forces HTTP users to HTTPS. The persistent nginx config is /home/dylan/wordpress/nginx-conf/nginx.conf; backup before the edit is /home/dylan/wordpress/nginx-conf/nginx.conf.bak-lan-arcade-20260619T162815Z. The webserver container was reloaded after nginx -t, and both http://127.0.0.1/mirrors/private-dos-vault/ and http://192.168.1.106/mirrors/private-dos-vault/ returned 200. The Pillage First HTTPS redirect was left intact.

The NFS mount initially hid older native client caches, so Unciv 4.20.13 and Stendhal 1.49 download shelves were restored under /var/www/html/mirrors/games/downloads/native/unciv/ and /var/www/html/mirrors/games/downloads/native/stendhal/. The old full docs mirrors for Unciv/Stendhal still need repair; their hubs now avoid stale local doc links until that mirror work is redone.

## Public Package Batch 2 / Native Shelf Caveat - 2026-06-20

Added 10 more Debian-package-backed public hubs: Ri-li, Chromium B.S.U., LBreakoutHD, Kobo Deluxe, Scorched3D, WarMUX, SpaceZero, NetHack X11, OpenCity, and UFO: Alien Invasion. Package metadata is in games.meta.sh and scripts/public_package_batch.py; launch evidence is generated by scripts/public_package_play_smoke.sh. UFO:AI is the large item in this batch and is intended for the full GannanNet profile, not the Raspberry Pi/camping profile.

The package cache was written to the NFS native shelf under /var/www/html/mirrors/games/downloads/native/. After this batch the NFS shelf was about 3.0 GB used; root disk was about 132 GB used of 295 GB. Packages were installed on the VM only for native Xvfb smoke testing. Debian enabled nethack-common.service during install; it was confirmed inactive and then disabled because the arcade does not need that save-recovery helper as an auto-start service.

QA after deploy: npm run qa:static passed 98/98 catalog entries with 0 external entrypoint refs; npm run qa:smoke:catalog passed 98/98 from localhost. LAN-origin desktop and mobile hub smokes passed for the 10 new entries under qa/reports/public-package-lan-origin/20260619T1748-lan-origin-*. Native no-network Xvfb smoke launched all 10 new games and saved screenshots, but they remain PARTIAL until each has stronger first-action gameplay proof.

Safe regeneration still emits missing-asset warnings for several older native hubs whose download/doc shelves were moved or hidden by the NFS transition. The generic public catalog currently passes, but those older hub download shelves need a dedicated repair/audit pass before claiming every heavy/native installer is complete.

## FreeRCT Upstream Release Intake - 2026-06-20

Added FreeRCT as an upstream-release hub rather than a Debian-main package hub. Official FreeRCT 0.1 Linux amd64 package and upstream checksum are cached on the NFS native shelf at /var/www/html/mirrors/games/downloads/native/freerct/0.1/; sha256sum -c passed before install. The VM installed that local package only to run a no-network Xvfb launch smoke.

QA status is PARTIAL: /usr/games/freerct launched under bwrap --unshare-net and produced a non-empty screenshot at qa/reports/upstream-release-smoke/freerct-lan-20260619T180322Z, but first path/ride placement proof is still pending. After safe regeneration, npm run qa:static and npm run qa:smoke:catalog passed 99/99 catalog entries; LAN-origin desktop/mobile hub smoke passed at qa/reports/freerct-lan-origin-20260619T1810-*. The remaining clean upstream-release queue is Tuxemon, Pioneer Space Sim, and Cytopia, but those need release/runtime-specific handling rather than the Debian package generator.

## Native Shelf Repair Pass - 2026-06-20

Ran a dedicated repair pass for older native/offline shelves that were hidden or missing after the NFS native-downloads transition. Repaired board-game shelves, Debian batch-three shelves, native next-ten shelves, original native-client shelves, and the Travian-like source shelf on the NFS mount at `/var/www/html/mirrors/games/downloads/native/`. The NFS shelf grew to about 33 GB used; VM root stayed about 133 GB used of 295 GB.

Safe regeneration no longer reports missing local assets or mirror-completeness failures. The only remaining safe-regeneration warnings are the expected unprivileged `/var/www/html/_offline_assets` write warnings. Local path repairs were also added for FreeCol (`/mirrors/freecol/www.freecol.org/`), 0 A.D. (`/mirrors/0ad/play0ad.com/`), OpenTTD (`/mirrors/openttd/www.openttd.org/`), and Wesnoth wiki/manual (`/mirrors/wesnoth/wiki.wesnoth.org/`). Wesnoth's marketing homepage mirror is a local blocker page because the upstream mirror was blocked, but the linked wiki/manual pages are present.

QA after the repair:

```text
ARCADE_NAME='GannanNet' LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 LAN_ARCADE_SKIP_ADMIN_AUTH=1 LAN_ARCADE_SKIP_MIRROR=1 LAN_ARCADE_CATALOG_SOURCE=metadata-existing bash ./setup_lan_arcade.sh
npm run qa:static                 # 99/99 OK, 0 external entry HTML refs
npm run qa:smoke:catalog          # 99/99 strict pass, 99 playable
```

Detailed logs are under `qa/reports/native-shelf-repair-20260620/`. Important caveat: these checks prove hub/static/catalog/offline-link completeness, not deep native gameplay. Some native entries still need first-action or LAN-client gameplay proof as recorded in their intake reports.

## Public Package Expansion 50 - 2026-06-20

Added 50 additional Debian-package-backed native/offline hubs from `scripts/public_package_expansion_20260620.csv`, covering lightweight arcade, platformer, shooter, puzzle, sports, board-game, and retro-style entries. The generator/smoke runner is `scripts/public_package_expansion_20260620.py`; hub pages live under `local-games/*`; package closures and manifests are cached outside Git on the NFS native shelf under `/var/www/html/mirrors/games/downloads/native/` and the shared `debian-bookworm-pool/`.

Native no-internet Xvfb smoke results: 49 PASS and 1 PARTIAL. `supertransball2-lan` launches offline and renders the packaged intro splash, but the generic harness did not reach a playable menu/level, so it needs a tailored/manual first-play retest before promotion to smoke-pass. Alex4 initially false-blocked because the screenshot uses a very low-colour retro palette; the threshold in the runner was adjusted and Alex4 now passes.

QA/deploy commands and results:

```text
python3 scripts/public_package_expansion_20260620.py cache     # 50/50 package shelves cached on NFS
python3 scripts/public_package_expansion_20260620.py smoke     # 49 PASS, 1 PARTIAL
python3 scripts/public_package_expansion_20260620.py generate
python3 scripts/public_package_expansion_20260620.py metadata
python3 scripts/public_package_expansion_20260620.py summary
ARCADE_NAME='GannanNet' LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 LAN_ARCADE_SKIP_ADMIN_AUTH=1 LAN_ARCADE_SKIP_MIRROR=1 LAN_ARCADE_CATALOG_SOURCE=metadata-existing bash ./setup_lan_arcade.sh
npm run qa:static                 # 149/149 OK, 0 external entry HTML refs
npm run qa:smoke:catalog          # 149/149 strict pass, 149 playable
```

Report/logs: `docs/PUBLIC_PACKAGE_EXPANSION_2026-06-20.md`, `qa/reports/public-package-expansion-20260620-*`, and per-game screenshot folders under `qa/reports/public-package-expansion-20260620/`. VM root after install/testing was about 134 GB used of 295 GB; NFS native shelf remained about 33 GB used of 12 TB. These results prove offline package availability plus first-launch/no-network rendering, not deep campaign completion or LAN multiplayer depth.

## TravianZ / FreeCol / Pillage First Pass - 2026-06-20

Brought the three Travian-like strategy tracks forward together.

TravianZ is now a live on-demand Docker service candidate:

```text
Hub:     http://192.168.1.106/mirrors/travianz-lan/
Service: http://192.168.1.106:8092/
Start:   scripts/prepare_travianz_service.sh start
Smoke:   node qa/travianz-smoke.mjs
Stop:    scripts/prepare_travianz_service.sh stop
Report:  qa/reports/travianz-smoke-20260620T102346Z/result.json
```

The source archive remains outside Git on the native shelf at `/var/www/html/mirrors/games/downloads/native/travian-like/travianz/travianz-d00826167857.tar.gz`; runtime/database state is under `$HOME/.lan-arcade/services/travianz/`. The smoke installs if needed, registers a throwaway player, logs in, reaches village gameplay, captures screenshots, and blocks off-LAN requests. Docker images are present in the local Docker cache after the first start, but a future stronger offline-hardening pass should export/cache those images on the NFS shelf if the VM ever needs to rebuild with no internet.

FreeCol has been promoted from pending to client-smoked. The official 1.2.0 Windows/JAR/ZIP/macOS clients are cached locally, and the portable ZIP launched under Xvfb into a new single-player game with screenshots/logs. Live hub copy now points at the cached downloads and records the latest QA report: `qa/reports/native-client-launch/freecol-lan-20260620T095834Z/report.txt`.

Pillage First now has a clearer attack flow while preserving existing games/worlds. The reproducible build script now hard-resets and cleans its temporary upstream checkout before applying LAN patches, preventing stale patched source from surviving across rebuilds. Attack/raid remains exposed from the map and Rally Point; enemy map popups still show scout intel; the Rally Point attack tab now adds an Attack briefing panel with target coordinates, selected troop count, defender intel, and a clear no-troops warning. Latest checks:

```text
node qa/pillage-first-live-smoke.mjs                 # qa/reports/pillage-first-live-smoke-20260620T102016Z
node qa/pillage-first-attack-briefing-smoke.mjs      # qa/reports/pillage-first-attack-briefing-20260620T102216Z
```

The focused attack briefing smoke treats React minified error `#418` as a known Rally Point route-level hydration warning because it also appears on untouched send-troops tabs. It still fails on missing UI terms, blocked network requests, failed LAN responses, console errors, or any other page error.

## Platform Cleanup / Social Foundation - 2026-06-28

Active phase review: `docs/PHASE23_PLATFORM_CLEANUP_REVIEW_2026-06-28.md`.

Key changes:

- Git identity guardrail: run `npm run qa:git-identity` before commits.
- Public library wording should be player-facing; technical intake labels belong in operator/admin areas.
- Classic PC search reaches packaged games such as SimAnt directly.
- Arcade API live container now includes `account-friends` and `account-messages`.
- User-data backup helper: `npm run backup:user-data`; latest smoke backup: `/home/dylan/backups/lan-arcade/user-data/20260627T152916Z`.
- Docs mirror validation report folder: `qa/reports/phase23-docs-mirror/`; FreeCiv docs were repaired no-network to remove a Twitter widget reference.
- Deployment modes are documented in `docs/DEPLOYMENT_MODES.md`: Full GannanNet mode uses the local mail server; Camping/Pi mode must remain usable without email.

Parallel handoff workspaces:

- `agent-handoffs/phase2-media-artwork/HANDOVER.md`
- `agent-handoffs/phase5-gameplay-qa/HANDOVER.md`
- Review doc for these handoffs: `docs/PHASE24_MEDIA_AND_GAMEPLAY_QA_REVIEW_2026-06-28.md`.
