# Yearly Top Games Acquisition Sweep - 2000 to 2016

Created: 2026-06-19

This sweep builds a popularity seed list of the top 10 highly rated games for
each year from 2000 through 2016, then adds a first-pass acquisition reality
check for LAN Arcade intake.

Data file:

```text
game-intake/yearly-top-games-2000-2016-acquisition-sweep.csv
```

## Method

- Seed source: Wikipedia's `YEAR_in_video_games` pages, using the rendered
  `Metacritic` / `GameRankings` score tables where present.
- Scope: 17 years x 10 games = 170 rows.
- Dedupe: duplicate platform releases in the same year collapse to one title.
- Acquisition pass: metadata-only. No archives, ISOs, installers, ROMs, or game
  files were downloaded.

This is a popularity/research map, not a promotion queue.

## Status Counts

The current CSV classifies rows as:

- `console-title-private-media-only`: mostly console exclusives; only usable if
  Dylan supplies owned media/dumps for a private emulator shelf.
- `modern-commercial-likely-store-only`: likely Steam/GOG/official-store only;
  do not acquire from random mirrors.
- `pc-classic-source-probe-needed`: older PC title worth a source-page check.
- `known-fail-store-or-private-only`: already checked or known to be blocked by
  purchase-only/full-game-unavailable source pages.
- `matched-prior-verified-page-visible-private`: already matched to a prior
  download-visible classics/tycoon sweep row.
- `official-free`, `free-to-play-online`, `commercial-indie-store`, or
  `commercial-store`: special cases needing per-game handling.

## Immediate Lessons

- A top-rated 2000-2016 list is much more console-heavy than the classic PC
  downloadability sweep. Most entries are not legal web-download tasks.
- The most useful candidates are the PC rows from 2000-2008 and the titles that
  already matched prior visible-download sweeps.
- For 2010-2016, most top-rated games are modern commercial/store-only titles.
  Good offline candidates from this period are more likely to come from indie
  freeware/open-source directories than from the absolute top-10 review lists.

## High-Value Follow-Ups

Worth checking source pages next:

- Baldur's Gate II: search confirmed the My Abandonware page points to GOG, so
  treat as private-owned/store-only unless another approved source exists.
- Unreal Tournament 2004: official Epic page exists; determine whether Epic
  still offers a free/redistributable installer or only metadata.
- Championship Manager 4 / Championship Manager 01/02: football-management lane;
  prior broad sweep found 01/02 download-visible.
- Pro Evolution Soccer 3: likely private classic source check.
- Civilization IV: likely store-only for full game; open alternatives already
  exist through Freeciv/Unciv.
- Company of Heroes, GTR 2, Galactic Civilizations II: source-page check before
  any acquisition claim.

Already matched to prior visible-download rows:

- Tony Hawk's Pro Skater 2
- Tony Hawk's Pro Skater 3
- Tony Hawk's Pro Skater 4

Already known blocked/private-only:

- Grand Theft Auto III
- Grand Theft Auto: Vice City
- Grand Theft Auto: San Andreas

## Recommended Next Hunt

Use this file to pick focused source checks, not direct downloads:

1. Filter the CSV to `pc-classic-source-probe-needed`.
2. For each title, search only official/source pages and reputable classic-game
   pages.
3. Record `pass-free-download-visible`, `fail-purchase-only`, or
   `fail-extras-only`.
4. Only after that should another agent acquire one selected file and write
   manifest/checksums.

For actually getting games into LAN Arcade quickly, the better next queue is
still:

- `classic-downloadability-sweep-2026-06-19.csv`
- `tycoon-downloadability-sweep-2026-06-19.csv`

Those files have more directly actionable visible-download candidates.
