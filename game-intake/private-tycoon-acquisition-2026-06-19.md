# Private Tycoon Acquisition Batch - 2026-06-19

This is a handoff for acquiring and testing classic tycoon/city-builder games
that Dylan wants considered for LAN Arcade after separate rights review.

Update after stricter downloadability sweep: read
`game-intake/tycoon-downloadability-sweep-2026-06-19.md` and
`game-intake/tycoon-downloadability-sweep-2026-06-19.csv` before using the queue
below. Several wishlist items here failed the practical acquisition gate because
their checked My Abandonware pages now point to GOG/Steam or offer only extras.
Use the newer sweep as the source of truth for what an agent should try to
download first.

These are not public-cache-safe by default. Treat this batch as
`private-only-or-legal-review` until a later agent records a clearer
redistribution decision. Do not put raw archives, ISOs, installers, CD images,
serials, ROMs, or extracted commercial data into Git.

## Decision Model

Use these gates:

| Gate | Meaning | Evidence |
| --- | --- | --- |
| `wanted` | Dylan wants this game in the intake queue. | Row in this file and `candidates.csv`. |
| `acquired-private` | Raw archive/installer/data exists on the VM private intake shelf. | Manifest with source URL, timestamp, size, and SHA256. |
| `install-draft` | A VM-local install or emulator wrapper exists. | Install notes and exact command. |
| `offline-smoke-pass` | Real gameplay works without internet. | Screenshot/log under `qa/reports/` plus blocked-network run notes. |
| `partial` | Launches but no real gameplay proof yet. | Screenshot/log and blocker notes. |
| `blocked` | Cannot install, crashes, missing data, or needs external service/network. | Error log and next action. |

Do not use `smoke-pass` or claim playable from download success alone.

## Storage Rules

Preferred private raw-file shelf:

```text
/srv/lan-arcade/native-downloads/intake/private-tycoon/<game-id>/raw/
```

Per-game manifest:

```text
/srv/lan-arcade/native-downloads/intake/private-tycoon/<game-id>/manifest.json
```

The manifest should include:

- `game_id`
- `title`
- `source_url`
- `acquired_by`
- `acquired_at`
- `private_only: true`
- `redistribution_status`
- `files`: name, size bytes, sha256
- `notes`

If Dylan downloads manually, copy the original files into the `raw/` folder and
leave filenames unchanged where practical. The next agent should then compute
checksums and write the manifest before extracting anything.

If an agent downloads on Dylan's behalf, do it one game at a time. Do not bulk
mirror My Abandonware. Rate-limit requests. Store only the selected files listed
in this handoff.

## Target Queue

| Priority | Candidate ID | Title | Source | Acquisition mode | Runtime hypothesis | Pass condition |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `simcity-2000-review` | SimCity 2000 CD Collection | `https://www.myabandonware.com/game/simcity-2000-cd-collection-311` | Dylan-approved private acquisition or Dylan manual upload | DOSBox first; Wine only if DOS path fails | Start a city, place roads/zones/power, save screenshot/log offline. |
| 2 | `railroad-tycoon-ii-review` | Railroad Tycoon II Gold Edition | `https://www.myabandonware.com/game/railroad-tycoon-ii-gold-edition-3p6` | Dylan-approved private acquisition or Dylan manual upload | Wine first; DOSBox only if a DOS build is supplied | Start scenario, build first track/station/train route, save screenshot/log offline. |
| 3 | `pharaoh-gold-review` | Pharaoh: Gold | `https://www.myabandonware.com/game/pharaoh-gold-d5o` | Dylan-approved private acquisition or Dylan manual upload | Wine first | Start campaign/tutorial, place housing/roads, save screenshot/log offline. |
| 4 | `theme-hospital-corsixth-review` | Theme Hospital via CorsixTH | `https://www.myabandonware.com/game/theme-hospital-2ek` plus `https://corsixth.com/` | Prefer CorsixTH demo/full-game data path after Dylan approval | CorsixTH engine with private game/demo data | Build first room or reach playable hospital map, save screenshot/log offline. |
| 5 | `simtower-review` | SimTower: The Vertical Empire | `https://www.myabandonware.com/game/simtower-the-vertical-empire-3f2` | Dylan-approved private acquisition or Dylan manual upload | Wine/Win16 compatibility research; possible Windows 3.x emulation if needed | Build first lobby/elevator/floor, save screenshot/log offline. |
| 6 | `caesar3-julius-augustus-private-data` | Caesar III via Julius/Augustus | `https://www.myabandonware.com/game/caesar-iii-3h9` plus engine source | Dylan-owned/private data only | Julius or Augustus engine with private Caesar III data | Start tutorial/campaign, place housing/roads/water, save screenshot/log offline. |
| 7 | `openrct2-private-data` | OpenRCT2 with RCT2/RCT Classic data | `https://docs.openrct2.io/en/latest/installing/getting-rct2.html` | Dylan-owned/private RCT2/RCT Classic data only | OpenRCT2 native engine | Load scenario/sandbox, build path/ride, save screenshot/log offline. |
| 8 | `openloco-private-data` | OpenLoco with Locomotion data | `https://github.com/OpenLoco/OpenLoco` | Dylan-owned/private Locomotion data only | OpenLoco native engine | Start scenario, build first route, save screenshot/log offline. |
| 9 | `transport-tycoon-deluxe-review` | Transport Tycoon Deluxe original data | `https://www.myabandonware.com/game/transport-tycoon-deluxe-2sd` | Low priority private acquisition; OpenTTD already covers public lane | DOSBox or private OpenTTD data import | Start company and build a first route, save screenshot/log offline. |

## Recommended Next Agent Workflow

1. Pick one game, starting with SimCity 2000.
2. Confirm whether Dylan wants agent-side download or manual upload for that
   title.
3. Put raw files under the `private-tycoon/<game-id>/raw/` folder.
4. Write `manifest.json` and `SHA256SUMS.txt` before extracting.
5. Extract/install into a VM-local working folder outside Git, for example:

```text
/srv/lan-arcade/native-downloads/intake/private-tycoon/<game-id>/work/
```

6. Build the smallest repeatable launch recipe.
7. Run with outbound network unavailable or blocked.
8. Capture screenshot and logs under:

```text
/home/dylan/LAN_Arcade/qa/reports/private-tycoon/<game-id>-<timestamp>/
```

9. Update `game-intake/candidates.csv`:

- `download_status=download-cached` only after manifest/checksums exist.
- `intake_status=partial` if it launches but gameplay is not proven.
- `intake_status=smoke-pass` only after offline gameplay evidence exists.
- `intake_status=blocked` with notes if install/play fails.

## Public Arcade Rule

For this batch, do not add raw download links to the public catalog. A future
hub may be appropriate only after Dylan approves the private-file handling and a
smoke pass exists. Any hub should state whether the game is private-file-backed,
requires a native client/emulator, and what local path or launcher is used.
