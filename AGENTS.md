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
- Do not revert Dylan's or another agent's changes.
- Keep deployment changes backed up.
- Use the existing QA scripts where practical.
- Keep the arcade offline-friendly: no trackers, signups, remote fonts, or required internet dependencies in playable games.
- Prefer local/original games or fully mirrored assets.
- If adding agent-facing context, update `docs/AGENT_HANDOVER.md`.

## Current Known Issue

As of 2026-06-12, the static LAN Tank Arena page returns `200`, but `lan-tank-arena.service` is inactive and `http://127.0.0.1:8787/tank-arena/healthz` does not respond. Treat Tank multiplayer as needing a service check/fix before claiming it is working.
