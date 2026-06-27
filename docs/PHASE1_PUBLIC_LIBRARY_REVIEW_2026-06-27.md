# Phase 1 Public Library Review - 2026-06-27

Scope: public-facing wording and launcher navigation cleanup for `/mirrors/games/`, the Classic PC shelf, and Classic PC browser player.

## Changes

- Replaced library sidebar/admin-style wording with player-facing labels: `Retro shelves`, `Needs setup`, `Ready now`, `Guest friendly`, `Classic PC Games`, and `Board Game Shelf`.
- Replaced public count labels such as `top-level cards`, `research rows`, and `listed old PC game entries` with user-facing library counts.
- Normalized Classic PC nested search statuses so cards show `Ready to try`, `Needs files`, `Starts, needs testing`, or `Needs attention` rather than raw intake states.
- Updated Classic PC collection copy from DOS/admin framing toward player-facing Classic PC wording.
- Updated Classic PC player side panel headings from `Browser Check` / `Offline Files` to `How This Runs` / `Offline Game Files`.
- Preserved internal status keys in manifests, data attributes, and filters so the tooling still works.

## Review Results

- `bash -n setup_lan_arcade.sh`: pass.
- `python3 -m py_compile scripts/build_private_dos_vault.py`: pass.
- `npm run qa:static`: pass, 152 scanned, 152 OK, 0 external entrypoint refs.
- HTTP checks: `/mirrors/games/`, `/mirrors/private-dos-vault/`, and `play.html?id=simant-ma` returned 200.
- Playwright desktop flow:
  - Search `simant` on `/mirrors/games/` shows SimAnt from the Classic PC shelf.
  - Clicking SimAnt opens `/mirrors/private-dos-vault/play.html?id=simant-ma`.
  - Returning to `/mirrors/games/` shows SimAnt under Recently played.
- Playwright visible-text scan found no public matches for: `source-ready`, `top-level`, `research rows`, `admin-hidden`, `No Play Yet`, `Game package is not cached`, `No gameplay smoke`, `Planned game`, `Browser Check`, `28 Listed`, or `old PC games`.
- Pixel 5 checks: no horizontal overflow on `/mirrors/games/` or `/mirrors/private-dos-vault/`.

## Known Limits

- The admin page still contains admin wording by design.
- Some generated native game hub pages still expose QA/status language. Those are outside this phase and should be handled in the next public-page wording pass.
- `_offline_assets` warnings still appear during unprivileged regeneration. They are pre-existing safe-regeneration warnings and did not block deployment.
