# Open Source Game Candidate Backlog

This backlog is for building LAN Arcade toward a Steam-like offline library without confusing discovery pages with proven playable games.

## Source notes

The VM was blocked by Reddit's JSON endpoint with HTTP 403, so this is not a complete automated Reddit scrape. The first pass used web-search snapshots from `r/opensourcegames` and `r/linux_gaming`, then cross-checked package availability on Debian 12 where possible. Treat every candidate as needing upstream license and asset verification before mirroring.

Reddit/search themes that repeated:

- OpenTTD, Mindustry, OpenRA, FreeCol, Battle for Wesnoth, Xonotic, Warzone 2100, Cataclysm DDA, SuperTux, Pingus, Freeciv, 0 A.D., Luanti/Minetest, Beyond All Reason, Red Eclipse, BZFlag, and Hedgewars.
- Several source ports or engines were also suggested, but many require proprietary assets. Those belong in a separate "bring your own legally-owned data" lane.

## Priority queue

| Priority | Game | Genre | Offline/LAN fit | Current VM/package status | Caveat | Next action |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | OpenTTD | Transport tycoon sim | Excellent LAN/server candidate, low resource. | Debian packages installed; server TCP and VM client launch passed. | Real client join/play still pending. | Automate client-joins-server smoke. |
| 2 | Freeciv | Turn-based 4X strategy | Strong LAN server candidate, mature rulesets. | Debian server/client installed; server TCP and VM client launch passed. | Real multi-client join pending. | Build saved small-map profile and player instructions. |
| 3 | Battle for Wesnoth | Hex tactics/campaigns | Strong hotseat/LAN candidate. | Server package installed; TCP smoke passed. | Client not installed/smoked yet. | Check client package size, install, screenshot, join lobby. |
| 4 | Stendhal | 2D MORPG | Good offline private-world target if server path is found. | Website/wiki/client ZIP/APK cached; ZIP integrity passed. | Local server not found/proven yet. | Inspect upstream server packaging and account creation path. |
| 5 | FreeCol | Colonization strategy | Good single-player strategy, likely easy Java launch. | Existing mirror/hub; Debian package available. | Not smoked yet. | Install/run Java client under Xvfb. |
| 6 | Widelands | Settlers-like RTS/economy | Good family-friendly economy RTS; multiplayer exists. | Debian package available. | Needs package size/client smoke. | Add hub after package simulation and screenshot smoke. |
| 7 | FreeOrion | Turn-based space 4X | Good deeper strategy target. | Debian package available. | May be more complex UI/server flow. | Install later; launch screenshot and tutorial notes. |
| 8 | Warzone 2100 | 3D RTS | Strong tech-tree RTS with multiplayer/skirmish. | Debian package available. | 3D client may need GPU/Xvfb care. | Package-size sim, then Xvfb launch. |
| 9 | Luanti/Minetest | Block sandbox/server | Excellent LAN server candidate. | Debian client/server packages available. | Needs world/mod profile and device clients. | Server smoke, then Android/desktop client guidance. |
| 10 | Cataclysm DDA curses | Roguelike survival | Very low-resource, great offline solo game. | Debian curses package available. | More keyboard-heavy, less family/casual. | Package and terminal smoke; add manual-heavy hub. |
| 11 | Endless Sky | Space exploration/combat | Good solo offline game. | Debian package available. | Client-only; no LAN focus. | Xvfb launch and front-page hub. |
| 12 | Hedgewars | Turn artillery | Good casual multiplayer. | Debian package available. | Theme is whimsical; check audience fit. | Package smoke and local multiplayer notes. |
| 13 | Teeworlds | 2D shooter | Lightweight LAN action. | Debian package available. | Action/PvP; needs server/client join. | Server/client smoke. |
| 14 | BZFlag | 3D tank battle | Classic LAN multiplayer. | Debian package available. | 3D client may be rough in VM. | Server smoke and compare with LAN Tank Arena. |
| 15 | SuperTuxKart | Kart racer | Great family game if hardware allows. | Debian package available. | 3D and data-heavy; may not suit Pi tier. | Garage-tier package-size and launch test. |
| 16 | OpenRA | RTS engine/mods | Excellent RTS target. | Not in Debian package query. | Engine is GPL, but bundled classic game assets have separate modding-guideline terms. | Verify offline legal asset path before mirroring. |
| 17 | Beyond All Reason | Large RTS | Very appealing advanced RTS. | Not packaged in current quick query. | Larger hardware/download/admin burden. | Research after smaller RTS pipeline works. |
| 18 | Xonotic / Red Eclipse | Arena FPS | Strong LAN shooter candidates. | Red Eclipse package available; Xonotic not found in quick Debian query. | Hardware/GPU and family suitability vary. | Add after one 3D smoke pattern is stable. |

## Bring-your-own-data lane

These may be excellent if Dylan supplies legally-owned assets, but they should not be mirrored as complete games by default:

| Engine/project | Why interesting | Caveat |
| --- | --- | --- |
| OpenRCT2 | RollerCoaster Tycoon 2 modernization and multiplayer. | Requires original RCT2/RCT Classic assets. |
| OpenMW | Morrowind engine. | Requires Morrowind data files. |
| OpenXcom | X-COM engine/reimplementation. | Requires original X-COM assets. |
| Arx Libertatis | Arx Fatalis engine. | Requires original game assets. |
| Ship of Harkinian | Zelda engine port. | Requires original game data/ROM extraction. |

## Tagging model for the future front page

- `pi-tier`: runs comfortably on Raspberry Pi/camping hardware.
- `garage-tier`: best for GannanNet or stronger local hardware.
- `server-backed`: has a host service that should be start/stop managed.
- `client-required`: players must install a native client.
- `browser-playable`: launches directly from `/mirrors/games/`.
- `bring-your-own-data`: legal engine/source port, but assets are not redistributed.
- `verified-server`: dedicated server smoke passed.
- `verified-client-launch`: native client launch screenshot passed.
- `verified-join`: client joined local server/world/lobby.
- `offline-verified`: tested with internet unavailable.
