# Phase 2 Site/Wiki Mirror Workflow Review - 2026-06-27

Scope: recover and standardize the website/wiki/manual mirroring workflow Dylan remembered from earlier LAN Arcade work.

## Changes

- Added `scripts/mirror_game_docs.py`, a reusable safe mirror runner for official game sites, wikis, manuals, and guide pages.
- Added `config/site-mirror-recipes.json` with initial recipes for OpenTTD, Mindustry, Freeciv, SuperTuxKart, Xonotic, and Freedoom.
- Added `docs/OFFICIAL_SITE_MIRRORING.md` with the standard workflow and promotion rules.
- Added no-network `--validate-only` and `--repair-existing` modes so existing mirrors can be audited and fixed without re-crawling the internet.

## Existing Mirror Repairs Applied

- `/var/www/html/mirrors/openttd-wiki/`
  - Before: 12 HTML pages, no root `index.html`.
  - Repair: generated root offline guide index.
  - After: 13 HTML pages, root index present, no common external tracker/font refs detected.
- `/var/www/html/mirrors/mindustry-docs/`
  - Before: 1,128 HTML pages, root index present, external `fonts.gstatic.com` references detected.
  - Repair: stripped common external font/tracker/search references from 1,128 HTML files.
  - After: root index present, no common external tracker/font refs detected.

## Review Results

- `python3 -m py_compile scripts/mirror_game_docs.py`: pass.
- Focused `run_wget` command-construction check: pass; `--level 2` and `--no-parent` are emitted correctly before source URLs.
- `python3 scripts/mirror_game_docs.py --recipe config/site-mirror-recipes.json --slug openttd-wiki --repair-existing`: pass.
- `python3 scripts/mirror_game_docs.py --recipe config/site-mirror-recipes.json --slug mindustry-docs --repair-existing`: pass.
- `http://127.0.0.1/mirrors/openttd-wiki/`: 200 and root guide text present.
- `http://127.0.0.1/mirrors/mindustry-docs/`: 200 and Mindustry page text present.
- Reports written under `qa/reports/docs-mirror-phase2/`.

## Known Limits

- Existing cache scripts still contain duplicated wget snippets. This phase adds the standard runner but does not migrate every importer to it yet.
- Refreshing live sites can still be blocked by anti-bot pages or site layout changes. The script records blockers rather than pretending a mirror exists.
- Mirrored official sites are offline information/manual assets only. They do not prove the game itself launches or plays.
