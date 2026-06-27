# Phase 11 Save Surface Inventory Review - 2026-06-27

Status: complete.
Scope: read-only inventory tooling and review only. No game data, launcher behavior, or account behavior was changed in this phase.

## What Changed

- Added `scripts/audit_save_surfaces.py`, a repeatable scanner for known LAN Arcade save/profile surfaces.
- Ran the scanner against the repo and selected deployed mirror launcher pages.
- Left existing unrelated dirty intake/game-ops files untouched.

## Checks Run

```sh
python3 -m py_compile scripts/audit_save_surfaces.py
python3 scripts/audit_save_surfaces.py --repo . --mirrors /var/www/html/mirrors --output /tmp/save-surface-inventory-phase11.md
```

Inventory result:

- Matching files: 59
- Matching sampled lines: 334
- browser_storage: 41
- emulatorjs: 131
- js_dos: 38
- indexeddb_filesystem: 7
- game_save_terms: 95
- account_save_api: 22

## Confirmed Findings

1. The account save vault API exists, but current game launchers do not yet write gameplay saves to it.
2. The generated game library uses `localStorage` for account session convenience and per-account recent-play cache; server-side recent activity is already present and should be treated as the stronger source.
3. The generated account page reads the account save vault API and displays synced saves, but it currently depends on tests/manual inserted saves until adapters are added.
4. Several small browser games have explicit `localStorage` save keys and are the safest first adapter candidates.
5. EvoLab has its own save/load and achievement systems and should be handled as a separate browser-game adapter after a focused smoke test.
6. EmulatorJS pages are widespread. Save behavior should be treated as runtime-specific until export/import is validated per core.
7. The private DOS vault uses js-dos/DOSBox packaging. Browser play works for some packages, but save sync needs a separate non-destructive export/import experiment before account integration.
8. Native/server games should keep their own server-side or game-native save/account storage; the arcade account system should track ownership/activity and launch context, not blindly copy game databases.

## Risks

- A signed-in arcade account currently isolates recent activity, not all game saves.
- On a shared browser, game saves that still use unscoped `localStorage`, IndexedDB, EmulatorJS storage, or js-dos storage can still be overwritten by another household user.
- Emulator/js-dos save syncing could corrupt progress if implemented before runtime-specific save export/import is proven.
- Browser games with localStorage keys need exact key mapping before migration, or old saves may appear missing.

## Phase Review Decision

Proceed, but only to a narrow next phase:

- Build a shared account-save client/helper for browser games.
- Integrate one or two low-risk browser games with explicit `SAVE_KEY` constants first.
- Keep legacy localStorage fallback and one-time import so existing saves are not lost.
- Do not wire EmulatorJS or js-dos saves to accounts yet.

Recommended first candidates from the scan:

- `local-games/breachline-tactics/game.js`
- `local-games/circuit-foundry/game.js`
- `local-games/outpost-siege/game.js`

Acceptance for the next phase:

- Signed-in user save writes to `/arcade-api/account/saves`.
- Existing localStorage save is imported once into the signed-in account save slot.
- Guest mode still uses browser localStorage.
- A second account does not see or overwrite the first account's save.
- Static QA and at least one Playwright account save round-trip pass.
