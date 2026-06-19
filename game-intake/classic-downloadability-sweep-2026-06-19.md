# Classic Downloadability Sweep - 2026-06-19

This is a broader follow-up after the tycoon-only sweep. Dylan asked for popular
late-1990s/2000s classics such as Tony Hawk, Midtown Madness, Need for Speed,
Grand Theft Auto-era games, and more tycoon/management titles.

The CSV beside this file has 100 actionable rows:

```text
game-intake/classic-downloadability-sweep-2026-06-19.csv
```

## Meaning Of Eligible

For this sweep, `eligible` means one of:

- a source page was checked and visibly exposed a download/archive size;
- the prior tycoon sweep already checked a visible download;
- the project is an official open/free/packageable alternative with a plausible
  offline cache path.

It does **not** mean the game has passed legal review, is public-cache-safe, or
works offline. Most My Abandonware-style rows remain private-only until Dylan
decides otherwise.

## Best First Batch

Small or high-confidence classics:

- Sid Meier's Railroad Tycoon Deluxe
- SimCity classic
- SimFarm
- The Incredible Machine 1/2
- Lemmings
- Prince of Persia
- Oregon Trail Deluxe
- Dune II
- SimAnt
- Need for Speed II: SE
- Midtown Madness
- Tony Hawk's Pro Skater 2

Higher-impact but more Windows/Wine risk:

- Need for Speed: Most Wanted
- Need for Speed: Underground 2
- Midtown Madness 2
- Zoo Tycoon: Complete Collection
- The Movies
- Black & White
- Tony Hawk's Underground 1/2
- Driver
- Midnight Club II

Very large/defer:

- Blur
- Need for Speed: Carbon
- Need for Speed: ProStreet
- Driver: San Francisco
- Spider-Man: Web of Shadows
- TOCA Race Driver 2

## Known Store-Only Or Not Useful From Checked Pages

Do not spend install-agent time on these unless Dylan supplies files from
another source:

- RollerCoaster Tycoon
- RollerCoaster Tycoon 2
- Railroad Tycoon II
- SimCity 2000
- SimCity 3000 Unlimited
- Pharaoh: Gold
- Caesar III
- Theme Hospital
- Grand Theft Auto III
- Grand Theft Auto: Vice City
- Grand Theft Auto: San Andreas
- Carmageddon 3: TDR 2000
- Capitalism / Capitalism II
- Industry Giant

## Next Agent Instruction

Use the CSV, not memory:

1. Pick one row with `verified-page-visible-private`,
   `verified-from-tycoon-sweep-private`, or `official-free-or-packageable`.
2. Recheck the source page immediately before acquisition.
3. Download only the selected file/version, not all variants.
4. Put raw files under:

```text
/srv/lan-arcade/native-downloads/intake/private-classics/<game-id>/raw/
```

or for open/packageable games:

```text
/srv/lan-arcade/native-downloads/intake/<game-id>/raw/
```

5. Write `manifest.json` and `SHA256SUMS.txt`.
6. Run a blocked-network gameplay smoke.
7. Save screenshots/logs under:

```text
/home/dylan/LAN_Arcade/qa/reports/classic-intake/<game-id>-<timestamp>/
```

8. Only then update `candidates.csv` to `download-cached`, `partial`,
   `blocked`, or `smoke-pass`.

## Source Notes

The first 60-ish rows were checked from My Abandonware's top-download and
targeted pages with metadata-only page fetches. No archives were downloaded.
The open alternatives were added from official project/package sources and need
normal license/version manifest checks before caching.
