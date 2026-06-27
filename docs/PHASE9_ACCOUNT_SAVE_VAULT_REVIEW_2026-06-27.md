# Phase 9 Account Save Vault Review - 2026-06-27

## Scope

Added account-scoped save storage primitives to the arcade API. This phase does not yet migrate emulator, DOS, browser-game, or Pillage First saves into the vault.

## Changes

- Added shared save types:
  - `SavePayloadEncoding`
  - `AccountSaveSlot`
  - `UpsertAccountSaveRequest`
- Added SQLite table `account_save_slots` keyed by account, adapter, game id, and slot.
- Added save metadata fields: label, payload encoding, size, SHA-256 checksum, metadata JSON, created/updated timestamps.
- Added authenticated API routes:
  - `PUT /account/saves`
  - `GET /account/saves?adapter=&gameId=&limit=&includePayload=1`
  - `GET /account/saves/:adapter/:gameId/:slot`
- Added `account-save-vault` to `/server-info` capabilities.
- Added API regression tests for write, list, fetch, checksum, metadata, and overwrite behaviour.

## Review Results

- `npm run test -w @lan-arcade/arcade-api`: pass, 6/6 tests.
- `npm run build`: pass.
- Rebuilt and restarted `lan-arcade-api` container.
- Live container route smoke: pass. Temporary account wrote/listed/fetched `browser-localstorage/2048/autosave`, then temporary account/player/save rows were removed.
- Live nginx proxy route smoke through `/arcade-api/`: pass. Temporary account wrote/fetched `js-dos/simant-ma/autosave`, then temporary account/player/save rows were removed.
- `/arcade-api/server-info`: pass, includes `account-save-vault`.
- `/arcade-api/health`: pass.

## Known Limits

- No launcher adapter writes saves to this vault yet.
- Payloads are stored as text in SQLite and capped at 512 KiB by API validation; large emulator save states will need file/blob storage or chunking.
- No delete endpoint yet.
- No retention, export, restore, or per-game save browser UI yet.
- Save isolation is now possible at the API layer, but games still need adapter-specific integration.

## Next Safe Phase

Inventory each launcher adapter and wire the lowest-risk save sync first, likely simple browser-localStorage games before js-dos or emulator IndexedDB saves.
