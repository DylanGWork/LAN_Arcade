# LAN Arcade

LAN Arcade is an off-grid household game library and LAN gaming appliance. It is designed for a home server, garage VM, or camping Raspberry Pi so family and guests can find games, read guides, install clients, join local servers, and keep playing without internet.

The goal is not to clone Steam. The goal is simpler: answer "what can I play now, on this device, with these people, and how do I start it?"

**Status:** unfinished beta. Treat page-load checks as weak evidence; games need real first-action gameplay checks before they are considered ready.

## What It Includes

- Browser games and original LAN Arcade games under `local-games/`.
- Emulator shelves for Game Boy, Game Boy Color, Game Boy Advance, and Classic PC games.
- Classic PC browser play through the local js-dos runtime where game files are available.
- Native/client game hubs with offline installers or package shelves where licensing and source intake allow it.
- Hosted LAN services such as Unciv, Mindustry, TravianZ, Pillage First, and LAN Tank Arena.
- Board-game and tabletop research shelves for future playable implementations.
- Local account support for separate favourites, recent activity, future saves, and social features.
- Local/off-grid email integration for full server deployments.
- QA scripts for offline checks, gameplay smoke tests, git identity checks, and user-data backups.

## Current Library State

The main page intentionally shows launcher cards and nested shelves, not every game inside large collections. The latest deployed inventory is tracked in [docs/GAME_LIBRARY_INVENTORY_STATUS_2026-06-28.md](docs/GAME_LIBRARY_INVENTORY_STATUS_2026-06-28.md). In short: some shelves contain hundreds of nested items, but only entries with local files and gameplay smoke evidence should be described as ready to play.

Launcher adapters are the current contract for how a player starts each item. See [docs/LAUNCHER_ADAPTERS.md](docs/LAUNCHER_ADAPTERS.md) before promoting package-only, desktop-client, or hosted-service entries.

## Deployment Modes

### Full Server / GannanNet Mode

Use this for the main VM or a stronger home server. It can support local accounts, local email, native downloads, emulator shelves, hosted game servers, and larger offline website/manual copies.

Current GannanNet URLs:

```text
http://192.168.1.106/mirrors/games/
http://192.168.1.106/mirrors/games/account/
http://192.168.1.106/mirrors/games/wiki/
http://192.168.1.106/mirrors/games/downloads/
http://192.168.1.106/mirrors/private-dos-vault/
http://192.168.1.106/mirrors/private-rom-vault/
http://192.168.1.106/mirrors/lan-tank-arena/
```

The VM serves `/var/www/html/mirrors` through the existing nginx route at `/mirrors/`.

**Important on GannanNet:** do not casually run the full Apache-first installer. Use the safe regeneration command in [docs/VM_DEVELOPMENT_AND_QA.md](docs/VM_DEVELOPMENT_AND_QA.md).

### Camping / Pi-Friendly Mode

Use this for lightweight offline trips. Keep the browser games, small emulator shelves, simple account/profile handling, and static guides. Do not require the local email stack or heavy hosted services on small hardware.

## Safe VM Regeneration

On GannanNet, regenerate the catalog and pages without installing packages, configuring Apache, or touching nginx:

```sh
ARCADE_NAME="GannanNet" \
LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 \
LAN_ARCADE_SKIP_ADMIN_AUTH=1 \
LAN_ARCADE_SKIP_MIRROR=1 \
LAN_ARCADE_CATALOG_SOURCE=metadata-existing \
bash ./setup_lan_arcade.sh
```

Remove only `LAN_ARCADE_SKIP_MIRROR=1` when you intentionally want to refresh game mirrors while still leaving the web server alone.

## Generic First Install

For a fresh Debian/Ubuntu/Raspberry Pi OS host where Apache can own the web server:

```sh
sudo apt update
sudo apt install -y git
sudo mkdir -p /opt/lan-arcade
sudo chown "$USER":"$USER" /opt/lan-arcade
cd /opt/lan-arcade
git clone https://github.com/DylanGWork/LAN_Arcade.git .
chmod +x setup_lan_arcade.sh
sudo ./setup_lan_arcade.sh
```

The full installer is still Apache-first and should be treated as beta. Existing nginx/container deployments should use the safe VM regeneration path instead.

## Main Repository Areas

- `setup_lan_arcade.sh` - catalog/page generator and original installer.
- `games.meta.sh` - card metadata, source mapping, and categories.
- `local-games/` - browser games, LAN hubs, emulator shelf wrappers, and generated player-facing pages.
- `services/arcade-api/` - local accounts, activity, favourites, save metadata, and social API.
- `services/lan-tank-arena/` - browser LAN Tank Arena WebSocket service.
- `services/mindustry/`, `services/unciv/`, `deploy/*.compose.yml` - optional hosted LAN services.
- `scripts/` - intake, mirror, package, QA, repair, and deployment helpers.
- `qa/` - Playwright and focused regression checks.
- `docs/` - VM runbooks, architecture notes, audits, and phase reports.
- `game-intake/` - research and candidate intake notes.
- `agent-handoffs/` and `game-ops/` - workspaces for helper agents and game operators.

## Accounts, Saves, And Social Direction

LAN Arcade now prefers real local accounts over simple browser profiles for full server deployments. Accounts should use stable internal IDs, not email addresses, as the durable identity key.

The local email server is a first-class platform service for full deployments. It is used for local-only verification, password recovery, invitations, notifications, and application/service account mail where needed. Lightweight camping deployments can run without email and use simpler local profile/account recovery rules.

Shared ROMs and game files are fine. User data is not shared by default: favourites, recent activity, emulator saves, save states, browser game saves, achievements, settings, and hosted-game accounts should be isolated per account where practical.

## Offline Website And Manual Copies

Use `scripts/mirror_game_docs.py` for official websites, wikis, manuals, and guide pages that should work offline. After mirroring, run the external-media repair pass when pages still reference remote screenshots, fonts, or uploads.

Player pages should say `Open offline website`, `Guides & Manuals`, or `Download Clients`, not `mirror`, `package cache`, or other operator wording.

## QA Rules

A page returning 200 is not enough.

Recommended checks while developing:

```sh
npm run qa:git-identity
npm run qa:launcher-adapters
npm run qa:library-discovery
npm run test -w @lan-arcade/arcade-api
npm run backup:user-data
```

Useful broader checks:

```sh
npm run qa:static
npm run qa:smoke
npm run qa:smoke:catalog
npm run qa:smoke:mobile
npm run qa:tank
```

For browser games and launcher pages, validate from the real LAN origin when promoting a fix:

```sh
node qa/arcade-smoke.mjs --catalog --base-url https://192.168.1.106/mirrors/games/ --game <game-id> --screenshot-all --report-dir qa/reports/<name>-desktop
node qa/arcade-smoke.mjs --catalog --base-url https://192.168.1.106/mirrors/games/ --game <game-id> --mobile --screenshot-all --report-dir qa/reports/<name>-mobile
```

If a game has a first-run flow, the smoke test must click through a meaningful action: create a world, start a match, open the emulator canvas, join a local server, or reach a playable screen.

## Git Safety

Before committing from the VM, confirm identity:

```sh
npm run qa:git-identity
git config user.name
git config user.email
```

Expected project identity is documented in [AGENTS.md](AGENTS.md). Do not commit as a random GitHub-linked identity.

## Backups

User/account data should be backed up before risky platform changes:

```sh
npm run backup:user-data
```

Large private game files, ROMs, and native installers are not stored in Git. They live on the VM/NFS storage and need their own backup plan.
