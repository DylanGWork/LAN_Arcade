# Native Next Ten Intake - 2026-06-17

This intake adds the next ten heavier/native games to the LAN Arcade using the offline-client rule: if the public catalog links a native game, the installers/archives needed to try it should be cached locally, not merely described.

## Games Added

- `supertuxkart-lan` - SuperTuxKart kart racing
- `xonotic-lan` - Xonotic arena FPS
- `redeclipse-lan` - Red Eclipse movement FPS
- `openarena-lan` - OpenArena classic arena FPS
- `freedoom-lan` - Freedoom plus Doom engines
- `bzflag-lan` - BZFlag tank combat
- `freeorion-lan` - FreeOrion space 4X
- `endless-sky-lan` - Endless Sky space RPG
- `cataclysm-dda-lan` - Cataclysm: Dark Days Ahead survival roguelike
- `manaplus-lan` - ManaPlus / The Mana World 2D MMORPG pathfinder

## Offline Download Shelves

Release files are cached outside Git on the native-downloads NFS mount and served under:

```text
/var/www/html/mirrors/games/downloads/native/<slug>/
http://127.0.0.1/mirrors/games/downloads/native/<slug>/
```

Each shelf has `index.html`, `manifest.json`, per-version `SHA256SUMS.txt`, and a `latest` symlink where supported. NFS usage after the batch was about 27G used on the 12T native-download shelf.

## Official Site / Wiki Mirrors

Bounded recursive wget mirroring was attempted for each upstream site/manual. Successful mirrors:

- `/var/www/html/mirrors/bzflag-site/`
- `/var/www/html/mirrors/freedoom-site/`

Blocked or timed-out mirrors have readable local blocker pages at their intended mirror URL instead of a fake manual:

- `/var/www/html/mirrors/cataclysm-dda-site/` - wget status 8
- `/var/www/html/mirrors/endless-sky-site/` - wget status 8
- `/var/www/html/mirrors/freeorion-site/` - wget status 8
- `/var/www/html/mirrors/manaplus-site/` - wget status 4
- `/var/www/html/mirrors/openarena-site/` - timeout status 124
- `/var/www/html/mirrors/redeclipse-site/` - wget status 8
- `/var/www/html/mirrors/supertuxkart-site/` - wget status 8
- `/var/www/html/mirrors/xonotic-site/` - wget status 4

The blocker pages are deliberate QA signals. They should be replaced by deeper/manual mirrors later, not hidden.

## QA Evidence

Static/browser checks after deployment and screenshot promotion:

```text
npm run qa:static
qa/reports/next-ten-page-smoke-final-20260617T111405Z/
```

Result: all ten new hub pages passed desktop and mobile catalog smoke with `failed=0`, `warnings=0`, `blockers=0`.

Native client launch smoke evidence:

```text
qa/reports/native-client-next-ten-20260617T105841Z/
qa/reports/native-client-next-ten-rerun-20260617T110348Z/
qa/reports/native-client-next-ten-endless-rerun2/endless-sky-lan-20260617T110847Z/
```

Final launch status:

- Pass: SuperTuxKart, Red Eclipse, OpenArena, Freedoom, BZFlag, ManaPlus, Xonotic.
- Pass after path/delay fix: FreeOrion, Cataclysm DDA.
- Pass after removing custom `--config` path: Endless Sky.

Service smoke evidence:

```text
qa/reports/service-smoke/bzflag-lan-20260617T105739Z/
qa/reports/service-smoke/openarena-lan-20260617T105745Z/
```

Results:

- BZFlag `bzfs` listened on UDP 5154 and was stopped.
- OpenArena dedicated ioquake3 server listened on UDP 27960 and was stopped.

## Notes For Next Agent

- The new hub pages live under `local-games/<slug>/` and deploy to `/var/www/html/mirrors/<slug>/`.
- `scripts/cache_native_next_ten_assets.py` handles the download shelves and bounded docs mirrors.
- `scripts/generate_native_next_ten_hubs.py` regenerates the hub pages from shelf manifests and existing screenshots.
- `scripts/native_client_launch_smoke.sh` now normalizes report roots to absolute paths and supports these ten IDs.
- `scripts/native_service_smoke.sh` now supports `bzflag-lan` and `openarena-lan`.
- Avoid unquoted shell regexes with `|` over SSH. During this intake, an unquoted process-check regex accidentally launched commands named `bzflag`, `ioquake3`, `doom`, etc. Cleanup was done with exact process names; no game processes remained afterward.
