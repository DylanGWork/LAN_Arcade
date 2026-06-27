# Ready For Main Agent - Phase 2 Media / Artwork Batch 1

## Summary
- Games scanned: 152 catalogue entries from `/var/www/html/mirrors/games/catalog.json`.
- Games needing artwork: 34 entries with blank/missing/problem previews.
- Games with proposed artwork: 34.
- Games still needing manual research: 0.

## High-Confidence Candidates
- `aevilia-gbc` - Aevilia -> `artwork-candidates/aevilia-gbc/candidate-01.png`
- `breachline-tactics` - Breachline Tactics -> `artwork-candidates/breachline-tactics/candidate-01.png`
- `circuit-foundry` - Circuit Foundry -> `artwork-candidates/circuit-foundry/candidate-01.png`
- `crossconnect-gb` - CrossConnect -> `artwork-candidates/crossconnect-gb/candidate-01.png`
- `domination-gb` - Domination GB -> `artwork-candidates/domination-gb/candidate-01.png`
- `gb-2048` - Game Boy 2048 -> `artwork-candidates/gb-2048/candidate-01.png`
- `gb-wordyl` - GB-Wordyl -> `artwork-candidates/gb-wordyl/candidate-01.png`
- `gene-garden` - Gene Garden -> `artwork-candidates/gene-garden/candidate-01.png`
- `grub-glide-gb` - Grub Glide -> `artwork-candidates/grub-glide-gb/candidate-01.png`
- `lan-tank-arena` - LAN Tank Arena -> `artwork-candidates/lan-tank-arena/candidate-01.png`
- `life-engine` - The Life Engine -> `artwork-candidates/life-engine/candidate-01.png`
- `outpost-siege` - Outpost Siege -> `artwork-candidates/outpost-siege/candidate-01.png`
- `plantboy-gb` - PlantBoy -> `artwork-candidates/plantboy-gb/candidate-01.png`
- `skyland-gba` - Skyland GBA -> `artwork-candidates/skyland-gba/candidate-01.png`
- `tobu-tobu-girl-deluxe` - Tobu Tobu Girl Deluxe -> `artwork-candidates/tobu-tobu-girl-deluxe/candidate-01.png`

## Needs Review
- `armagetronad-lan` - Armagetron Advanced: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `board-games-wave-1` - Board Games Wave 1: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit. Private/commercial/shelf content needs human rights/context review before public-facing use.
- `crawl-tiles-lan` - Dungeon Crawl Stone Soup: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `emulator-library` - Emulator Library: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `evolab` - EvoLab: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `flare-lan` - Flare: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `lincity-ng-lan` - LinCity-NG: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `megaglest-lan` - MegaGlest: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `openclonk-lan` - OpenClonk: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `pillage-first-lan` - Pillage First!: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `pingus-lan` - Pingus: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `private-dos-classics` - Classic PC Games: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit. Private/commercial/shelf content needs human rights/context review before public-facing use.
- `private-gbc-vault` - Private Game Boy Vault: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit. Private/commercial/shelf content needs human rights/context review before public-facing use.
- `private-rom-wave-1` - Game Boy Wave 1: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit. Private/commercial/shelf content needs human rights/context review before public-facing use.
- `retro-emulator-lab` - Retro Emulator Lab: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `supertux-lan` - SuperTux: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.
- `travian-like-lab` - Travian-like Strategy Lab: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit. Private/commercial/shelf content needs human rights/context review before public-facing use.
- `travianz-lan` - TravianZ LAN Service: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit. Private/commercial/shelf content needs human rights/context review before public-facing use.
- `unknown-horizons-lan` - Unknown Horizons: Use as card preview candidate; copied from local VM evidence, no production files changed. Hub/shelf screenshot should be reviewed for card crop/fit.

## Scripts / Method
- Used an inline Python scanner from this handoff folder to read the live generated catalogue and copy local QA/mirrored assets into `artwork-candidates/`.
- BMP local assets were converted to PNG via `/usr/bin/ffmpeg` only inside the handoff candidate folder.
- No production files were changed.
