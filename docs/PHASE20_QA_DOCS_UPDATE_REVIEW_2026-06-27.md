# Phase 20 QA Docs Update Review - 2026-06-27

## Scope

Updated the project handover and VM QA notes so future agents use the current
library discovery regression instead of manual one-off checks.

## Changes

- Documented the two Recently played modes:
  - guest/browser-local history uses `localStorage`;
  - signed-in accounts use server-backed recent activity through
    `/arcade-api/account/activity`.
- Replaced the old manual nested-title search snippet with the required commands:
  - `npm run qa:static`
  - `npm run qa:library-discovery`
- Recorded that `qa:library-discovery` validates direct `simant` search, stale
  operator wording absence, and Recently played after launch.
- Kept mobile/narrow viewport checks as an additional requirement when layout or
  CSS changes.

## Review

Confirmed the docs change is documentation-only and does not alter generated
catalog files, deployed pages, account state, game data, or service config.

## Validation

Commands run on the GannanNet VM from `/home/dylan/LAN_Arcade`:

```bash
npm run qa:library-discovery -- --report-dir qa/reports/phase20-doc-regression
npm run qa:static
```
