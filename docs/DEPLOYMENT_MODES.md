# LAN Arcade Deployment Modes

Last updated: 2026-06-28

LAN Arcade should feel like one game appliance, but not every install needs the same services. Keep the public library shape consistent across modes; vary what launchers and account features are enabled.

## GannanNet Full Server Mode

Use for the garage/home server VM.

Included services:

- nginx/webserver serving `/mirrors/`.
- Arcade API container at `/arcade-api/`.
- Local account database with favourites, recent activity, save vault, friends, and local messages.
- Local Mailu mail server for account verification, password reset, invitations, notifications, and game/service mail workflows.
- Native game package shelves and optional NFS-backed installer storage.
- Hosted LAN services that can be started one at a time.

Expected user experience:

- Player opens the Game Library, signs in or chooses Guest.
- Cards say `Play`, `Open shelf`, `Install / play`, or `Start / join`.
- Technical import status is hidden from player pages and moved to operator/admin docs.
- Saves and progress are account-owned wherever practical.

## Camping / Pi-Friendly Mode

Use for a Raspberry Pi or weekend offline kit.

Included services:

- Static library and browser games.
- Small emulator shelves that are proven on weak hardware.
- Optional lightweight account/profile picker without local email.
- No heavy native-server stack by default.

Email handling:

- Do not require Mailu on Pi mode.
- Account recovery can be admin/manual only.
- Password reset links and mail notifications are disabled unless a mail server is configured.

## Shared Rules

- ROMs, installers, docs, and static game files are shared read-only library assets.
- Saves, save states, settings, achievements, favourites, and recent activity belong to a user/account.
- Public pages should explain what the player can do, not how the intake pipeline classified the game.
- Every game promotion needs a full-flow QA note: load, first meaningful action, offline check, and screenshot/log path.
- Large collections stay nested, but search should reach into them and link directly to playable items.

## Installer Prompt Target

Future setup should ask:

1. Is this `Full server` or `Camping/Pi` mode?
2. Should LAN Arcade use an existing local mail server, install one later, or run without email?
3. Where should large native installers live: local disk or NFS path?
4. Which shelves should be enabled on first boot?

Do not force the full Mailu stack or native services onto lightweight installs.
