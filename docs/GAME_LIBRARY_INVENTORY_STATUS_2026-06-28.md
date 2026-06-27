# Game Library Inventory Status - 2026-06-28

This note records the current deployed library state on GannanNet. It exists because earlier phase notes blurred together several different states: listed, imported, nested, playable, and fully QA-smoked.

## Confirmed Counts

Source checked on 2026-06-28 from `/home/dylan/LAN_Arcade` and deployed manifests under `/var/www/html/mirrors`.

| Area | Current state | What it means |
| --- | ---: | --- |
| Top-level library cards | about 152 | Cards and shelves visible on the main library page. This is not the full nested game count. |
| Source game/shelf directories | 153 | Direct folders under `local-games/`; includes launchers, shelves, hubs, and games. |
| Native download shelves | 129 deployed, 124 normalized | Offline installer/package shelves exist for many native games. Most are download/install support pages, not browser-playable games. |
| Classic PC / DOS shelf | 28 listed | Entries visible in the Classic PC shelf. |
| Classic PC browser packages | 15 packaged | These have local ZIP/js-dos bundles and can be tried in the browser. |
| Classic PC needing files/recipes | 13 | Listed entries still need local files, launch recipes, or stronger smoke tests before they should be called playable. |
| Curated Game Boy/Game Boy Color wave | 201 | Curated nested ROM links in `private-rom-wave-1`; not top-level cards. |
| Private Game Boy vault | 743 | Large private vault exposed through its own nested shelf, not individual home-page cards. |
| Board-game wave | 200 rows | Mostly research entries. Only a small subset are local/playable today. |

## Classic PC Breakdown

The Classic PC shelf is the clearest example of the confusion:

- 28 entries are listed in `/var/www/html/mirrors/private-dos-vault/manifest.json`.
- 15 entries have local package/browser bundles.
- Gameplay confidence is lower than package count:
  - `smoke-pass`: 1
  - `partial`: 3
  - `source-ready`: 11 with packages but weak/unfinished gameplay proof
  - `candidate`: 12 with no package yet
  - `blocked`: 1

Player-facing wording should therefore say things like `15 ready to try in browser` and `13 still need files or setup`, not imply all 28 are playable.

## Board-Game Wave Breakdown

`/var/www/html/mirrors/board-games-wave-1/manifest.json` currently reports:

- `metadata-only`: 192
- `playable-local`: 6
- `partial-local`: 1
- `analog-local`: 1

These should be treated as a research shelf until more entries become playable local implementations or clear offline tabletop packages.

## Why The Main Page Does Not Show Hundreds Of Cards

Large collections are intentionally nested so the home screen does not become unusable:

- Game Boy vault: one shelf/card opens hundreds of nested titles.
- Curated Game Boy wave: one shelf/card opens curated nested links.
- Classic PC games: one shelf/card opens the DOS/Classic PC shelf.
- Board-game wave: one shelf/card opens research rows.

Search should reach into these shelves and show direct nested results for known titles. If a title such as SimAnt does not appear from search, that is a search/index bug, not proof that the package is missing.

## Current User-Facing Problems

- Some pages still expose operator wording like `source-ready`, `candidate`, `package`, `manifest`, or `cache` where players need plain actions.
- Some entries are visible before they are genuinely playable.
- Native download pages were previously raw package lists; they are now normalized into player-facing pages, but still need per-game copy review.
- Classic PC/DOS games need stronger first-action QA and clear controls/manuals.
- Board-game rows need promotion rules before they appear as playable games.

## Promotion Rules Going Forward

Do not claim a game is playable from a page load or manifest entry alone.

A game can be promoted as `Ready to play` only when:

1. The launch path is reachable from `/mirrors/games/`.
2. Required files are present locally.
3. It works with network blocked or disconnected, except intentionally local-LAN services.
4. A tester reaches a meaningful first action: start game, create world, place/build/move, start match, or join hosted session.
5. Screenshots/logs are stored under `qa/reports/` or the shelf's QA notes.
6. Player-facing text says what to click and what device/input is needed.

## Next Cleanup Priorities

1. Finish or hide the 13 Classic PC entries that still need files/recipes/testing.
2. Add direct nested search results for all packaged Classic PC titles and curated ROMs.
3. Keep research-only board rows out of `Ready now` and clear in their shelf wording.
4. Continue converting public pages from operator language to player language.
5. Add a single inventory script that prints these counts from deployed manifests before every bulk-import summary.
