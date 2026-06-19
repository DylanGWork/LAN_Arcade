# My Abandonware Five-Game Intake Audit - 2026-06-19

Scope: quick acquisition experiment for Dylan's tycoon/city-builder lane. Purchase/store-only pages are treated as blocked for this source lane. Raw archives are private-only/legal-review and are stored outside Git on the NFS native-download shelf.

## Hard Blocks

- `railroad-tycoon-ii-review`: My Abandonware page says no longer abandonware and points to GOG. No full-game cache.
- `pharaoh-gold-review`: My Abandonware page points to GOG/Steam; visible downloads are patch/demo extras only. No full-game cache.
- `theme-hospital-corsixth-review`: full-game download is removed / buy path only; CorsixTH remains a private-data path if Dylan supplies owned files.

## Cached Private Batch

| Candidate | Source | Cached bytes | Runtime hypothesis | Current status |
| --- | --- | ---: | --- | --- |
| `simtower-review` | https://www.myabandonware.com/game/simtower-the-vertical-empire-3f2 | 11582048 | Win3.x/Win95 emulation first | download-cached |
| `create-city-review` | https://www.myabandonware.com/game/create-city-vhz | 4814850 | Wine 32-bit / old InstallShield | download-cached |
| `mobility-city-in-motion-review` | https://www.myabandonware.com/game/mobility-a-city-in-motion-g4m | 41690368 | Wine 32-bit/XP compatibility | download-cached |
| `firestorm-review` | https://www.myabandonware.com/game/firestorm-the-forest-fire-simulation-program-30g | 648592 | DOSBox | download-cached |
| `virtual-city-2003-review` | https://www.myabandonware.com/game/virtual-city-ewx | 70361217 | Wine, English RIP first | download-cached |

Private shelf root:

```text
/srv/lan-arcade/native-downloads/intake/private-tycoon
```

Each cached candidate has:

- `manifest.json`
- `SHA256SUMS.txt`
- `LAUNCH_RECIPE.md`
- `raw/` original downloads
- `work/` placeholder for extraction/install testing

## Runtime Preflight

- `bwrap` is installed and can be used for blocked-network smoke tests.
- `dosbox`, `wine`, and `clamscan` were not found in PATH during this pass.
- No candidate in this batch is marked playable or smoke-passed yet.

## Cautions

- Create City's setup archive contains a serial-number text file. Do not copy that value into Git, public hub pages, or catalog notes.
- Virtual City 2003 used the smaller English RIP, not the larger ISO. If gameplay smoke reveals missing assets/audio, retry the English ISO.
- These are private/legal-review candidates, not public-cache-safe arcade entries.

## Archive Integrity

- Zip archives in the five-game batch passed `unzip -tq`.
- Manual/addendum files for SimTower and Create City are PDFs despite the `.zip` filenames supplied by the source; `pdfinfo` could read their metadata.
- No executable from this batch has been run yet.

## Next Safe Action

Install or prepare isolated runtimes one at a time, starting with the easiest proof: `firestorm-review` under DOSBox. Run each smoke with outbound network blocked, capture screenshots/logs under `qa/reports/private-tycoon/`, then promote only proven candidates from `download-cached` to `partial` or `smoke-pass`.
