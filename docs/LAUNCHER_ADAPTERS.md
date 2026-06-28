# LAN Arcade Launcher Adapters

LAN Arcade separates **files exist** from **a player can start the game**.

The generated adapter registry is `config/launcher-adapters.json` and the deployed copy is `/var/www/html/mirrors/games/launcher-adapters.json`. Human decisions live in `config/launcher-adapter-overrides.json`; do not hand-edit the generated registry except as an emergency deployed-output repair.

## Player-Facing Adapter Types

- `browser`: open the local browser game directly.
- `browser-emulator`: open a browser emulator such as Game Boy, Game Boy Color, GBA, or Classic PC/js-dos.
- `collection`: open a nested shelf such as Classic PC Games or the Game Boy vault.
- `hosted-lan`: open a local game hub that starts or joins a LAN/server session.
- `browser-stream`: future/pilot mode where the VM runs a lightweight native game and streams it to the browser.
- `desktop-client`: client installers exist, but the entry is not one-click playable yet.
- `linux-package`: Debian/Linux package files exist, but the entry is not one-click playable yet.
- `research-shelf` / `setup-needed`: visible for operators and planning, not a ready-to-play promise.

## Rules

1. `Ready now` means a normal player can start the game from the LAN Arcade UI.
2. Raw `.deb` dependency lists, checksums, and package manifests belong under advanced/setup pages, not the primary player flow.
3. `linux-package`, `desktop-client`, and `setup-needed` entries must not be marked `readyNow: true` until they gain a real playable adapter.
4. Hosted service control must be allowlisted. Browser/API input must never become arbitrary shell.
5. Every promoted adapter needs full-flow QA: open, start, interact, confirm offline behaviour, and record result.

## Safe Commands

Regenerate the launcher audit:

```bash
npm run qa:launcher-adapters
```

Deploy the generated registry through the normal safe VM regeneration path:

```bash
ARCADE_NAME="GannanNet" \
LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 \
LAN_ARCADE_SKIP_ADMIN_AUTH=1 \
LAN_ARCADE_SKIP_MIRROR=1 \
LAN_ARCADE_CATALOG_SOURCE=metadata-existing \
bash ./setup_lan_arcade.sh
```

Hosted service status and smoke tests stay behind the allowlisted VM helper:

```bash
python3 scripts/native_service_admin.py list
python3 scripts/native_service_admin.py status mindustry-lan --json
python3 scripts/native_service_admin.py start mindustry-lan --keep-running
python3 scripts/native_service_admin.py stop mindustry-lan
```
