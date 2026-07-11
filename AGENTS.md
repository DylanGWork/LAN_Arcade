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
- Public player-facing pages must not contain external `http(s)` links, images, scripts, forms, fonts, embeds, or visible source URLs. Keep upstream/source URLs in non-public operator manifests, attribution files, or operator docs; expose only local saved websites/guides/downloads to players. Run `npm run qa:offline-links` after deployment changes that touch public HTML.
- Prefer local/original games or fully mirrored assets.
- If adding agent-facing context, update `docs/AGENT_HANDOVER.md`.


## Recent Regression Lessons

- Do not certify a game or launcher from HTTP 200, a visible card, or a loaded page alone. Test the first meaningful user action on the real LAN origin and mobile/narrow layout where practical.
- Do not certify a mirrored manual from HTTP 200 or link scanning alone. Open its player-facing landing page, follow at least one useful guide link, confirm local CSS actually renders, and block external requests during the browser test.
- Never replace arbitrary raw URLs inside CSS or JavaScript. Audit and rewrite only runtime-bearing references such as HTML href/src/action/srcset and CSS url(); license comments, SVG namespaces, and code examples must remain intact.
- Keep user-facing library wording separate from intake/admin wording. Avoid labels such as `source-ready`, `package missing`, `candidate`, or `top-level cards` on pages intended for guests; use plain labels such as `Ready to play`, `Needs local files`, `Open shelf`, `Play`, or `Install / play`.
- Large shelves such as Game Boy, Classic PC/DOS, and board-game research must remain nested to avoid flooding the home page, but search must reach into those shelves and offer direct playable results for known titles.
- Browser DOS emulation is resource-heavy. Prefer js-dos worker/canvas mode, clean up emulator instances on page unload, and treat local DOSBox downloads as the low-power fallback.
- Keep inventory states explicit. `Listed`, `nested`, `packaged`, `playable`, and `QA-smoked` are different states; do not tell Dylan or players that a whole wave is imported when only a shelf or research manifest exists.
- Public launcher labels must come from the launcher-adapter audit where available. Package-only native shelves and desktop-client download hubs are not `Ready now` until they have a browser launcher, simple desktop launcher bundle, or server-streamed play path.

## Current Known Issue

As of 2026-06-12, the static LAN Tank Arena page returns `200`, but `lan-tank-arena.service` is inactive and `http://127.0.0.1:8787/tank-arena/healthz` does not respond. Treat Tank multiplayer as needing a service check/fix before claiming it is working.
## Agent Ownership

The main LAN Arcade agent is the release orchestrator. It owns:

- canonical registry and readiness schemas;
- launcher contracts and public wording;
- deployment profiles, generation, and live deployment;
- account/save architecture and the final release gate.

Helper agents may gather artwork, research game intake, or produce gameplay QA
evidence in their assigned workspace. They must not silently edit platform
schemas, deploy services, promote readiness, or mix game-development work into
the platform. Complex games use their own repository and hand back a versioned
release or launcher adapter.

## Current Authority

- The live GannanNet deployment profile is `full`; use `pi` only for a lightweight export/test and restore `full` afterward.
- Canonical inventory is generated from `canonical-registry.json`; 153 cards are not the total game count.
- Public readiness comes only from `readiness.json` and its current evidence receipts.
- `lan-tank-arena.service` is active/enabled and the same-origin WebSocket proxy is live. Re-run `npm run qa:tank:live` before claiming multiplayer remains healthy.
- Pillage First development belongs in `/home/dylan/Pillage-First-LAN`; this repository owns only its Arcade integration.
- Public `wiki/` is Guides & Manuals. Operator commands and internals belong in repository docs or the protected admin area.
