# Phase 4 Account Foundation Review - 2026-06-27

Scope: add a safe API-level foundation for real LAN Arcade accounts without changing the public static library or forcing login yet.

## Changes

- Extended shared API types with `ArcadeAccount`, `AccountSession`, account roles/status, and create/login payloads.
- Added SQLite `accounts` and `account_sessions` tables in `services/arcade-api`.
- Added a nullable `players.account_id` migration so existing PIN/player profiles keep working while new accounts can own a player profile.
- Added account endpoints:
  - `POST /accounts` creates a local account, derives `<username>@gannan.home.arpa`, links/creates a player profile, and returns an account session token.
  - `POST /auth/login` creates a new account session from username/password.
  - `GET /auth/me` returns the current account/player for `x-arcade-account-session`.
  - `GET /accounts` lists local accounts for local admin/debug use.
- Preserved legacy profile endpoints: `/players`, `/sessions`, `/scores`, and leaderboards still use the existing player/session flow.

## Review Results

- `npm run test -w @lan-arcade/arcade-api`: pass, including account create/login/current-account regression.
- `npm run build`: pass for shared package, arcade API, and companion app.
- `npm test`: pass for shared, arcade API, and companion game tests.

## Deployment Status

- Code is built and ready, but `arcade-api` is not currently running as a system service on the VM.
- No live `/arcade-api/health` or `127.0.0.1:3100/health` endpoint responded during review.
- This phase therefore provides the tested account foundation only. A follow-up service phase must add or revive the API systemd/nginx deployment before the browser library can use it.

## Known Limits

- Mailu mailbox creation is not automated yet. New accounts record local email addresses and return `mailboxProvisioning: pending-mailu-automation`.
- Password reset, verification emails, invitations, and child approval flows are not implemented yet.
- Static library pages still use browser-local Recently Played; account-backed activity is a later phase.
- Emulator/DOS save isolation is not implemented yet.
- `GET /accounts` is local/debug-oriented and should be admin-protected before exposing account management to general users.

## Next Safe Phase

Deploy the account API service behind `/arcade-api/`, then add a small account/profile picker to the library that can fall back to guest mode if the API is offline.
