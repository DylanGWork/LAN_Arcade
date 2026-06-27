# Phase 17 Account Email State Review - 2026-06-27

## Scope

Added safe account email-state fields needed for future local-mail integration without sending mail, requiring verification, or changing login behaviour.

## Changes

- Added shared `MailboxStatus` type: `pending`, `ready`, `alias`, `disabled`, `error`.
- Added `mailboxStatus` and `emailVerifiedAt` to returned `ArcadeAccount` objects.
- Added SQLite account columns:
  - `mailbox_status TEXT NOT NULL DEFAULT 'pending'`
  - `email_verified_at TEXT`
- New accounts now start with `mailboxStatus: pending` and `emailVerifiedAt: null`.
- `/server-info` now advertises `account-email-state`.
- `POST /accounts` returns the new email-state fields in its `email` block.

## Deployment Safety

Before restarting the live API container, backed up the arcade database to:

`/var/lib/lan-arcade/backups/20260627-phase17-account-email-state-20260627T071721Z.sqlite`

The migration is additive only and uses `safeAlter` for existing databases.

## Checks

- `npm run build -w @lan-arcade/shared`
- `npm run build -w @lan-arcade/arcade-api`
- `git diff --check` for changed source files
- `npm run test -w @lan-arcade/arcade-api`: 6/6 tests passing
- Rebuilt/restarted `lan-arcade-api` with `docker compose -f deploy/lan-arcade-api.compose.yml up -d --build lan-arcade-api`
- Live `/arcade-api/health`: pass
- Live `/arcade-api/server-info`: includes `account-email-state`
- Live temp account smoke:
  - account created with `mailboxStatus: pending`
  - `emailVerifiedAt: null`
  - `/auth/me` returned the same fields
  - temp `codexp17*` account was removed afterwards
- Container status after smoke: `lan-arcade-api Up`

## Review

This phase prepares the account API for the real local-mail workflow while avoiding premature mailbox creation or password-reset implementation. The account system can now distinguish these states cleanly:

- arcade account exists but mailbox is not provisioned yet
- mailbox exists later (`ready`)
- mailbox is parent/admin alias (`alias`)
- mailbox disabled/error state for recovery tooling
- local email verified timestamp once verification is implemented

## Known Limits

- No Mailu mailbox or alias is created yet.
- No verification email, password reset flow, invitation flow, or child recovery UI exists yet.
- Existing accounts are migrated to `mailboxStatus: pending` and `emailVerifiedAt: null`, which is correct until the mailbox provisioning agent confirms each mailbox/alias.
