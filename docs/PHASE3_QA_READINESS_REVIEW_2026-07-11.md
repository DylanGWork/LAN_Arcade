# Phase 3 QA Readiness Review - 2026-07-11

Status: PASS

## Scope

Phase 3 replaces inferred playability with a canonical, evidence-backed readiness authority. It does not repair games; Phase 4 consumes the resulting limited and blocked queues.

## Implemented

- Added T0-T4 evidence tiers and Ready, Limited, Quarantined, Research promotion states.
- Added expiring receipts tied to canonical record/entity identity, exact local target, content type, and registry-source SHA-256.
- Added newer-failure precedence and newer-repair recovery.
- Added atomic generation of readiness.json and qa-quarantine.json.
- Made readiness.json authoritative for public labels, Ready filtering, primary actions, and safe action targets.
- Kept limited entries available as Try without calling them playable.
- Kept collection wrappers as navigation and board intake rows as research.
- Changed quarantine tooling to consume readiness authority rather than generic page smoke results.
- Added an early safe-mode guard so LAN_ARCADE_REGISTRY_INDEX_ONLY=1 cannot install packages, configure Apache, refresh mirrors, or touch services.

## Current Truth

The canonical registry still represents 1,106 distinct titles. The public readiness authority covers 1,318 public entries because it also includes collection memberships and research rows.

- Ready to play: 2
- Needs play testing: 1,099
- Not ready: 4
- Planning/research: 213
- Structured current receipts: 11

Ready:
- Pillage First: offline T3 create-world action.
- SimCity Classic DOS: offline T3 city/zoning/funds action.

Not ready:
- Classic PC Lemmings: browser runtime crash after level start.
- Game Boy Aladdin: black output.
- LAN Tank Arena: static page responds but backend health endpoint is down.
- Veloren LAN: no completed local server/client session.

Lemmings browser, SimAnt, Endless Sky, Mindustry, and Unciv remain Try/Needs play testing because their available evidence is below the required tier.

## Verification

Passed:
- node --test qa/readiness/core.test.mjs: 7/7.
- node qa/readiness/live-invariants.mjs.
- blocked-network browser smoke at the real HTTPS LAN origin.
- canonical registry invariants and byte-reproducibility checks.
- library discovery smoke.
- static mirror audit: 153/153 OK; zero entrypoint external dependency references.
- Git identity check.
- tracked-secret scan.
- Phase 3 path-specific diff check.
- unrelated deployment hash guard for Pillage First and Tank static entrypoints.

Browser evidence:
- qa/reports/phase3-readiness-browser-20260711/
- qa/reports/library-discovery-smoke-20260711T043543Z/

Deployment rollback copy:
- /home/dylan/backups/lan-arcade/phase3-readiness/20260711T043216Z

The generated readiness and quarantine files return HTTP 200 from the Docker nginx route. The Docker webserver, arcade API, and local mail containers remained up. Host Apache is disabled and inactive.

## Deployment Incident

The first registry-only attempt supplied only LAN_ARCADE_REGISTRY_INDEX_ONLY=1. The existing guard was late in the installer, so the script upgraded Debian security packages for Apache, Git, and Node before failing to start Apache because Docker nginx owns ports 80/443.

No arcade generation or game deployment occurred during that failed attempt. Apache was immediately disabled, stopped, and reset to inactive. Docker nginx and the arcade remained healthy. The later safe regeneration completed successfully.

The script now forces all package, Apache/admin, mirror, device, Tank-service, and catalog-refresh skips at startup whenever registry/index-only mode is selected. This makes the short safe command fail-safe instead of relying on callers to remember six environment flags.

## Review Decision

Phase 3 is accepted. Public readiness is intentionally conservative. No admin filters were changed automatically, so blocked entries remain discoverable in Full Library with a clear Not ready label but are excluded from Ready now.

Phase 4 should repair or replace launch routes, run title-specific offline gameplay flows, and add new receipts. It must not promote entries by editing launcher wording.
