# Phase 6 Account Picker Review - 2026-06-27

## Scope

Added the first public account surface to the main game library without gating play.

Implemented in `setup_lan_arcade.sh` and regenerated the deployed `/mirrors/games/` page with safe VM flags.

## Changes

- Added a `Player` panel to the game library sidebar.
- Guest mode remains the default and requires no setup.
- Added sign-in and create-account controls backed by `/arcade-api/`.
- Stored account session details in browser local storage.
- Scoped recently played entries by account id when signed in.
- Preserved the existing guest recently-played key for visitors and old browsers.

## Review Results

- `bash -n setup_lan_arcade.sh`: pass.
- Safe regeneration completed with `LAN_ARCADE_SKIP_PACKAGE_INSTALL=1`, `LAN_ARCADE_SKIP_ADMIN_AUTH=1`, `LAN_ARCADE_SKIP_MIRROR=1`, `LAN_ARCADE_CATALOG_SOURCE=metadata-existing`.
- `npm run qa:static`: pass, 152 scanned, 152 OK, 0 external refs in entry HTML.
- `/arcade-api/health`: pass.
- `/arcade-api/accounts`: pass.
- `npm run qa:smoke -- --limit 1 --report-dir qa/reports/phase6-account-panel`: pass, 1/1 strict, playable.
- Browser JS smoke: pass. `#accountPanel` rendered Guest mode, `SimAnt` deep search returned results, no console/page errors.

## Known Limits

- Recently played is still browser-local; it is separated by signed-in account only on the same browser.
- Emulator saves, DOS saves, achievements, and app-specific game accounts are not yet server-backed or isolated by account.
- Email verification/password reset is not wired into the arcade UI yet.
- Account creation from the public page creates live accounts; automated browser smoke avoided creating disposable accounts.

## Next Safe Phase

Phase 7 should add server-side account activity/saves groundwork instead of relying only on browser local storage. Keep ROM/game assets shared and user data account-scoped.
