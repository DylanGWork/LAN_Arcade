# Phase 0 Stabilization Snapshot - 2026-06-27

## Scope

Phase 0 stabilised the current deployed LAN Arcade state before account and library architecture changes.

Included in the stabilisation commit group:

- Agent/rules documentation for recent regression lessons.
- Main library nested-search and browser-local Recently played behaviour.
- Classic PC/DOS player memory mitigation using js-dos worker/canvas mode and unload cleanup.

Explicitly excluded for later review:

- `game-intake/candidates.csv` open-source Wave 1 candidate additions.
- `game-intake/source-notes.md` intake note changes.
- Untracked game-intake sweep files.
- `game-ops/` Pillage First operator handover files.

## Git Baseline Before Commit

```text
HEAD: c8425e4be2c00fe0ee9b219078b7a3bb2ad335af
Branch: main
Remote: https://github.com/DylanGWork/LAN_Arcade.git
```

## Deployed Inventory Snapshot

```text
Main catalog: 152 top-level cards
Classic PC/DOS vault: 28 entries
Classic PC/DOS package states: smoke-pass=1, source-ready=11, partial=3, blocked=1, candidate=12
Game Boy/GBC vault: 743 selected playable links
Game Boy/GBC Wave 1: 201 curated links
Board Games Wave 1: 200 entries, including 6 playable-local, 1 partial-local, 1 analog-local, 192 metadata-only
```

## URL Checks

Checked from the VM:

```text
http://127.0.0.1/mirrors/games/ -> 200
http://127.0.0.1/mirrors/private-dos-vault/ -> 200
http://127.0.0.1/mirrors/private-rom-vault/ -> 200
https://127.0.0.1/mirrors/pillage-first/ -> 200
```

## QA Evidence

Static mirror audit:

```text
npm run qa:static
Games scanned: 152
OK: 152
Needs attention: 0
Games with external dependency refs in entry HTML: 0
```

Focused browser regression checks:

- LAN-origin `/mirrors/games/` loads.
- Searching `simant` returns direct `SimAnt` playable card first.
- Opening SimAnt reaches `/mirrors/private-dos-vault/play.html?id=simant-ma`.
- Returning to `/mirrors/games/` shows SimAnt in Recently played.
- Pixel 5 mobile viewport search for SimAnt has no horizontal overflow.

## Review Result

Phase 0 is clean enough to commit the stabilisation group. The remaining dirty intake files are valid-looking candidate/intake work but are not part of this stabilisation baseline and should be reviewed before promotion or commit.
