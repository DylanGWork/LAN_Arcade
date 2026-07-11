# Phase 7 Deployment Profiles Review - 2026-07-11

## Result

PASS. LAN Arcade now uses one codebase with two explicit deployment profiles:

- `full`: home-server library, full local accounts, local mail recommended, hosted services on demand, and the complete library as the first screen.
- `pi`: camping/Raspberry Pi library, guest or local accounts, no mail requirement, hosted services disabled by default, and the Pi-friendly shelf as the first screen.

This is a deployment policy and first-screen selection, not a fork and not a second catalog.

## Implementation

- Added the versioned profile contract in `config/deployment-profiles.json`.
- Added a validating profile compiler in `scripts/build_deployment_profile.mjs`.
- Added `LAN_ARCADE_DEPLOYMENT_PROFILE=full|pi` to safe and full generation.
- Generated public `deployment-profiles.json` and active `deployment-profile.json`.
- Made the public library select the configured default shelf after loading the active profile.
- Made Pi generation skip the optional live Tank service.
- Added contract and browser tests for both modes.
- Documented both modes in `README.md`.

## Review Evidence

| Check | Result |
| --- | --- |
| Deployment profile contract | PASS |
| Pi safe regeneration | PASS |
| Pi browser default is Camping / Pi-friendly | PASS |
| Pi browser external requests | 0 |
| Full safe regeneration | PASS |
| Full browser default is Full library | PASS |
| Full browser external requests | 0 |
| Canonical registry browser smoke | PASS |
| Readiness unit tests | 8/8 PASS |
| Readiness live invariants | PASS |
| Tank service after profile tests | active and enabled |
| Live VM restored to profile | `full` |

Evidence directories:

- `qa/reports/deployment-profile-browser-pi-20260711T065510Z/`
- `qa/reports/deployment-profile-browser-full-20260711T065520Z/`
- `qa/reports/canonical-registry-browser-20260711T065624Z/`

## Safety Review

The mode switch was tested with `LAN_ARCADE_REGISTRY_INDEX_ONLY=1`. That path skips package installation, Apache/admin configuration, mirroring, device changes, and service changes. The test did not stop or reconfigure Tank Arena. The running VM was explicitly regenerated back to `full`.

## Known Boundary

The Pi profile does not shrink or delete the shared catalog. It changes the default player shelf and disables optional live Tank setup when used for installation. Producing a physically smaller export is a later packaging task and should consume this same profile contract rather than create a separate source tree.
