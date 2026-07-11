# Phase 4 Launch Repair Review - 2026-07-11

## Scope

This phase begins the evidence-driven repair queue created by Phase 3. Its completed
recovery slice restores LAN Tank Arena end to end and fixes registry-only generation
so routine readiness rebuilds cannot trigger installer work or an interactive prompt.

It does not claim that every limited title is playable. The readiness authority still
keeps unproven games limited and three known-broken routes quarantined.

## Tank Arena Root Cause

The static game page existed, but the WebSocket backend had no installed systemd unit,
port 8787 was down, and the HTTPS page tried to connect directly to a non-TLS backend
port. A page-load check could therefore pass while multiplayer was impossible.

## Changes

- Installed and enabled a hardened `lan-tank-arena.service` running the tracked Node
  server as the unprivileged `dylan` user.
- Added the same hardening to the generated service unit:
  `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, and
  `ProtectHome=read-only`.
- Changed the browser client to use the same-origin `/tank-arena/ws` route by
  default while retaining the explicit `?port=` development override.
- Added the tracked nginx WebSocket proxy snippet under
  `deploy/nginx/tank-arena-location.conf`.
- Deployed that route to the existing Docker nginx service.
- Changed the unrelated dormant Friendica upstream in the live nginx configuration
  from eager DNS resolution to runtime resolution. Friendica remains stopped; this
  only allows nginx configuration validation and reload while that optional service
  is absent.
- Added a blocked-network, two-client live browser smoke and retained desktop/mobile
  screenshots.
- Added a newer T4 pass receipt. The older outage receipt remains in history and is
  superseded by timestamp rather than deleted.
- Made registry/index-only generation noninteractive and forced the default
  `GannanNet` name unless `ARCADE_NAME` is explicitly supplied.

## Evidence

- `qa/readiness/evidence/tank-arena-live-20260711/tank-live-smoke.json`
- `qa/readiness/evidence/tank-arena-live-20260711/screenshots/alpha.png`
- `qa/readiness/evidence/tank-arena-live-20260711/screenshots/bravo.png`
- Backup: `/home/dylan/backups/lan-arcade/tank-arena-proxy/20260711T045703Z`

The live smoke proves:

- two real Chromium clients joined the same deployed room;
- both clients observed two players;
- movement/rotation and firing changed shared state;
- the proxied health route returned HTTP 200;
- no request left the LAN allowlist;
- no browser page or console error occurred.

## Regression Results

- `npm run qa:tank`: pass.
- `npm run qa:tank:live`: pass.
- `npm run qa:readiness`: 7 unit tests and live invariants pass.
- `npm run qa:readiness:browser`: pass with blocked outbound networking.
- Registry/index-only generation: pass without packages, Apache, mirrors, device
  checks, or service installation.
- Public title: `GannanNet LAN Arcade`.
- Tank health: pass at `https://192.168.1.106/tank-arena/healthz`.
- Readiness changed from 2 ready / 4 quarantined to 3 ready / 3 quarantined.

## Service Footprint

At review time the backend used about 23 MB RAM and no active rooms after the smoke.
The host Apache service remained disabled and inactive. Docker nginx, arcade API, and
mail services remained healthy.

## Remaining Phase 4 Queue

The following are intentionally not promoted:

- DOS Lemmings: browser emulator memory fault.
- Game Boy Aladdin: black output.
- Veloren: no complete client/server playable session.
- SimAnt, Mindustry, Unciv, Endless Sky, and other T2 entries: launch/service evidence
  exists, but no current title-specific T3/T4 gameplay receipt exists.

This is the correct conservative result: repaired routes become Ready; unresolved or
under-tested routes stay Limited or Not ready.
