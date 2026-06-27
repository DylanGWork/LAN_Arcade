# Phase 21 EvoLab Account Save Scope Review - 2026-06-27

## Scope

Added account-aware save isolation to EvoLab without changing gameplay rules.
EvoLab uses IndexedDB through Dexie, so this phase intentionally did not use the
simple localStorage account-save adapter from other browser games.

## Changes

- Added an EvoLab account scope helper that reads the LAN Arcade account session
  from `lanArcadeAccount.v1`.
- Kept guest saves on the existing `EvoLabDB` database for backwards
  compatibility.
- Scoped signed-in account saves to per-account IndexedDB databases named
  `EvoLabDB_account_<account-id>` after sanitising the account id.
- Scoped EvoLab leaderboard localStorage keys per signed-in account.
- Added a Save/Load panel message showing whether EvoLab is saving as Guest or a
  signed-in account.
- Extended the existing Pixi shader error filter to cover the newer headless
  Chromium `reading 'set'` variant seen during QA.
- Rebuilt and redeployed the EvoLab static bundle under `/mirrors/evolab/`.

## Review

- This isolates EvoLab simulations, creatures, settings, achievements, and
  local leaderboard entries between signed-in accounts on the same browser.
- Guest behaviour remains compatible with existing browser-local EvoLab saves.
- This is not yet cross-device save sync. EvoLab IndexedDB export/import still
  needs a separate proven adapter before account saves can roam between devices.
- The account smoke used a fake localStorage session only; it did not create,
  mutate, or delete real LAN Arcade accounts.

## Validation

Commands run on the GannanNet VM:

```bash
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" -w /work \
  node:24-bookworm-slim sh -lc 'npm run type-check && npx vitest run tests/data/SaveSystem.test.ts && npm run build'

ARCADE_NAME="GannanNet" \
LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 \
LAN_ARCADE_SKIP_ADMIN_AUTH=1 \
LAN_ARCADE_SKIP_MIRROR=1 \
LAN_ARCADE_CATALOG_SOURCE=metadata-existing \
bash ./setup_lan_arcade.sh

npm run qa:static
npm run qa:smoke -- --catalog --game evolab --report-dir qa/reports/phase21-evolab-smoke
npm run qa:library-discovery -- --report-dir qa/reports/phase21-library-discovery
