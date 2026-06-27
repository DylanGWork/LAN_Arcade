# Phase 13 Account Save Status Review - 2026-06-27

Status: complete.
Scope: user-visible save/account status for browser games already integrated with the account save helper.

## What Changed

- Extended `local-games/shared/account-save.js` to update an optional status element.
- Added a compact `Save:` status line inside the command panel for:
  - `breachline-tactics`
  - `circuit-foundry`
  - `outpost-siege`
- Status states now distinguish:
  - guest browser save
  - signed-in account
  - syncing
  - synced
  - browser fallback if account save upload fails

## Review Findings

- The status is inside existing command panels, not over the canvas, so it avoids covering gameplay.
- The wording is user-facing rather than operator/admin wording.
- This change does not alter save ownership rules from Phase 12.
- The helper still keeps emulator/DOS runtimes untouched.

## Checks Run

```sh
node --check local-games/shared/account-save.js
node --check local-games/breachline-tactics/game.js
node --check local-games/circuit-foundry/game.js
node --check local-games/outpost-siege/game.js
ARCADE_NAME='GannanNet' LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 LAN_ARCADE_SKIP_ADMIN_AUTH=1 LAN_ARCADE_SKIP_MIRROR=1 LAN_ARCADE_CATALOG_SOURCE=metadata-existing bash ./setup_lan_arcade.sh
npm run qa:static
npm run qa:smoke -- --catalog --game breachline-tactics --report-dir qa/reports/phase13-save-status-breachline
npm run qa:game -- breachline-tactics
npm run qa:game -- circuit-foundry
npm run qa:game -- outpost-siege
```

Focused status checks:

- Verified deployed HTML for all three games contains `accountSaveStatus`.
- Created a temporary signed-in local account and opened Breachline Tactics.
- Verified the status showed `Save: <username>`.
- Removed the temporary `codexp13*` account from the API container database.

Regression results:

- Static mirror audit: 152/152 OK, 0 external dependency refs.
- `breachline-tactics`: desktop playable, mobile playable.
- `circuit-foundry`: desktop playable, mobile playable.
- `outpost-siege`: desktop playable, mobile playable.

## Known Limits

- The status is available only in games using the shared browser save helper.
- EmulatorJS, js-dos, native games, and LAN services still need separate account/save status designs.
- The current line intentionally stays brief; a future platform-level launcher can provide fuller account/save explanations outside the game canvas.

## Phase Review Decision

Proceed only to one of these next bounded tasks:

1. Non-destructive EmulatorJS/js-dos save export/import experiment.
2. Add account-save integration to EvoLab after a focused review of its `SaveSystem`.
3. Continue user-facing library wording cleanup now that account and save primitives exist.
