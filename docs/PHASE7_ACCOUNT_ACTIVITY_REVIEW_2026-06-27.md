# Phase 7 Account Activity Review - 2026-06-27

## Scope

Added server-backed account activity for recently played games. This is groundwork for account-based saves and progress without changing game launch behaviour.

## Changes

- Added shared activity types:
  - `RecentGameActivity`
  - `RecordGameActivityRequest`
- Added SQLite table `account_activity` with one row per account/game/path and a play count.
- Added API routes:
  - `POST /account/activity`
  - `GET /account/activity/recent?limit=12`
- Added `account-activity` to `/server-info` capabilities.
- Updated the main game library generator so signed-in users sync recent-play events through `/arcade-api/`.
- Guest mode still uses browser-only local storage.

## Review Results

- `bash -n setup_lan_arcade.sh`: pass.
- `npm run test -w @lan-arcade/arcade-api`: pass, including account activity test.
- `npm run build`: pass.
- Safe regeneration completed with package/admin/mirror skips enabled.
- Rebuilt and restarted `lan-arcade-api` container.
- `npm run qa:static`: pass, 152 scanned, 152 OK, 0 external refs in entry HTML.
- Live `/arcade-api/server-info`: pass, includes `account-activity`.
- Live authenticated API smoke: pass. Temporary account created, SimAnt activity recorded, recent list returned it, temporary account/player/activity removed.
- Browser integration smoke: pass. Signed-in account rendered, SimAnt deep-search card clicked, recent-play reached API, no console/page errors, temporary account removed.
- `npm test`: pass.
- `npm run qa:smoke -- --limit 1 --report-dir qa/reports/phase7-account-activity`: pass.
- Live container health: `lan-arcade-api` up; `/arcade-api/health` pass.

## Known Limits

- This records recently played games only. It does not yet store emulator saves, DOSBox disk changes, game settings, achievements, or full save states.
- The UI sends activity on card click with `fetch(..., keepalive: true)`; extremely abrupt browser termination could still miss an event.
- Existing guest recently-played history is not migrated into a newly signed-in account.
- No account management UI exists yet for password reset, email verification, child controls, or account deletion.

## Next Safe Phase

Add an account settings/profile page and begin save-location inventory per launcher adapter: browser games, DOS/js-dos, Game Boy emulator, native service hubs, and Pillage First.
