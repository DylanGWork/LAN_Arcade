# Game Guidance Audit - 2026-07-11

## Result

LAN Arcade does not yet have full manual coverage. The audit deliberately separates a short local hint from a game-specific manual or wiki.

| Library scope | Records checked | Some basic help | Reachable local game-specific guide | Missing local game-specific guide |
| --- | ---: | ---: | ---: | ---: |
| Top-level catalogue cards | 153 | 145 | 20 | 133 |
| Classic PC shelf | 28 | 28 | 2 | 26 |
| Game Boy vault | 743 | 743 | 0 | 743 |

The 924 records above are source records, not unique games. Collection cards overlap their nested titles, and the 200 board-game research rows are excluded because they are not playable adapters.

## Findings

- Only 20 of 153 top-level cards currently expose a reachable local full guide.
- 8 top-level collection/original-game cards have no detected basic help at all.
- Classic PC has controls for all 28 entries, but only 2 title-specific manuals.
- All 743 Game Boy entries share emulator controls; none currently has per-title manual metadata.
- A previous audit falsely treated SuperTux as covered by the SuperTuxKart documentation because it matched similar slugs. Guide associations now use explicit game IDs.
- The old documentation validator accepted blocker placeholder pages as successful mirrors. It now reports blocker markers as unusable and exits non-zero.

## Official Sources Located

20 high-value official guide sources are registered. 12 are now cached and linked locally; 8 are verified upstream sources still waiting for a bounded offline cache.

| Game | Guide type | Offline state | Official source |
| --- | --- | --- | --- |
| Mindustry | wiki | Cached and linked | https://mindustrygame.github.io/wiki/ |
| SuperTux | manual | Cached and linked | https://github.com/SuperTux/supertux/wiki/User-Manual |
| SuperTuxKart | website-and-faq | Cached and linked | https://supertuxkart.net/Main_Page |
| Xonotic | new-player-guide | Cached and linked | https://xonotic.org/guide/ |
| DDNet | wiki | Cached and linked | https://wiki.ddnet.org/wiki/Special%3AMyLanguage/Main_Page |
| Endless Sky | player-manual | Cached and linked | https://github.com/endless-sky/endless-sky/wiki/PlayersManual |
| Widelands | game-manual | Found; not cached yet | https://www.widelands.org/wiki/Game%20Manual/ |
| FreeOrion | quick-play-guide | Found; not cached yet | https://www.freeorion.org/index.php/V0.3_Quick_Play_Guide |
| Cataclysm: Dark Days Ahead | in-game-help-reference | Found; not cached yet | https://docs.cataclysmdda.org/JSON/HELP_MENU.html |
| Luanti | player-guide | Cached and linked | https://docs.luanti.org/for-players/ |
| Veloren | owners-manual | Found; not cached yet | https://book.veloren.net/ |
| Stendhal | manual | Found; not cached yet | https://stendhalgame.org/wiki/Stendhal/manual |
| TripleA | user-guide-and-rulebook | Cached and linked | https://triplea-game.org/user-guide/ |
| Dungeon Crawl Stone Soup | manual-and-quick-start | Found; not cached yet | https://crawl.develz.org/wordpress/documentation |
| NetHack | guidebook | Found; not cached yet | https://nethack.org/common/info.html |
| Simutrans | wiki | Found; not cached yet | https://simutrans-germany.com/wiki/wiki/en_Index |
| OpenTTD | manual | Cached and linked | https://wiki.openttd.org/en/Manual/ |
| Battle for Wesnoth | wiki | Cached and linked | https://wiki.wesnoth.org/ |
| 0 A.D. | manual | Cached and linked | https://trac.wildfiregames.com/wiki/0adManual |
| Freeciv | website-and-help | Cached and linked | https://www.freeciv.org/ |

## This Pass

- Added explicit guide-source and mirror-to-game associations.
- Exposed local manuals from the Mindustry, SuperTux, SuperTuxKart, Xonotic, DDNet, Endless Sky, Luanti, and TripleA hubs.
- Cached bounded offline copies for SuperTux, DDNet, Endless Sky, Luanti, TripleA, Xonotic, and SuperTuxKart.
- Repaired remote media where available. Two dead upstream image URLs were replaced with local transparent placeholders so they cannot leak network requests.
- Added non-recursive mirroring for selected pages. This avoids recursively crawling large GitHub sites.

## Next Queue

1. Cache the eight verified-but-not-local sources: Widelands, FreeOrion (after version review), Cataclysm DDA, Veloren, Stendhal, Dungeon Crawl Stone Soup, NetHack, and Simutrans.
2. Prioritize complex strategy, RPG, simulation, and hosted multiplayer entries before simple arcade games.
3. Acquire Classic PC manuals only from approved/licensed sources or user-provided files, recording checksums and source notes.
4. Treat Game Boy title manuals as a separate rights-aware metadata project. Platform controls are not a substitute for individual game instructions.
5. Keep simple original/browser games on short in-app guides where a full external wiki would add little value.

## Reproduce

    python3 scripts/audit_game_guidance.py --output-dir qa/reports/guidance-audit
