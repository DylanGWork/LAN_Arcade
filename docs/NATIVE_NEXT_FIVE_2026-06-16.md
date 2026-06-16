# Native Next Five Intake - 2026-06-16

Added the first diverse native-game batch after Unciv/Mindustry/OpenTTD-style offline-download rules:

| Game | URL | Download cache | Docs/manual cache | VM evidence | Still pending |
| --- | --- | --- | --- | --- | --- |
| Teeworlds / DDNet | `/mirrors/teeworlds-ddnet-lan/` | `/mirrors/games/downloads/native/teeworlds-ddnet/` (373 MB) | `/mirrors/teeworlds-ddnet-docs/` (636 KB) | DDNet server UDP 8303 smoke passed; DDNet client launch passed. | Two-client LAN join/play. |
| Hedgewars | `/mirrors/hedgewars-lan/` | `/mirrors/games/downloads/native/hedgewars/` (517 MB) | `/mirrors/hedgewars-docs/` (1.9 MB) | Hedgewars native client launch passed. | Hotseat or LAN match smoke. |
| Widelands | `/mirrors/widelands-lan/` | `/mirrors/games/downloads/native/widelands/` (2.8 GB) | No full docs mirror yet; upstream website/wiki was anti-bot blocked during intake. | Widelands native client launch passed after XDG temp-home fix. | Two-client economy start, cleaner docs source. |
| Warzone 2100 | `/mirrors/warzone2100-lan/` | `/mirrors/games/downloads/native/warzone2100/` (3.4 GB) | `/mirrors/warzone2100-site/` (6.4 MB) | Warzone native client launch passed. | Saved skirmish/autohost or LAN join smoke. |
| Luanti | `/mirrors/luanti-lan/` | `/mirrors/games/downloads/native/luanti/` (138 MB) | `/mirrors/luanti-docs/` (144 KB) | Minetest/Luanti server UDP 30000 smoke passed; client launch passed. | Real laptop/phone join into local world. |

QA run:

- `npm run qa:static`: 88/88 OK, 0 entrypoint external dependency refs.
- Desktop/mobile hub smoke: all five strict passed and playable under `qa/reports/native-next-five/*-20260616T000637Z-*`.
- Service smoke reports:
  - `qa/reports/service-smoke/teeworlds-ddnet-lan-20260615T235745Z/report.txt`
  - `qa/reports/service-smoke/luanti-lan-20260615T235751Z/report.txt`
  - `qa/reports/service-smoke/hedgewars-lan-20260615T235758Z/report.txt`
  - `qa/reports/service-smoke/widelands-lan-20260615T235758Z/report.txt`
  - `qa/reports/service-smoke/warzone2100-lan-20260615T235758Z/report.txt`
- Client launch reports:
  - `qa/reports/native-client-launch/teeworlds-ddnet-lan-20260615T235831Z/report.txt`
  - `qa/reports/native-client-launch/hedgewars-lan-20260615T235847Z/report.txt`
  - `qa/reports/native-client-launch/widelands-lan-20260616T000117Z/report.txt`
  - `qa/reports/native-client-launch/warzone2100-lan-20260615T235910Z/report.txt`
  - `qa/reports/native-client-launch/luanti-lan-20260615T235922Z/report.txt`

Implementation notes:

- Added `scripts/generate_native_game_hubs.py` to generate consistent player-facing native hub pages.
- Extended `scripts/cache_native_game_offline_assets.py` for `teeworlds-ddnet`, `hedgewars`, `widelands`, `warzone2100`, and `luanti`.
- Extended `scripts/native_service_smoke.sh` and `scripts/native_client_launch_smoke.sh` for this batch.
- Debian package install pulled about 1.2 GB of local smoke dependencies. The package post-install enabled `minetest-server`; it was immediately stopped and disabled. Keep native services one-at-a-time.
