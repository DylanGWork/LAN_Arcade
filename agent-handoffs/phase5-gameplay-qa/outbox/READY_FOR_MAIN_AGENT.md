# Ready For Main Agent - Phase 5 Gameplay QA Expanded Pass

Batch complete from `/home/dylan/LAN_Arcade/agent-handoffs/phase5-gameplay-qa`.

## Counts

- Attempted gameplay tests: 30
- playable: 2
- partly_playable: 22
- not_playable: 4
- needs_manual_human_test: 2
- blocked_missing_files / blocked_external_dependency: 0

Nested inventory/categorization rows discovered: 1,324.

Nested shelf counts:
- top-level catalog: 152
- private ROM vault: 743
- curated/private ROM wave 1: 201
- board games wave 1: 200
- private DOS vault: 28

## Evidence

- Batch 1 CSV: `work/gameplay-results.csv`
- Curated Game Boy CSV: `work/rom-wave-gameplay-results.csv`
- Ready Classic PC remainder CSV: `work/dos-remainder-gameplay-results.csv`
- Combined CSV: `work/gameplay-results-expanded.csv`
- Inventory CSV: `work/nested-library-inventory.csv`
- Categorized inventory CSV: `work/nested-library-categorized.csv`
- Board categorization CSV: `work/board-game-categorization.csv`
- Screenshots directory: `screenshots/`
- Logs directory: `logs/`

## Major Player-Facing Findings

- DOS entries can reach a title/splash screen but still not prove gameplay. SimAnt, SimCity Classic, and The Incredible Machine need targeted startup/control passes before being labelled playable from this Phase 5 evidence.
- Prince of Persia shows a black emulator area after input; this should be treated as not playable until the bundle/startup path is fixed or documented.
- Lemmings crashed the browser during the pass; retest alone with memory observation and inspect js-dos runtime/bundle behavior.
- Tobu Tobu Girl Deluxe reaches the title screen, but automated Start/Jump key attempts did not advance to gameplay. Manual key/focus verification needed.
- EvoLab starts and runs, but the first-run tutorial/setup overlay can obscure the simulation and intercept semantic clicks.
- Pillage First works when launched via the HTTPS live route, but the HTTP hub screenshots show broken image icons.
- Curated Game Boy Wave 1 direct launchers load emulator/title screens, but the automated key path did not prove Start/A gameplay for the 10 sampled picks.
- Ready Classic PC/DOS entries often stop at DOSBox welcome, title, or loading screens; generic keypresses are not enough to prove gameplay.
- Board game wave 1 is mostly metadata-only: 192 of 200 entries need rights/source/manual research before gameplay testing. The 8 local/open entries are native/client/manual candidates rather than browser-play proofs.

## Major Technical Findings

- `pillage-first-lan` is playable: created a local world, reached resources, selected Woodcutter, saw level/cost panel. Evidence: `screenshots/pillage-first-lan/04-world-created.png`, `05-field-selected.png`, `06-field-action-after-click.png` and `logs/pillage-first-lan/field-action.json`.
- `evolab` is playable: population/resources changed after Start Simulation. Evidence: `screenshots/evolab/03-simulation-running.png` and `logs/evolab/evolab-playtest.json`.
- `prince-of-persia-ma` black-screened despite canvas detection.
- `lemmings-ma` produced `Target crashed` during screenshot.
- `unciv-lan` and `mindustry-lan` remain `needs_manual_human_test`; this pass did not start native services or clients.
- `black-gold-dos-ma` and `rogue-ma` crashed headless Chromium during the DOS remainder pass.
- `gta-london-1961-ma` logged `ExitStatus: ExitStatus`.
- `railroad-tycoon-dos-ma` logged repeated `RangeError: offset is out of bounds`.

## Regression Callouts

These failures would likely pass old page-load or HTTP-200 QA:

- SimAnt: emulator/splash present, no colony action.
- SimCity Classic DOS: title menu present, no new city/zoning action.
- The Incredible Machine: title screen present, no puzzle interaction.
- Tobu Tobu Girl Deluxe: emulator/title present, no platforming action.
- Prince of Persia: canvas/page present, black game output.
- Lemmings: launch path present, browser crashed during gameplay QA.
- Curated Game Boy entries: emulator/title present, but no first in-game action proved.
- Ready Classic PC remainder: js-dos runtime present, but no first title-specific action proved for most entries.
