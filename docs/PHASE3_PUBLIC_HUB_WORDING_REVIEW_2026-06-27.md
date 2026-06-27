# Phase 3 Public Hub Wording Review - 2026-06-27

Scope: remove remaining system/operator wording from public launcher and hub pages while preserving technical evidence for operators.

## Changes

- Added `scripts/polish_public_wording.py`, a repeatable post-generation public wording pass for top-level launcher pages under `local-games/*/index.html` and `local-games/*/play.html`.
- Reworded visible labels such as `QA Status`, `QA Evidence`, `QA Result`, `Regression Status`, `NFS-backed shelf`, `Latest report`, and `HTTP 200 does not count...` into player-facing wording.
- Replaced public status pills like `QA PARTIAL` with `PARTIALLY TESTED`.
- Replaced exposed operator implementation terms such as `bwrap --unshare-net` with `offline test mode`.
- Kept detailed QA paths and operator notes out of the public page body; detailed test logs remain available in repo/QA docs.

## Deployment

- Applied the polish pass to local launcher files.
- Copied changed public launcher HTML files into `/var/www/html/mirrors/<game>/` without recopying large game/source folders.
- Deployment copy count: 127 launcher files.

## Review Results

- Live wording scan across `/var/www/html/mirrors/*/{index,play}.html`: no hits for targeted admin phrases.
- `npm run qa:static`: pass, 152 scanned, 152 OK, 0 external entrypoint refs.
- Representative live page check: `knavalbattle-lan` now shows `PARTIALLY TESTED`, `Test Notes`, `Play Check`, and no `QA PARTIAL`, `NFS-backed`, `Latest report`, or `bwrap` text.

## Known Limits

- This phase does not redesign every native hub layout; it only removes confusing public terminology.
- Technical terms may still appear in source manifests, attribution files, docs, and operator reports. That is intentional.
- Future hub generators should either use player-facing strings directly or run `scripts/polish_public_wording.py` after generation.
