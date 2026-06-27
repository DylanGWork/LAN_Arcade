# Phase 22 Review: Account Favourites

Date: 2026-06-27

## Scope

Added per-account favourites to the LAN Arcade library while keeping guest favourites browser-local. This phase extends the existing account/session, recent activity, and save-vault model instead of adding a separate identity system.

## Changes

- Added `FavoriteGame` shared type.
- Added `account_favorites` SQLite table with account-scoped rows and cascade cleanup.
- Added arcade API endpoints:
  - `GET /account/favorites`
  - `PUT /account/favorites`
  - `DELETE /account/favorites/:gameId`
- Added `account-favorites` to `/arcade-api/server-info` capabilities.
- Added Save/Saved controls to game cards.
- Added a top-of-library `Favourites` shelf.
- Guest favourites use `localStorage` under `lanArcadeFavorites.v1`.
- Signed-in favourites sync to the arcade account and also keep a local browser cache for fast rendering.
- Updated discovery QA so cards can be proper articles with inner launch links and separate favourite buttons.

## Deployment

- API container rebuilt and restarted with `docker compose -f deploy/lan-arcade-api.compose.yml up -d --build lan-arcade-api`.
- Public library regenerated with safe VM flags:
  - `LAN_ARCADE_SKIP_PACKAGE_INSTALL=1`
  - `LAN_ARCADE_SKIP_ADMIN_AUTH=1`
  - `LAN_ARCADE_SKIP_MIRROR=1`
  - `LAN_ARCADE_CATALOG_SOURCE=metadata-existing`

## Backup

Before migration/deploy, live API DB was backed up to:

`/var/lib/lan-arcade/backups/20260627T120655Z-phase22-account-favorites.sqlite`

Note: one extra badly named backup was also created during a timestamp quoting retry:

`/var/lib/lan-arcade/backups/-phase22-account-favorites.sqlite`

It was intentionally left in place rather than deleted during deployment.

## Verification

Passed:

- `npm run build -w @lan-arcade/shared`
- `npm run build -w @lan-arcade/arcade-api`
- `npm run test -w @lan-arcade/arcade-api`
- `npm run qa:static`
- `npm run qa:library-discovery -- --report-dir qa/reports/phase22-library-discovery`
- Live `/arcade-api/health` check through nginx route.
- Live `/arcade-api/server-info` shows `account-favorites` capability.
- Live DB migration check confirmed `account_favorites` table exists.
- Signed-in API smoke created a disposable account, saved SimAnt as a favourite, listed it, removed it, and cleaned the account.
- Deployed HTML contains `favoriteShelf`, `favorite-button`, and `card-link`.

## Review Notes

- The old discovery smoke expected cards to be anchor elements. That was updated because favourites need real buttons, and nested buttons inside anchors are invalid and brittle.
- This phase does not yet sync emulator save files. It only provides a personal-library primitive that future save/profile work can build on.
- Favourites are currently surfaced as a compact top shelf showing the first three items; the full favourites view/filter can be added in the next library UX phase.

## Next Safe Phase

Recommended next phase: add a full `My Library` view with favourites, recently played, continue/resume candidates, and device-friendly filters. That should reuse this account-favourites API rather than adding another storage path.
