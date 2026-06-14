# Offline Game Library Roadmap

LAN Arcade is growing from a camping-friendly static arcade into an offline game library for local entertainment when internet access is unavailable. The model is closer to a small LAN Steam library than a single web page: games can be browser-playable, emulator-backed, native-client LAN services, or heavier experimental servers that are started on demand.

## Operating Rules

- Do not accept a 200 response as proof that a game works. Every playable entry needs a content/render check and an interaction check.
- Keep the `/mirrors/` nginx route as the VM deployment target. Do not run the Apache-first installer casually on GannanNet.
- Prefer games that run fully offline after their assets, containers, or installers are cached.
- Do not publish commercial ROMs or unlicensed game assets into Git or public mirrors. Emulator runtimes are okay; ROM/game content needs a clear license, public-domain status, or a private user-owned import path.
- Heavy services should be available to start, not always running. Catalog entries should explain how to start/connect rather than consuming RAM by default.

## Hardware Tiers

| Tier | Target | Game shape | Examples |
| --- | --- | --- | --- |
| 0 | Raspberry Pi / camping kit | Static web games, tiny JS games, simple local assets | Current LAN Arcade browser catalog |
| 1 | Pi or small VM | EmulatorJS with licensed homebrew/public-domain ROMs | Game Boy/NES/Atari homebrew test ROMs |
| 2 | GannanNet VM / garage LAN | Native-client LAN services, cached Docker images, small JVM servers | Mindustry, Unciv turn server |
| 3 | Stronger VM/desktop server | Larger web/native servers with meaningful RAM and disk | Freeciv-web research, Veloren-style servers |
| 4 | Dedicated heavy host | MMO-scale or complex private worlds | OSRS-like experiments, long-lived RPG worlds |

## Intake Lifecycle

1. Identify source, license, expected hardware, and offline viability.
2. Cache the smallest useful artifact first: static mirror, runtime, container image, or installer.
3. Add a catalog entry with hardware tier, status, start/connect instructions, and source/license notes.
4. Run static mirror audit and desktop/mobile smoke where applicable.
5. For games with actual rules or agents, dogfood them for long enough to prove the loop works.
6. Record service health checks, ports, memory footprint, and known failure modes.
7. Promote status only after offline/external-request checks pass.

## Regression Gates

- Static mirror audit: no missing local assets and no entrypoint external dependency refs.
- Browser smoke: desktop and mobile screenshots, visible render evidence, basic interaction, no runtime page errors.
- Offline behavior: block external requests or inspect request logs for anything outside the LAN host.
- Dogfood: play the actual game loop, not just the menu. For simulations, capture population/resources/progress over time.
- Service games: verify the service starts on demand, reports health, accepts a client connection, and can be stopped cleanly.
- Mobile UX: menus must be dismissible, non-overlapping, and playable on a phone viewport when the game is marked mobile-friendly.
- Performance: record rough RAM/CPU footprint for long-running services and high-speed browser simulations.

## Current Library Expansion

- EvoLab: patched toward species-level play with shared breeding reserves, ready-breeder HUD, capped event stat effects, relative Vite assets, and high-speed simulation caps.
- Mindustry LAN: catalog page added and service smoke passed after fixing the default map to `Ancient_Caldera` and hosting immediately with `host Ancient_Caldera survival`.
- Unciv LAN: catalog page added and service smoke passed on port 8090 for `/isalive`, auth registration/check, upload, download, and wrong-password overwrite rejection. Note that `PUT /auth` requires the new password in the request body.
- Retro Emulator Lab: catalog page added and launcher smoke passed. EmulatorJS 4.2.3 runtime is cached outside Git at `/mirrors/emulatorjs-runtime/4.2.3/`. First legal ROM entries are `tobu-tobu-girl-deluxe` and `skyland-gba`.

## EmulatorJS Path

EmulatorJS is useful as a runtime, not as permission to redistribute commercial games. The first safe playable targets are now in place: Tobu Tobu Girl Deluxe and Skyland GBA. Continue adding only homebrew/public-domain/explicitly licensed ROMs, and add a private import area later for Dylan-owned ROMs that is excluded from Git and not mirrored as public project content.

Runtime cache:

```text
/var/www/html/mirrors/emulatorjs-runtime/4.2.3/
```

After refreshing the runtime, run:

```sh
scripts/patch_emulatorjs_runtime.sh /var/www/html/mirrors/emulatorjs-runtime/4.2.3/data
```

That patch disables EmulatorJS' localhost CDN update check for offline QA and adds an `en-GB` localization alias when only `en-US` is bundled.

Playable emulator entries should set the EmulatorJS data path to the local runtime, for example:

```html
<script>
  window.EJS_player = '#game';
  window.EJS_core = 'gb';
  window.EJS_pathtodata = '../emulatorjs-runtime/4.2.3/data/';
  window.EJS_gameUrl = './roms/example-homebrew.gb';
</script>
<script src="../emulatorjs-runtime/4.2.3/data/loader.js"></script>
```

## Steam-Like Front Page Direction

The front page should eventually become a library UI rather than a flat wall of cards. Suggested metadata fields:

- `hardware_tier`: pi, vm, garage, heavy
- `play_mode`: browser, emulator, native-client, server-client, docs-only
- `offline_status`: ready, cached, needs-test, research, blocked
- `service_name`: optional systemd/compose unit
- `start_command`: optional on-demand service command
- `connect_url_or_address`: browser URL, LAN host:port, or native-client server URL
- `qa_badge`: latest static/smoke/dogfood result
- `license_status`: mirrored-ok, runtime-only, private-content, permission-needed

Front page sections should prioritize:

- Ready Now
- Camping/Pi Friendly
- LAN Multiplayer
- Emulation Lab
- Native Client Required
- Research/Needs QA

## Candidate Progression

1. Finish EvoLab stability and UX patches, then keep it as a dogfood benchmark for simulation games.
2. Add more legal EmulatorJS homebrew ROMs now that Tobu Tobu Girl Deluxe and Skyland GBA have proven the intake path.
3. Promote Mindustry further by testing with a real native client on the LAN; on-demand server smoke now passes.
4. Promote Unciv further by completing a phone/desktop client loop; raw HTTP auth/file loop now passes.
5. Revisit Freeciv-web as a heavier research item only after memory and external-request issues are bounded.
6. Investigate Veloren, open-source RPG/MMO servers, and OSRS-like projects one at a time with strict license and resource notes.
