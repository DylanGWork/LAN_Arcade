# Phase 19 Library Discovery Smoke Review - 2026-06-27

## Scope

Added a reusable, non-destructive Playwright regression smoke for the main Game Library discovery flow.

## Changes

- Added `qa/library-discovery-smoke.mjs`.
- Added package shortcut: `npm run qa:library-discovery`.

## What It Tests

- Main library loads without page errors.
- Public wording regressions are absent:
  - no `top-level cards`
  - no `Native / services`
- Recently played shelf is hidden before a launch.
- Searching `simant` returns a direct `SimAnt` card.
- `SimAnt` links directly to `/mirrors/private-dos-vault/play.html?id=simant-ma`.
- The SimAnt action label is `Play`.
- Clicking SimAnt records browser-local recent activity.
- Returning to the library shows `Recently played` with SimAnt.
- No local HTTP failures are observed during the flow.

## Checks

- `node --check qa/library-discovery-smoke.mjs`
- `npm run qa:library-discovery -- --report-dir qa/reports/phase19-library-discovery`
- `npm run qa:static`: 152 games scanned, 152 OK, 0 needing attention

Report written locally to:

`qa/reports/phase19-library-discovery/result.json`

## Review

This closes the specific regressions Dylan hit around SimAnt search, nested Classic PC discovery, stale operator wording, and recently played visibility. It does not test account creation or save isolation because this smoke is intentionally non-destructive and safe to run repeatedly.

## Next Useful QA Work

Add a separate account-auth smoke that creates and deletes a temporary account only when an explicit cleanup path is configured. Keep that separate from this general discovery smoke.
