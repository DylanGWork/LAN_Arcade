# Board Games Wave 1 Import Plan - Family And Social Play

Date: 2026-06-21  
Scope: planning only. No downloads, purchases, authentication, Steam/BGA/Tabletopia login, Workshop sync, VASSAL module fetching, ROM/game import, or access-control bypassing was performed.

## Goal

Build a broad, high-quality digital board game shelf of about 200 games for family, guests, and repeat social play. This is not a "top 200 hobby games" list. It is a playable-household list: easy entry points, enough children's/family/party titles, classics, and a smaller set of deeper games for people who come back often.

## Existing LAN Arcade Board-Game Sources Reviewed

- `docs/BOARD_GAME_INTAKE_2026-06-19.md`: 15 native board-game hubs already trialed.
- `scripts/native_board_game_data.py`: source/package metadata for Pioneers, TEG, KsirK, Atlantik/monopd, TripleA, Biloba, Ricochet Robots, Bovo, KFourInLine, KReversi, Kigo/GNU Go, Pentobi, GNU Backgammon, KNavalBattle, and XFrisk.
- `docs/PUBLIC_PACKAGE_INTAKE_2026-06-20.md` and `scripts/public_package_expansion_20260620.csv`: package-backed family/puzzle/board-adjacent entries, including Nine Men's Morris and several family puzzle games.
- `game-intake/source-notes.md`: current intake rules: public package/data lanes are preferred; unclear commercial material stays legal-review/private-only.

Current proven/source-clear base:

- PASS: Pioneers, TEG, KsirK, Biloba, Ricochet Robots, Bovo, KFourInLine, KReversi, Kigo/GNU Go, Pentobi, GNU Backgammon.
- PARTIAL: Atlantik/monopd, KNavalBattle, XFrisk.
- BLOCKED: TripleA until offline map/update checks are patched.
- Extra source-clear candidate from public package expansion: Nine Men's Morris.

## External Source Lanes For This Plan

| Source lane | Offline value | Access/licensing concern | Recommendation |
|---|---|---|---|
| Debian/open-source native packages | High | Usually redistributable through package metadata, but each package still needs manifest/license notes | Import first. This is the cleanest LAN Arcade lane. |
| Public-domain classic implementations | High | Generic games are safe only with original/source-clear art, names, and code | Build/source-clear these before touching commercial scans. |
| Official commercial digital apps | Medium-high | Purchase/DRM/account/installer ownership; do not commit installers or private assets | Private-only lane if Dylan provides owned files or approved accounts later. |
| VASSAL modules | Medium | VASSAL is open-source and has a large module library, but module asset permissions vary | Use only modules with explicit permission or private-owned-game status. |
| Board Game Arena | Low for offline import | Online/account service; good discovery/playtesting reference, not an offline LAN source | Use for choosing games, not importing payloads. |
| Tabletopia | Low for offline import | Online sandbox/account service; no rules AI; official library but not LAN-offline | Discovery/reference only unless a publisher provides offline assets. |
| Tabletop Simulator / Tabletop Playground | Medium | Steam purchase/account; Workshop mods are not automatically redistribution-safe | Use official DLC or source-clear/private mods only. |
| Tabletop Club / open tabletop sandboxes | Medium | Source-clear assets required per game | Good future lane for public-domain/classic games and original family games. |

## Counting And Edition Rules

- One preferred English-playable version per game.
- Prefer official/source-clear implementations over scanned or unofficial assets.
- Prefer family, guest-friendly, or repeat-play editions over deluxe/completionist editions.
- Do not import duplicate editions, reskins, junior editions, regional language editions, fan rethemes, print-and-play variants, or unofficial Workshop copies unless they fill a specific approved gap.
- Count expansions as metadata on the base game unless the expansion is essential to the digital implementation.
- Use source-clear analogs where needed: Pioneers for Catan-like play, TEG/KsirK/XFrisk for Risk-like play, Atlantik for Monopoly-like play, KFourInLine for Connect Four-like play, Pentobi for Blokus-like play.

## Category Breakdown

| Category | Count | Main age range | Role |
|---|---:|---|---|
| Children's games | 16 | 4-8 | Young kids, first board games, parent-child play |
| Family games | 18 | 7+ | Main family-night shelf |
| Party games | 17 | 8+ | Guests, larger groups, fast teaching |
| Cooperative games | 17 | 7+ | Shared-table play, lower-conflict groups |
| Classic board games | 18 | 5+ | Evergreen rules, source-clear implementation targets |
| Gateway strategy games | 18 | 8-12+ | Repeat play without heavy rules load |
| Medium-weight strategy games | 17 | 12+ | Experienced players and long-term play |
| Trading/economic games | 16 | 10+ | Negotiation, auctions, markets |
| Tile/engine-building games | 17 | 8-12+ | Spatial puzzles and replayable systems |
| Deduction/social deduction games | 15 | 8-14+ | Talking, clues, hidden information |
| Card-driven board games | 16 | 7-12+ | Portable-feeling digital card/table games |
| Educational/history/science games | 15 | 8-14+ | Learning themes that still play well |
| Total | 200 | Mixed | Broad Wave 1 target |

## Board Games Wave 1 Candidate Library

### Children's Games - 16

Preferred source: official digital app if owned, source-clear tabletop implementation, or supervised web-only reference. Keep these bright, short, and parent-friendly.

1. Outfoxed!
2. Rhino Hero
3. Hoot Owl Hoot!
4. Dragon's Breath
5. My First Carcassonne
6. Ticket to Ride: First Journey
7. Catan Junior
8. Dragomino
9. Animal Upon Animal
10. Go Away Monster!
11. The Sneaky Snacky Squirrel Game
12. Race to the Treasure!
13. Sleeping Queens
14. Labyrinth Junior
15. Guess Who?
16. Spot It! Kids

### Family Games - 18

Preferred source: official apps/private-owned installers where available; otherwise metadata-only until rights are clear.

1. Ticket to Ride
2. Carcassonne
3. Azul
4. Kingdomino
5. Cascadia
6. Harmonies
7. Splendor
8. King of Tokyo
9. Qwirkle
10. Labyrinth
11. The Quest for El Dorado
12. Jamaica
13. Camel Up
14. Downforce
15. Tsuro
16. Hey, That's My Fish!
17. Santorini
18. Patchwork

### Party Games - 17

Preferred source: official digital version, source-clear party web app, or private/manual table implementation. Online-only services are discovery references, not LAN imports.

1. Codenames
2. Just One
3. Telestrations
4. Wavelength
5. Hues and Cues
6. Concept
7. So Clover!
8. Decrypto
9. Monikers
10. Time's Up!
11. Happy Salmon
12. Taco Cat Goat Cheese Pizza
13. Pit
14. Anomia
15. A Fake Artist Goes to New York
16. Herd Mentality
17. Medium

### Cooperative Games - 17

Preferred source: official apps/private-owned installers for rule-enforced games; source-clear implementations only where art/rules/data are approved.

1. Pandemic
2. Forbidden Island
3. Forbidden Desert
4. Forbidden Sky
5. Castle Panic
6. Flash Point: Fire Rescue
7. The Crew: The Quest for Planet Nine
8. The Crew: Mission Deep Sea
9. Hanabi
10. Sky Team
11. Magic Maze
12. Mysterium
13. Chronicles of Crime
14. The Mind
15. Bomb Busters
16. Zombie Kidz Evolution
17. MicroMacro: Crime City

### Classic Board Games - 18

Preferred source: source-clear/open implementations first. Avoid trademarked commercial branding where a generic implementation is enough.

1. Chess
2. Checkers / Draughts
3. Go
4. Backgammon
5. Reversi / Othello-style
6. Connect Four-style
7. Battleship-style
8. Mastermind-style
9. Mancala / Kalah
10. Dominoes
11. Mahjong
12. Nine Men's Morris
13. Gomoku / Five in a Row
14. Ludo / Parchisi
15. Sorry!-style race game
16. Trouble-style pop-and-move game
17. Yahtzee-style dice game
18. Scrabble-style word tile game

### Gateway Strategy Games - 18

Preferred source: official digital/private-owned implementation or authorized module. Pioneers already covers the Catan-like lane cleanly.

1. Catan
2. 7 Wonders
3. 7 Wonders Duel
4. Dominion
5. Small World
6. Stone Age
7. Lords of Waterdeep
8. Raiders of the North Sea
9. Century: Spice Road / Century: Golem Edition
10. Sagrada
11. Welcome To
12. Cartographers
13. Space Base
14. Machi Koro
15. Lost Cities
16. Between Two Cities
17. Flamecraft
18. Colt Express

### Medium-Weight Strategy Games - 17

Preferred source: private-owned official app, authorized VASSAL module, or Tabletop Simulator official DLC. These are lower priority for first family testing.

1. Concordia
2. Agricola
3. Terraforming Mars
4. Scythe
5. Viticulture
6. Great Western Trail
7. Brass: Birmingham
8. Orleans
9. Tzolk'in: The Mayan Calendar
10. The Castles of Burgundy
11. Puerto Rico
12. Terra Mystica
13. Clans of Caledonia
14. Everdell
15. Dune: Imperium
16. Ark Nova
17. El Grande

### Trading And Economic Games - 16

Preferred source: official/authorized modules. These are excellent adult-family games but often need a human host who can teach auctions/trades.

1. Acquire
2. Bohnanza
3. For Sale
4. High Society
5. Modern Art
6. Chinatown
7. Stockpile
8. Power Grid
9. Container
10. QE
11. Genoa
12. Jaipur
13. The Estates
14. Medici
15. Ponzi Scheme
16. I'm the Boss!

### Tile And Engine-Building Games - 17

Preferred source: official app/private-owned implementation where available; otherwise authorized modules. Keep one edition per title.

1. Calico
2. Isle of Skye
3. Alhambra
4. Lanterns: The Harvest Festival
5. Glen More II: Chronicles
6. Railroad Ink
7. Karuba
8. Metro
9. Suburbia
10. Project L
11. Tiny Towns
12. Barenpark
13. Akropolis
14. Nova Luna
15. My City
16. Next Station: London
17. Dorfromantik: The Board Game

### Deduction And Social Deduction Games - 15

Preferred source: official apps or private/source-clear implementations. For younger groups, prefer clue deduction over heavy bluffing.

1. Clue / Cluedo
2. Scotland Yard
3. Mr. Jack
4. Detective Club
5. The Chameleon
6. Spyfall
7. Werewords
8. One Night Ultimate Werewolf
9. Coup
10. Sleuth
11. Cryptid
12. Turing Machine
13. Awkward Guests
14. Sherlock 13
15. Fugitive

### Card-Driven Board Games - 16

Preferred source: official digital app, source-clear card engine, or authorized module. These are good laptop/tablet candidates because storage is low.

1. UNO
2. Sushi Go Party
3. No Thanks!
4. 6 nimmt!
5. Coloretto
6. The Game
7. Scout
8. Sea Salt & Paper
9. Arboretum
10. Point Salad
11. Fantasy Realms
12. Star Realms
13. Hero Realms
14. Race for the Galaxy
15. San Juan
16. Innovation

### Educational, History, And Science-Themed Games - 15

Preferred source: official/authorized digital version. Include these only if they remain fun without a classroom vibe.

1. Timeline
2. Trekking Through History
3. Trekking the World
4. Trekking the National Parks
5. The World Game
6. Photosynthesis
7. Evolution
8. Oceans
9. Cytosis
10. Periodic
11. Genotype
12. Prime Climb
13. Ion
14. Subatomic
15. Memoir '44

## Essential Must-Have Targets

These are the first "make the shelf feel real" games, mixing already-proven source-clear entries with modern family essentials:

- Already source-clear/proven or near-proven: Pioneers, TEG, KsirK, Ricochet Robots, KFourInLine, KReversi, Kigo/GNU Go, Pentobi, GNU Backgammon, KNavalBattle, Nine Men's Morris.
- Modern family/gateway: Ticket to Ride, Carcassonne, Azul, Kingdomino, Cascadia, Splendor, Codenames, Just One, Pandemic, Forbidden Island, The Crew, Hanabi, Sky Team, Catan/Pioneers lane, 7 Wonders, Dominion, Bohnanza, No Thanks!, 6 nimmt!, Clue/Cluedo.

## Best By Use Case

Best for young children:

- Ticket to Ride: First Journey
- My First Carcassonne
- Dragomino
- Rhino Hero
- Outfoxed!
- Hoot Owl Hoot!
- Race to the Treasure!
- Sleeping Queens
- Labyrinth Junior
- Guess Who?

Best for family nights:

- Ticket to Ride
- Carcassonne
- Azul
- Kingdomino
- Cascadia
- Splendor
- King of Tokyo
- Qwirkle
- The Quest for El Dorado
- Camel Up
- Pandemic
- Forbidden Island
- Codenames
- Just One
- Dixit-style slot: use Hues and Cues or Concept if Dixit assets are unavailable.

Best for larger groups:

- Codenames
- Just One
- Wavelength
- Hues and Cues
- Concept
- So Clover!
- Decrypto
- Monikers
- Time's Up!
- Happy Salmon
- Taco Cat Goat Cheese Pizza
- Pit
- Anomia
- Herd Mentality
- Werewords

Best for experienced players:

- Concordia
- Agricola
- Terraforming Mars
- Scythe
- Viticulture
- Great Western Trail
- Brass: Birmingham
- Orleans
- The Castles of Burgundy
- Power Grid
- Puerto Rico
- Terra Mystica
- Dune: Imperium
- Ark Nova
- El Grande

## Recommended Import Priority Order

1. Proven/source-clear native board shelf: keep the existing 15 board hubs, promote Nine Men's Morris, and fix partials in this order: KNavalBattle, XFrisk, Atlantik, TripleA.
2. Public-domain/generic classics: chess, checkers, dominoes, mancala, gomoku, reversi, backgammon, go, mahjong, dice/word/tile analogs using source-clear assets.
3. Starter family/gateway rights review: Ticket to Ride, Carcassonne, Azul, Kingdomino, Cascadia, Splendor, Codenames, Pandemic, The Crew, Hanabi, 7 Wonders, Dominion, Bohnanza.
4. Party-game implementation review: prioritize games with minimal asset burden and easy LAN/browser table play. Avoid copying proprietary card art when a simple source-clear prompt deck can work.
5. Authorized module/app lane: import only games with official apps, explicit publisher permission, purchased/private installers, or clearly licensed VASSAL/Tabletop assets.
6. Medium/heavy strategy: add after the family shelf proves that the digital board-game UX works for guests.
7. Prune and tune: remove games nobody starts, games with ugly/noisy UX, duplicate mechanisms, broken save states, and source-unclear implementations.

## Starter Subset For Initial Testing - 45 Games

Use this before attempting the full 200:

1. Pioneers
2. TEG
3. KsirK
4. Biloba
5. Ricochet Robots
6. Bovo
7. KFourInLine
8. KReversi
9. Kigo / GNU Go
10. Pentobi
11. GNU Backgammon
12. KNavalBattle
13. XFrisk
14. Nine Men's Morris
15. Chess
16. Checkers / Draughts
17. Dominoes
18. Mancala / Kalah
19. Mahjong
20. Ticket to Ride
21. Carcassonne
22. Azul
23. Kingdomino
24. Cascadia
25. Splendor
26. Codenames
27. Just One
28. Wavelength
29. Hues and Cues
30. Pandemic
31. Forbidden Island
32. The Crew: The Quest for Planet Nine
33. Hanabi
34. Sky Team
35. Mysterium
36. Qwirkle
37. Sushi Go Party
38. 7 Wonders
39. Dominion
40. Stone Age
41. Bohnanza
42. For Sale
43. No Thanks!
44. 6 nimmt!
45. Clue / Cluedo

## Storage Estimate

| Scope | Expected storage | Notes |
|---|---:|---|
| Metadata/catalog only for all 200 | <100 MB | Covers manifests, notes, source URLs, rights status, QA status. |
| Existing source-clear native board shelf | 1-4 GB | Debian package closures plus docs/screenshots. Already mostly represented. |
| Starter subset of 45 with mostly source-clear + metadata-only commercial rows | 2-10 GB | If commercial candidates stay metadata-only until rights review. |
| 200-game VASSAL/module-style library where permissions are clear | 10-60 GB | Highly variable; many modules are small, some use large scans. |
| 200 official commercial digital apps/private installers | 150-600 GB | Depends on Steam/mobile/desktop ports and cached dependencies. |
| Tabletop Simulator-heavy shelf | 50-300 GB+ | Base app/DLC/workshop assets; account/Steam/rights constraints dominate. |

Recommended reservation: start with 25 GB for board-game metadata/native packages, then approve a 250 GB private board-game shelf before importing official apps/modules. Reserve 1 TB only if Steam/TTS or many commercial apps become part of the plan.

## Licensing, Source, And Implementation Concerns

- Board-game art, card text, boards, rulebooks, trademarks, and official digital implementations are protected even when the rule idea is familiar.
- Do not import random Tabletop Simulator Workshop mods, VASSAL modules, scans, or fan recreations into the public LAN shelf unless permission/source status is clear.
- Board Game Arena and Tabletopia are useful for discovery and playtesting, but they are online/account services, not offline import sources.
- Official digital apps may require purchase, Steam/mobile accounts, DRM, or private installers. Keep those private and out of Git.
- For public LAN Arcade, prefer source-clear analogs and original assets: Pioneers over Catan assets, TEG/KsirK over Risk assets, Atlantik over Monopoly assets, KFourInLine/Pentobi/KReversi/Kigo/GNU Backgammon over trademarked commercial packages.
- Party games often need prompt/card decks. Build source-clear decks instead of copying commercial cards.
- Children's games are often brand/art dependent; use metadata-only until an official/source-clear digital implementation is approved.
- VASSAL is technically useful, especially for heavier strategy and history games, but each module needs a manifest saying whether it is publisher-approved, fan/private-only, or unavailable.

## Practical Next Steps

1. Add a `board-games-wave-1` candidate manifest with fields: title, category, age, player count, source lane, rights status, preferred implementation, estimated storage, QA gate, and notes.
2. Promote the existing source-clear board-game package shelf as Wave 1A and finish partial smokes.
3. Build a generic-classics lane with source-clear art and rules summaries.
4. For the 45-game starter subset, mark each row as `import-now`, `metadata-only`, `private-owned-needed`, `online-reference-only`, or `blocked`.
5. Only after the starter subset is pleasant to launch, expand toward the full 200.

## Public Sources Checked For Source-Lane Planning

- Board Game Arena game list: https://boardgamearena.com/gamelist
- Tabletopia public site, which describes a large online sandbox catalog: https://tabletopia.com/
- VASSAL, open-source board/card game engine and module library: https://vassalengine.org/
- Tabletop Simulator official site and Steam page/DLC lane: https://www.tabletopsimulator.com/ and https://store.steampowered.com/app/286160/Tabletop_Simulator/
