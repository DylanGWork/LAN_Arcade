# Bulk Game Import Wave 1 Plan

Date: 2026-06-21
Status: planning only; no imports started by this document.

## Recommendation

Use a curated emulator-first wave: target 200 promoted games from a 207-candidate
pool.

This is the best high-success path because the VM already has a deduplicated,
English-friendly private GB/GBC vault and a no-AI EmulatorJS smoke runner. Treat
200 as a planning wave, not a single blind promotion. Run it in batches of about
50, promote only smoke-passing games, and use the extra seven candidates as
failure replacements.

Do not use Windows/Wine classics, PS1/N64, or large native games for this bulk
wave. They are better handled in 5-15 game batches because setup, controls,
installer behavior, and offline checks vary too much.

## Existing Evidence Reviewed

- `docs/EMULATOR_LIBRARY_PLAN.md`: private ROM vault build and no-AI smoke flow.
- `docs/GAME_INTAKE_AGENT_HANDOVER.md`: intake rules, private media rules, smoke gate.
- `game-intake/yearly-top-games-2000-2016-acquisition-sweep.md`: high-rated seed list, mostly private/store-only for non-handheld systems.
- `game-intake/classic-downloadability-sweep-2026-06-19.md`: useful but mostly private/manual Windows/DOS intake.
- `game-intake/tycoon-downloadability-sweep-2026-06-19.md`: DOS/Wine classics queue, not suitable for 200-at-once.
- `/var/www/html/mirrors/private-rom-vault/manifest.json`: 743 selected English-friendly GB/GBC titles from 2,184 archive ROM files.
- `/var/www/html/mirrors/private-dos-vault/manifest.json`: six DOS classics currently packaged.

Current private ROM vault counts:

```text
Game Boy:       79 selected titles, 22.3 MiB ROM data
Game Boy Color: 664 selected titles, 826.1 MiB ROM data
Full vault:     743 titles, about 850 MiB on disk
EmulatorJS runtime: about 297 MiB one-time shared runtime
```

The proposed 201 GB/GBC title list below is present in the current manifest and
uses about 250 MiB of ROM data.

## Ranked Platform Recommendations

1. Game Boy / Game Boy Color private vault
   - Quality: high after curated filtering.
   - Metadata: good enough for title/system/language; genre tags need cleanup.
   - Complexity: low; EmulatorJS path exists.
   - Expected success: 90-95 percent after excluding bootlegs/duplicates.
   - Import order: first.

2. DOS classics already in private DOS vault
   - Quality: high recognisable sim/management titles.
   - Metadata: decent from previous tycoon sweep.
   - Complexity: medium; controls/manuals matter.
   - Expected success: 75-85 percent.
   - Import order: after ROM smoke pass, one at a time.

3. GBA private media
   - Quality: potentially very high, but not present in the current selected vault.
   - Complexity: low once Dylan supplies files and a manifest exists.
   - Expected success: 85-95 percent later.
   - Import order: Wave 2 after intake files exist.

4. SNES / Genesis / Master System private media
   - Quality: high possible, but no proven current shelf/manifest in this repo.
   - Complexity: medium until runtime/core controls are proven.
   - Import order: Wave 2/3 pilot batch of 25 each.

5. Windows/Wine classics and large native packages
   - Quality: mixed to excellent, but setup-heavy.
   - Complexity: high.
   - Expected success: 40-70 percent per game until wrappers mature.
   - Import order: keep separate from this wave; 5-15 at a time.

6. PS1/N64/PS2-era private media
   - Quality: high, but storage/config/performance risk is much higher.
   - Complexity: high.
   - Import order: not Wave 1.

## Import Order

1. Build or derive a Wave 1 allowlist from the current private ROM manifest.
2. Run GB batch first: 50 titles.
3. Run GBC in three batches of about 50 titles.
4. Review smoke screenshots and quarantine anything with blank screens, anti-emulator screens, non-English text, broken controls, or obvious bad dumps.
5. Promote the first 200 smoke-passing games into the emulator shelf UI.
6. Run the six DOS titles one at a time as a manual tail; promote only if first-play evidence exists.

Recommended batch shape:

```text
Batch 1: Game Boy 50
Batch 2: Game Boy Color 1-50
Batch 3: Game Boy Color 51-100
Batch 4: Game Boy Color 101-151
Batch 5: DOS classics 6 manual smoke checks
```

## Size And Effort Estimate

```text
Candidate count:          207 total candidates
GB/GBC ROM candidates:    201 titles, about 250 MiB ROM data
DOS candidates:           6 titles, about 1-10 MiB current packaged data
Runtime already cached:   EmulatorJS 4.2.3, about 297 MiB
If ROMs are copied:       about 250 MiB extra
If manifest-only/symlink: near-zero extra ROM storage
Smoke screenshots/reports: estimate 250 MiB to 1 GiB, depending screenshot count
Expected agent effort:    low for ROM wave, medium for report review
Expected wall time:       several unattended smoke batches plus manual review
```

Use manifest/allowlist filtering rather than duplicating ROM files where
possible. Keep all private ROM/package files out of Git.

## Candidate List

The list is deliberately recognisable-heavy and avoids obvious regional variants,
bootlegs, prototypes, demos, duplicate paired editions, and most roster-only sports
sequels. Some teen/adult titles are included for the full GannanNet shelf, not the
kids/camping shelf.

### Game Boy Candidates (50)

1. Adventures of Lolo
2. Alleyway
3. Arcade Classic No. 1 - Asteroids & Missile Command
4. Arcade Classic No. 2 - Centipede & Millipede
5. Arcade Classic No. 3 - Galaga & Galaxian
6. Arcade Classic No. 4 - Defender & Joust
7. Balloon Kid
8. Battletoads in Ragnarok's World
9. Chessmaster, The
10. Donkey Kong
11. Donkey Kong Land
12. Donkey Kong Land 2
13. Donkey Kong Land III
14. Dr. Mario
15. Dynablaster
16. Game & Watch Gallery
17. James Bond 007
18. Kid Icarus - Of Myths and Monsters
19. Killer Instinct
20. Kirby's Block Ball
21. Kirby's Dream Land
22. Kirby's Dream Land 2
23. Kirby's Pinball Land
24. Kirby's Star Stacker
25. Legend of Zelda, The - Link's Awakening
26. Mario & Yoshi
27. Mario's Picross
28. Mega Man - Dr. Wily's Revenge
29. Mega Man II
30. Mega Man III
31. Metroid II - Return of Samus
32. Mole Mania
33. Mystic Quest
34. Pocket Bomberman
35. Pokemon - Red Version
36. QIX
37. SolarStriker
38. Space Invaders
39. Star Wars
40. Street Fighter II
41. Super Mario Land
42. Super Mario Land 2 - 6 Golden Coins
43. Tetris
44. Tetris 2
45. Tetris Attack
46. Top Rank Tennis
47. Vegas Stakes
48. Wario Land - Super Mario Land 3
49. Wario Land II
50. Wave Race

### Game Boy Color Candidates (151)

1. 007 - The World Is Not Enough
2. 1942
3. 3-D Ultra Pinball - Thrillride
4. Aladdin
5. Alice in Wonderland
6. Alone in the Dark - The New Nightmare
7. Asterix & Obelix
8. Asteroids
9. Atlantis - The Lost Empire
10. Azure Dreams
11. Batman - Chaos in Gotham
12. Bionic Commando - Elite Forces
13. Blaster Master - Enemy Below
14. Bomberman Max - Blue Champion
15. Bomberman Quest
16. Bugs Bunny - Crazy Castle 3
17. Bugs Bunny in - Crazy Castle 4
18. Bust-A-Move 4
19. Bust-A-Move Millennium
20. Cannon Fodder
21. Capcom vs SNK - Millennium Fight 2001
22. Centipede
23. Chicken Run
24. Classic Bubble Bobble
25. Colin McRae Rally
26. Commander Keen
27. Conker's Pocket Tales
28. Croc
29. Croc 2
30. Crystalis
31. Deja Vu I & II - The Casebooks of Ace Harding
32. Denki Blocks!
33. Dexter's Laboratory - Robot Rampage
34. Donald Duck - Goin' Quackers
35. Donkey Kong Country
36. Dragon Ball Z - Legendary Super Warriors
37. Dragon Warrior III
38. Dragon Warrior Monsters
39. Dragon Warrior Monsters 2 - Cobi's Journey
40. Driver
41. Duke Nukem
42. Earthworm Jim - Menace 2 the Galaxy
43. Elevator Action EX
44. Emperor's New Groove, The
45. Frogger
46. Frogger 2
47. Galaga - Destination Earth
48. Game & Watch Gallery 2
49. Game & Watch Gallery 3
50. Gex - Enter the Gecko
51. Gex 3 - Deep Cover Gecko
52. Ghosts'n Goblins
53. Grand Theft Auto
54. Grand Theft Auto 2
55. Hamtaro - Ham-Hams Unite!
56. Harry Potter and the Chamber of Secrets
57. Harry Potter and the Sorcerer's Stone
58. Harvest Moon 2 GBC
59. Harvest Moon 3 GBC
60. Heroes of Might and Magic
61. Heroes of Might and Magic II
62. Hexcite - The Shapes of Victory
63. Indiana Jones and the Infernal Machine
64. International Superstar Soccer 2000
65. Kirby - Tilt 'n' Tumble
66. Klax
67. Konami GB Collection Vol.1
68. Konami GB Collection Vol.2
69. Konami GB Collection Vol.3
70. Konami GB Collection Vol.4
71. Legend of the River King 2
72. Legend of Zelda, The - Link's Awakening DX
73. Legend of Zelda, The - Oracle of Ages
74. Legend of Zelda, The - Oracle of Seasons
75. LEGO Island 2 - The Brickster's Revenge
76. LEGO Racers
77. LEGO Stunt Rally
78. Lemmings & Oh No! More Lemmings
79. Lufia - The Legend Returns
80. Magi Nation
81. Magical Tetris Challenge
82. Marble Madness
83. Mario Golf
84. Mario Tennis
85. Mega Man Xtreme
86. Mega Man Xtreme 2
87. Metal Gear Solid
88. Mickey's Racing Adventure
89. Mickey's Speedway USA
90. Micro Machines 1 and 2 - Twin Turbo
91. Micro Machines V3
92. Microsoft - The 6 in 1 Puzzle Collection Entertainment Pack
93. Microsoft Pinball Arcade
94. Midway Presents Arcade Hits - Joust & Defender
95. Midway Presents Arcade Hits - Moon Patrol & Spy Hunter
96. Missile Command
97. Monopoly
98. Monster Rancher Battle Card GB
99. Monster Rancher Explorer
100. Mortal Kombat 4
101. Motocross Maniacs 2
102. Mr. Driller
103. Ms. Pac-Man - Special Color Edition
104. NBA Jam 2001
105. NFL Blitz
106. Oddworld Adventures 2
107. Pac-Man - Special Color Edition
108. Paperboy
109. Perfect Dark
110. Pitfall - Beyond the Jungle
111. Pokemon - Crystal Version
112. Pokemon Pinball
113. Pokemon Puzzle Challenge
114. Pokemon Trading Card Game
115. Power Quest
116. Prince of Persia
117. Project S-11
118. Qix Adventure
119. R-Type DX
120. Rampage - World Tour
121. Rayman
122. Rayman 2
123. Resident Evil Gaiden
124. Return of the Ninja
125. Road Rash
126. San Francisco Rush 2049
127. Scooby-Doo! - Classic Creep Capers
128. Shadowgate Classic
129. Shantae
130. Spider-Man
131. Spider-Man 2 - The Sinister Six
132. Star Wars - Yoda Stories
133. Star Wars Episode I - Racer
134. Street Fighter Alpha - Warriors' Dreams
135. Super Mario Bros. Deluxe
136. Survival Kids
137. Tetris DX
138. Toki Tori
139. Tomb Raider
140. Tony Hawk's Pro Skater 2
141. Top Gear Pocket
142. Top Gear Rally
143. Toy Story 2
144. Uno
145. Wario Land 3
146. Warlocked
147. Wendy - Every Witch Way
148. Worms Armageddon
149. X-Men - Mutant Academy
150. X-Men - Mutant Wars
151. Yu-Gi-Oh! - Dark Duel Stories

### DOS Manual Tail (6)

1. SimCity Classic DOS
2. SimFarm
3. Sid Meier's Railroad Tycoon Deluxe
4. Firestorm: The Forest Fire Simulation Program
5. A-Train
6. Black Gold / Oil Imperium

## Exclusions For This Wave

Exclude these even if present in the selected vault:

- Obvious bootlegs or suspicious hacks: Pokemon Diamond/Jade/Pearl/Sapphire GBC,
  Sonic Adventure 7/8, Super Mario Special 3, Super Marrio Sunshine, Digimon
  clone variants, Rockman DX8, Matel Gear II, Harry Potter clone variants.
- Duplicate regional spelling variants, for example `Color` vs `Colour` Pac-Man
  or Ms. Pac-Man.
- Paired version duplicates unless gameplay is meaningfully different. For this
  wave: Pokemon Red for GB, Pokemon Crystal for GBC, Bomberman Max Blue only,
  Dragon Warrior Monsters 2 Cobi only.
- Most yearly sports roster variants. Keep only a few arcade/popular picks like
  NBA Jam, NFL Blitz, ISS 2000, Tony Hawk, and Top Gear.
- Tools, diagnostics, prototypes, demos, and language-specific releases.

## Metadata And Artwork Prerequisites

Minimum metadata before promotion:

- Title, platform, selected source path, SHA256, private/public status.
- Genre tags cleaned for the promoted subset; current manifest has many
  `Unsorted` entries.
- Family/kids suitability tag separate from genre.
- Smoke screenshot thumbnail generated locally; do not rely on remote artwork.
- Known controls per platform, plus a warning that multiplayer/link-cable modes
  are not supported unless specifically proven.

Nice-to-have metadata after first promotion:

- Release year and publisher from existing manifest/intake notes or local source
  metadata.
- One-line description for the shelf card.
- Content flags for violence, gambling/casino, horror, and mature themes.

## Smoke Gate

Do not promote based on manifest presence. Required evidence:

- Emulator page loads from LAN origin.
- External network blocked.
- Screenshot entropy shows real rendered content.
- Screenshot/manual review rejects anti-emulator messages, blank screens, obvious
  language mismatch, and broken boot loops.
- Save-state smoke is not required for this wave, but should become mandatory
  after account/save architecture lands.

Recommended commands, after a Wave 1 allowlist exists:

```sh
npm run rom:vault:smoke -- --run-id wave1-gb --screenshots one
npm run rom:vault:smoke -- --run-id wave1-gbc-a --screenshots one
npm run rom:vault:smoke -- --run-id wave1-gbc-b --screenshots one
npm run rom:vault:smoke -- --run-id wave1-gbc-c --screenshots one
```

If the current runner cannot target the allowlist directly, add the smallest safe
selection-file option before importing. Do not hand-click 200 games unless a
runner failure needs manual confirmation.

## Risks And Blockers

- Current private ROM smoke report is still empty, so the first real full pass may
  uncover anti-emulator screens or bad dumps.
- The selected profile is English-friendly, not a full quality guarantee.
- Save data is not account-isolated yet; avoid advertising family-safe saves until
  the account/save architecture is implemented.
- Some recognisable titles are not child-friendly. Use shelf/profile tags so the
  camping/kids profile can hide GTA, Resident Evil, Mortal Kombat, etc.
- If a curated shelf copies ROMs instead of using a manifest/allowlist, duplicate
  storage will grow unnecessarily.
- DOS titles need manual first-play checks and manuals; do not bulk-promote them
  alongside the ROM batch.

## Practical Batch Size Decision

A 200-game wave is appropriate only for GB/GBC because the files are small, the
runtime is already cached, and the no-AI smoke runner exists. It is not appropriate
for Windows/Wine/native service games.

Recommended operational target:

- Plan with 207 candidates.
- Smoke in batches of about 50.
- Promote the first 200 that pass the smoke gate and metadata cleanup.
- If pass rate drops below 85 percent, stop after the first 100 passes and review
  the runner/source assumptions before continuing.