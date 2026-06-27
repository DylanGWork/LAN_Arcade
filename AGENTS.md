# LAN Arcade Agent Rules

This repo is Dylan's LAN Arcade project on the GannanNet VM.

## Current Location

- VM: `GannanNet`
- SSH: `dylan@192.168.1.106`
- Repo: `/home/dylan/LAN_Arcade`
- Deployed arcade: `http://192.168.1.106/mirrors/games/`
- Offline wiki: `http://192.168.1.106/mirrors/games/wiki/`
- Downloads: `http://192.168.1.106/mirrors/games/downloads/`
- Tank Arena page: `http://192.168.1.106/mirrors/lan-tank-arena/`

Read `docs/AGENT_HANDOVER.md` and `docs/VM_DEVELOPMENT_AND_QA.md` before changing deployment or running setup scripts.

## VM-Specific Warning

The README's full installer is Apache-first. On GannanNet, nginx already owns port 80 and serves `/var/www/html/mirrors` through the existing `webserver` container.

Do not run `sudo ./setup_lan_arcade.sh` casually on GannanNet. Prefer the safe regeneration command in `docs/VM_DEVELOPMENT_AND_QA.md`.

## Boundaries

Stay inside `/home/dylan/LAN_Arcade` unless Dylan explicitly asks otherwise.

Do not touch:

- `/opt/asx-platform`
- `/home/dylan/wordpress` unless explicitly working on homepage/proxy integration
- `/home/dylan/mealie`
- `/srv/reticulum-services/actual-budget`
- `/home/dylan/financial-planner`
- `/home/dylan/task-hub`
- `/home/dylan/inventory-hub`
- `/home/dylan/garden-hub`
- `/home/dylan/house-map`
- `/srv/maps`
- `/srv/kiwix`
- `/mnt/tank/*`
- unrelated Docker containers or global Docker settings

Do not stop Docker globally.

## Development Rules

- Check `git status` before edits.
- When Dylan says VM-only, do edits, tests, and generated artifacts on GannanNet over SSH. Do not create local temp scripts or run local browser-control helpers unless he explicitly asks.
- Before every commit, run `npm run qa:git-identity` or manually verify `git config user.name` and `git config user.email`.
- Approved LAN Arcade commit identity on GannanNet is currently `DylanGWork LAN Arcade Agent <dylan.gannan@pestsense.com>`. Do not use VM host-derived emails such as `dylan@GannanNet.GannanNet`.
- If GitHub shows a surprising contributor, first check commit author emails and repo collaborator permissions. GitHub contributor attribution can come from commit metadata even when the account has no write access.
- Do not revert Dylan's or another agent's changes.
- Keep deployment changes backed up.
- Use the existing QA scripts where practical.
- Keep the arcade offline-friendly: no trackers, signups, remote fonts, or required internet dependencies in playable games.
- Prefer local/original games or fully mirrored assets.
- If adding agent-facing context, update `docs/AGENT_HANDOVER.md`.


## Recent Regression Lessons

- Do not certify a game or launcher from HTTP 200, a visible card, or a loaded page alone. Test the first meaningful user action on the real LAN origin and mobile/narrow layout where practical.
- Keep user-facing library wording separate from intake/admin wording. Avoid labels such as `source-ready`, `package missing`, `candidate`, or `top-level cards` on pages intended for guests; use plain labels such as `Ready to play`, `Needs local files`, `Open shelf`, `Play`, or `Install / play`.
- Large shelves such as Game Boy, Classic PC/DOS, and board-game research must remain nested to avoid flooding the home page, but search must reach into those shelves and offer direct playable results for known titles.
- Browser DOS emulation is resource-heavy. Prefer js-dos worker/canvas mode, clean up emulator instances on page unload, and treat local DOSBox downloads as the low-power fallback.
- Keep inventory states explicit. `Listed`, `nested`, `packaged`, `playable`, and `QA-smoked` are different states; do not tell Dylan or players that a whole wave is imported when only a shelf or research manifest exists.

## Current Known Issue

As of 2026-06-12, the static LAN Tank Arena page returns `200`, but `lan-tank-arena.service` is inactive and `http://127.0.0.1:8787/tank-arena/healthz` does not respond. Treat Tank multiplayer as needing a service check/fix before claiming it is working.
