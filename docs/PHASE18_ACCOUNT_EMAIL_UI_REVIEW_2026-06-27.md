# Phase 18 Account Email UI Review - 2026-06-27

## Scope

Surfaced the account email state added in Phase 17 in the player-facing library UI.

## Changes

- Main Game Library account panel now shows:
  - local arcade email address
  - mailbox setup state
  - email verification state
- `/mirrors/games/account/` now shows explicit account fields:
  - `Mailbox`
  - `Email verification`
- Labels are user-facing:
  - `Mailbox setup pending`
  - `Email not verified yet`
  - `Mailbox ready` / `Ready` when future provisioning marks it ready

## Checks

- `bash -n setup_lan_arcade.sh`
- `git diff --check -- setup_lan_arcade.sh`
- Safe VM regeneration with package/admin/mirror steps skipped
- `npm run qa:static`: 152 games scanned, 152 OK, 0 needing attention
- Playwright signed-in smoke using temporary `codexp18*` account:
  - library `#accountPanel` showed `Mailbox setup pending`
  - library `#accountPanel` showed `Email not verified yet`
  - account page showed `Mailbox` / `Setup pending`
  - account page showed `Email verification` / `Not verified yet`
  - no page errors
  - temporary account removed after smoke

## Review

This is a display-only phase. It does not send email, verify addresses, provision Mailu mailboxes, or implement password resets. It makes the future local-mail workflow visible without changing guest mode or current account login behaviour.

## Remaining Work

- Mailbox/alias provisioning automation.
- Local email verification flow.
- Local password reset flow.
- Child/family recovery rules and admin recovery tools.
