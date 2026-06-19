# Tycoon Downloadability Sweep - 2026-06-19

This sweep fixes the earlier overly-broad tycoon queue. A page is not enough.
The next agent needs a source page that actually exposes a free full-game
download, not only a purchase link, manual, patch, demo, or store redirect.

## Gate

`pass-free-download-visible` means the checked source page visibly offered a
download for the game/archive itself. It does not mean the game is legally
public-cache-safe, and it does not mean the game works offline yet.

`fail-purchase-only` means the checked page pointed to GOG/Steam/another store
for the full game and did not visibly offer a full-game download.

`fail-extras-only-purchase-full-game` means the checked page offered only
manuals, patches, demos, or extras while directing the full game to a store.

For this batch, even `pass-free-download-visible` items should remain
private-only unless Dylan later decides otherwise. Do not put raw archives,
ISOs, installers, CD images, serials, cracks, or extracted commercial data into
Git.

## Actual Acquisition Queue

Start here instead of the GOG-only classics:

| Priority | Candidate ID | Title | Source | Evidence | Runtime | First smoke |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `railroad-tycoon-deluxe-dos-ma` | Sid Meier's Railroad Tycoon Deluxe | `https://www.myabandonware.com/game/sid-meier-s-railroad-tycoon-deluxe-22z` | Visible `Download 9 MB` plus browser-play option. | DOSBox / EmulatorJS | Start company, build track/station/train. |
| 2 | `railroad-tycoon-dos-ma` | Sid Meier's Railroad Tycoon | `https://www.myabandonware.com/game/sid-meier-s-railroad-tycoon-zn` | Visible DOS downloads: codes, install disks, pre-installed package, manual. | DOSBox / EmulatorJS | Start company and build first route. |
| 3 | `a-train-dos-ma` | A-Train | `https://www.myabandonware.com/game/a-train-1bn` | Visible `Download 1 MB` plus browser-play option. | DOSBox / EmulatorJS | Start map and create first rail/property action. |
| 4 | `sim-farm-dos-ma` | SimFarm | `https://www.myabandonware.com/game/sim-farm-204` | Visible `Download 1 MB` plus browser-play option. | DOSBox / EmulatorJS | Start farm and place/plant first field. |
| 5 | `simcity-classic-dos-ma` | SimCity | `https://www.myabandonware.com/game/simcity-ri` | Visible `Download 381 KB` plus browser-play option. | DOSBox / EmulatorJS | Start city and place roads/zones/power. |
| 6 | `zoo-tycoon-windows-ma` | Zoo Tycoon | `https://www.myabandonware.com/game/zoo-tycoon-a3d` | Visible Windows ISO downloads; English ISO listed as 567 MB. | Wine / VM | Install, launch, open/build first zoo. |
| 7 | `sim-theme-park-windows-ma` | Sim Theme Park / Theme Park World | `https://www.myabandonware.com/game/sim-theme-park-a20` | Visible `Download 465 MB`. | Wine / VM | Install, create/open first park. |
| 8 | `simcoaster-windows-ma` | SimCoaster / Theme Park Inc. | `https://www.myabandonware.com/game/simcoaster-a27` | Visible `Download 165 MB`. | Wine / VM | Install, create/open first park. |
| 9 | `simsafari-windows-ma` | SimSafari | `https://www.myabandonware.com/game/simsafari-bf4` | Visible `Download 23 MB`. | Wine / VM | Create safari/camp and place first animal/building. |
| 10 | `big-biz-tycoon-2-windows-ma` | Big Biz Tycoon! 2 | `https://www.myabandonware.com/game/big-biz-tycoon-2-ewu` | Visible RIP download listed as 70 MB. | Wine | Start company/office loop. |
| 11 | `entrepreneur-windows-ma` | Entrepreneur | `https://www.myabandonware.com/game/entrepreneur-dlm` | Visible `Download 17 MB`. | Wine / VM | Start product/company loop. |
| 12 | `black-gold-dos-ma` | Black Gold / Oil Imperium | `https://www.myabandonware.com/game/black-gold-lu` | Visible `Download 363 KB` plus browser-play option. | DOSBox / EmulatorJS | Start oil business scenario. |
| 13 | `railroad-empire-dos-ma` | Railroad Empire / Take the A-Train II | `https://www.myabandonware.com/game/railroad-empire-qv` | Visible `Download 338 KB` plus browser-play option. | DOSBox / EmulatorJS | Start railroad map. |
| 14 | `take-a-train-iv-dos-ma` | Take the A-Train IV | `https://www.myabandonware.com/game/take-the-a-train-iv-fam` | Visible `Download 845 KB`. | DOSBox | Start game and verify language/usability. |
| 15 | `3d-roller-coaster-designer-windows-ma` | 3D Roller Coaster Designer | `https://www.myabandonware.com/game/3d-roller-coaster-designer-j8o` | Visible `Download 100 MB`. | Wine / VM | Installer and first coaster/design screen. |
| 16 | `create-city-windows-ma` | Create City | `https://www.myabandonware.com/game/create-city-vhz` | Visible `Download 5 MB`. | Wine | Only proceed if higher-priority city builders block; comments suggest design issues. |
| 17 | `corporate-pursuit-win3x-ma` | Corporate Pursuit | `https://www.myabandonware.com/game/corporate-pursuit-fmq` | Visible `Download 27 MB`. | Windows 3.x / WineVDM / VM | Start company/product loop. |

## Failed For This Acquisition Gate

Do not send these to a download/install agent unless Dylan supplies files from
another source.

| Candidate | Result | Why |
| --- | --- | --- |
| RollerCoaster Tycoon | `fail-purchase-only` | Checked page shows GOG/Steam buy links and no visible full download. |
| RollerCoaster Tycoon 2: Triple Thrill Pack | `fail-purchase-only` | Checked page says it is no longer abandonware and points to GOG/Steam. |
| Railroad Tycoon II: Gold Edition | `fail-purchase-only` | Checked page points to GOG for the full game. |
| Railroad Tycoon 3 | `fail-purchase-only` | Checked page points to GOG/Steam. |
| SimCity 2000: CD Collection | `fail-purchase-only` | Checked page points to GOG for the full game. |
| SimCity 3000 Unlimited | `fail-purchase-only` | Checked page points to GOG. |
| Pharaoh: Gold | `fail-extras-only-purchase-full-game` | Checked page points to GOG/Steam and only offers patch/demo extras. |
| Caesar III | `fail-extras-only-purchase-full-game` | Checked page points to GOG/Steam and only offers demo/manual extras. |
| Theme Hospital | `fail-extras-only-purchase-full-game` | Checked page points to GOG and only offers manual/extras. |
| Transport Tycoon Deluxe | `fail-extras-only-purchase-full-game` | Checked page points to Steam and only offers manual/patch extras. |
| Theme Park | `fail-demo-only-purchase-full-game` | Checked page points to GOG and only offers demo extras. |
| Capitalism | `fail-purchase-only` | Checked page points to GOG. |
| Capitalism II | `fail-purchase-only` | Checked page points to GOG/Steam. |
| Industry Giant | `fail-purchase-only` | Checked page points to GOG/Steam. |

## Next Agent Instruction

Start with `tycoon-downloadability-sweep-2026-06-19.csv`, not the older
private tycoon queue. Pick one `pass-free-download-visible` row at a time.

For each selected row:

1. Download/acquire only that one listed file or language variant.
2. Store raw files under:

```text
/srv/lan-arcade/native-downloads/intake/private-tycoon/<game-id>/raw/
```

3. Write `manifest.json` and `SHA256SUMS.txt`.
4. Extract/install only under:

```text
/srv/lan-arcade/native-downloads/intake/private-tycoon/<game-id>/work/
```

5. Run a blocked-network gameplay smoke.
6. Save screenshots/logs under:

```text
/home/dylan/LAN_Arcade/qa/reports/private-tycoon/<game-id>-<timestamp>/
```

7. Update `candidates.csv` only after evidence exists:

- `download_status=download-cached` after raw files and checksums exist.
- `intake_status=partial` if it launches but gameplay is not proven.
- `intake_status=smoke-pass` only after meaningful offline gameplay.
- `intake_status=blocked` if the installer/runtime fails.

## Notes

- OpenTTD remains the clean public path for Transport Tycoon-style play.
- Micropolis remains the clean public path for classic SimCity-style play.
- OpenRCT2/OpenLoco/Julius/Augustus remain good engines, but they need
  privately supplied original data files; the checked My Abandonware pages for
  their obvious commercial sources did not pass this free-download gate.
