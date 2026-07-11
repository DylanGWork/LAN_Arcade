# Phase 8 Governance And Release Review - 2026-07-11

## Result

PASS. The platform phase is complete and the live GannanNet deployment remains on
the `full` profile.

## Implemented

- Replaced the public Wiki/admin hybrid with a player-only `Guides & Manuals` page.
- Removed public admin controls, filesystem paths, service health commands, QA commands, and hidden-game state.
- Added responsive player guidance for browser, retro, installable, LAN, tabletop, and account-aware games.
- Added a focused player-guide browser regression with blocked external networking.
- Added `LAN_ARCADE_PAGES_ONLY=1` for safe library/account/guide regeneration without rebuilding catalog inputs or game payloads.
- Added `npm run qa:release` as the combined platform release gate.
- Updated README, VM runbook, roadmap, account architecture, agent rules, and handover authority.
- Recorded main-agent ownership and bounded helper-agent responsibilities.
- Retained Pillage First as a separate product/repository boundary.

## Regression Found And Fixed

The older broad skip-variable regeneration still redeployed local bundles and
rebuilt `catalog.json`. During this phase that changed the catalog source
fingerprint and correctly made two gameplay receipts stale, reducing Ready from
3 to 1.

The preserved catalog was restored, returning all 12 receipts to current and
readiness to 3 Ready / 3 Quarantined. Pages-only mode was then added and proven
to preserve `catalog.json` byte-for-byte while rebuilding public pages. The
runbooks now warn that broad catalog/payload regeneration can invalidate
evidence and requires follow-up gameplay gates.

## Release Gate

`npm run qa:release` passed, including:

| Gate | Result |
| --- | --- |
| Git identity | PASS |
| Tracked secret scan | PASS |
| Full/Pi profile contract | PASS |
| Readiness tests and live invariants | 8/8 PASS |
| Canonical inventory and nested search | PASS |
| Library discovery | PASS |
| Player guides | PASS |
| Public external URL audit | 0 found |
| Blocked public guide links | 0 found |
| Account/save A-B-A isolation | PASS |
| Tank Arena two-client live flow | PASS |
| Tank health endpoint | PASS |
| Credentialed family-account browser flow | PASS |

The deployed profile browser smoke also passed after pages-only regeneration,
with `full` selecting the Full library first screen.

## Backups

- Generated pages before deployment: `/home/dylan/backups/lan-arcade/generated-pages/phase8-predeploy-20260711/`
- Verified online user-data backup: `/home/dylan/backups/lan-arcade/user-data/20260711T075158Z/`

## Live Health

- `lan-tank-arena.service`: active and enabled.
- `lan-arcade-api`: running; health endpoint returns OK.
- nginx `webserver`: running and healthy.
- Root disk: 152 GB used of 295 GB (54%).
- NFS native-download shelf: mounted read/write; 41 GB used of 11 TB.
- Memory: 9.7 GiB total, 6.5 GiB available at final check.

## Residual Limits

- Only three original browser games currently use the synchronized account save adapter.
- EmulatorJS, js-dos, and most native/hosted saves are not account isolated.
- Local-mail password reset and verification are not yet connected to the Arcade API.
- Pillage First is not yet an Arcade-account multiplayer world.
- Most inventory remains Limited because real gameplay evidence has not been collected; the platform no longer disguises that as Ready.
- TravianZ is currently running even though the full-profile policy describes hosted services as on demand. Service orchestration remains a later bounded task.
- A physically smaller Pi export is not yet built; the Pi profile currently selects lightweight behavior from the shared catalog.

## Final Architecture

One platform repository now owns catalog identity, readiness, launch adapters,
accounts, deployment profiles, public UX, and release governance. Complex games
live behind repository/release boundaries. Helper agents may gather media,
intake, or gameplay evidence, but readiness promotion and deployment remain with
the platform orchestrator.
