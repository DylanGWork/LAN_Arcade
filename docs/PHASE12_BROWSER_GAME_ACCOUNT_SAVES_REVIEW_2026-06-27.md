# Phase 12 Browser Game Account Saves Review - 2026-06-27

Status: complete.
Scope: first account-save adapter for small browser games only. EmulatorJS, js-dos, native, and LAN-service saves were intentionally left unchanged.

## What Changed

- Added `local-games/shared/account-save.js`.
- Updated safe regeneration to deploy shared browser-game assets to `/var/www/html/mirrors/shared/`.
- Wired account-aware save slots into:
  - `local-games/breachline-tactics/`
  - `local-games/circuit-foundry/`
  - `local-games/outpost-siege/`
- Each patched game now uses account-specific localStorage keys when signed in.
- Signed-in saves are uploaded to `/arcade-api/account/saves` with adapter `browser-localstorage`.
- Guest mode still uses the legacy localStorage save keys.
- Existing legacy browser saves are claim-imported into the first signed-in account only; later accounts do not automatically inherit another account's claimed legacy save.

## Review Findings

- This phase addresses the lowest-risk save isolation class identified in Phase 11.
- It does not make emulator/DOS saves family-safe yet; those still need runtime-specific export/import validation.
- It does not solve cross-device sync for every game type yet, but these three browser games now have the server-side save path needed for cross-device account restores.
- The account session is still cached in browser localStorage for convenience; the authoritative save copy is now the account save API for these games.

## Checks Run

```sh
bash -n setup_lan_arcade.sh
node --check local-games/shared/account-save.js
node --check local-games/breachline-tactics/game.js
node --check local-games/circuit-foundry/game.js
node --check local-games/outpost-siege/game.js
ARCADE_NAME='GannanNet' LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 LAN_ARCADE_SKIP_ADMIN_AUTH=1 LAN_ARCADE_SKIP_MIRROR=1 LAN_ARCADE_CATALOG_SOURCE=metadata-existing bash ./setup_lan_arcade.sh
npm run qa:static
npm run qa:game -- breachline-tactics
npm run qa:game -- circuit-foundry
npm run qa:game -- outpost-siege
```

Targeted account-save browser test:

- Created two temporary local accounts.
- Opened Breachline Tactics signed in as account A.
- Started a run and verified a `PUT /arcade-api/account/saves` occurred.
- Verified account A had one `breachline-tactics` save.
- Verified account B had zero `breachline-tactics` saves.
- Verified the saved payload had `started: true` and three playable units.
- Removed the temporary `codexp12*` accounts from the API container database.

Regression results:

- `breachline-tactics`: desktop playable, mobile playable.
- `circuit-foundry`: desktop playable, mobile playable.
- `outpost-siege`: desktop playable, mobile playable.
- Static mirror audit: 152/152 OK, 0 external dependency refs.

## Known Limits

- If a household browser has an old guest save, the first signed-in account that opens that game may claim it. That is deliberate to avoid losing existing local progress, but it is not a full migration wizard.
- Save upload is debounced and best-effort. If the API is down, the browser save still works and the next save attempt can upload again.
- Account save restore happens after page load. The game starts from local account cache immediately, then updates if the server has a newer saved payload.
- EmulatorJS/js-dos save isolation is still pending.

## Phase Review Decision

Proceed to the next phase only if it is one of these bounded tasks:

1. Add the same browser-localStorage adapter to more original browser games with explicit save keys.
2. Add account/save status indicators to game pages so users know whether they are playing as Guest or a signed-in account.
3. Build a non-destructive EmulatorJS/js-dos save export/import experiment without changing production launcher behavior.

Do not globally patch emulator or DOS saves yet.
