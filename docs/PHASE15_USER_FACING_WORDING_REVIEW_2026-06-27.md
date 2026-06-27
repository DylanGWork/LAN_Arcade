# Phase 15 User-Facing Wording Review - 2026-06-27

## Scope

Cleaned the public game library wording so the main arcade reads more like a player-facing gaming appliance and less like an operator/intake dashboard.

## Changes

- Renamed the public `Native / services` profile and shelf to `Installed & LAN games`.
- Reworded the library help note so nested collections are described as shelves rather than top-level launcher plumbing.
- Changed the Classic PC status chip from `classic PC games ready` to `ready Classic PC games`.

## Review

Confirmed the deployed `/mirrors/games/` page contains:

- `Installed & LAN games`
- `Large collections open as shelves`
- `ready Classic PC games`

Confirmed the deployed page no longer contains these public-facing phrases:

- `Native / services`
- `top-level cards`
- `listed old PC`
- `playable old PC`

## Checks

- `bash -n setup_lan_arcade.sh`
- `python3 -m py_compile scripts/build_private_dos_vault.py`
- `git diff --check -- setup_lan_arcade.sh`
- Safe VM regeneration with package/admin/mirror steps skipped
- `npm run qa:static`

Static QA result: 152 games scanned, 152 OK, 0 needing attention, 0 external dependency refs in entry HTML.

## Known Limits

This phase only changed obvious public wording in the main catalogue generator. Internal terms such as `metadata`, `candidate`, and `source-ready` remain in scripts/manifests where they are implementation details or machine-readable states.
