# Platform Phases 1-3 Review - 2026-06-22

Scope: safe VM deployment slice for the LAN Arcade platform-library audit. This did not implement account/login/save isolation, email workflows, hosted-service orchestration changes, or game mechanic changes.

## Phase 1 - Library Information Architecture

Implemented:

- Renamed the sidebar from static catalogue language to player-facing play modes.
- Added play-mode filters: Full library, Ready now, Guest quick-play, Camping / Pi-friendly, LAN multiplayer, Emulation shelves, Native / services, and Research / QA.
- Renamed shelves to Collections & Shelves and added quick filters for ready, guest, LAN, native/service, board-game, and research entries.
- Updated the main heading copy so the page answers what can be played by device, people, platform shelf, or hosted LAN service.

Review result:

- Live page checked at `http://127.0.0.1/mirrors/games/`.
- Browser review found the new Play Modes and Collections & Shelves navigation.
- Rendered 152 top-level cards.
- No browser page errors were observed.
- Screenshot and JSON review: `qa/reports/platform-phases/phase-1-ia-20260622/`.

Notes:

- This is a front-door/navigation improvement only. It does not prove individual game loops beyond the existing QA gates.

## Phase 2 - Action And Readiness Semantics

Implemented:

- Added card-level classification for Collection, LAN service, Native hub, Emulator, Board game, Phone friendly, and Browser ready.
- Added readiness/device/player/age chips to each card.
- Replaced the blunt Play/Open hub split with contextual actions: Play, Open shelf, Start / join, Install / play, and Review.
- Adjusted recommendation scoring so ready entries and collections rise while research/blocked entries drop.
- Fixed the old native/server classifier so multiplayer alone no longer forces a game into the native/server bucket.

Review result:

- Live page checked at `http://127.0.0.1/mirrors/games/`.
- Rendered 152 cards and 620 detail chips.
- Found 6 collection badges, 20 LAN service badges, and 107 native hub badges.
- Found 5 Open shelf actions, 18 Start / join actions, 104 Install / play actions, 6 Review actions, and Play actions for low-friction games.
- No browser page errors were observed.
- Screenshot and JSON review: `qa/reports/platform-phases/phase-2-actions-20260622/`.

Notes:

- Some classification is necessarily metadata-derived. The Phase 3 audit now makes those assumptions visible so they can be corrected as metadata improves.

## Phase 3 - Platform QA Guardrail

Implemented:

- Added `scripts/library_platform_audit.py`.
- Added npm command `qa:library-platform`.
- The audit checks top-level catalogue content types, readiness states, primary actions, missing local launch targets, external launch targets, thin metadata, and missing age tags.

Review result:

- Command run: `npm run qa:library-platform -- --output-dir qa/reports/platform-phases/phase-3-library-audit-20260622`.
- Top-level cards: 152.
- Missing local launch targets: 0.
- External launch targets: 0.
- Missing age metadata: 0.
- Thin metadata entries: 10.
- Report: `qa/reports/platform-phases/phase-3-library-audit-20260622/REPORT.md`.

Platform audit counts:

- Content types: 9 browser games, 6 collections, 13 emulator entries, 18 LAN services, 106 native hubs.
- Readiness: 22 ready offline, 5 shelf ready, 16 start on demand, 103 client install, 5 needs QA, 1 restore needed.
- Actions: 22 play, 5 open shelf, 16 start/join, 103 install/play, 6 review.

Existing regression gates:

- `npm run qa:library-platform -- --strict --output-dir qa/reports/platform-phases/phase-3-library-audit-strict-20260622`: pass. Missing local launch targets: 0; external launch targets: 0.
- `npm run qa:static`: pass. 152 scanned, 152 OK, 0 external dependency refs in entry HTML.
- `npm run qa:smoke -- --base-url http://127.0.0.1/mirrors/games/ --limit 5 --report-dir qa/reports/platform-phases/phase-3-smoke-sample-20260622`: pass. 5/5 strict passed and 5/5 playable.

Notes:

- The safe regeneration command produced recurring `_offline_assets` permission/fallback warnings during local deploy patching. These are existing deploy warnings and did not produce static audit failures.

## Remaining Work

- Thin metadata cleanup for: foobillardplus-lan, geki2-lan, geki3-lan, kraptor-lan, lierolibre-lan, morris-lan, numptyphysics-lan, open-invaders-lan, pink-pony-lan, tuxpuck-lan.
- Account/login/save isolation is still planning-only and should be implemented as a separate backend phase using `docs/GAME_LIBRARY_ACCOUNT_ARCHITECTURE.md` and the local mailserver docs.
- Hosted-service start/stop orchestration still needs a separate admin/API phase.
- The library platform audit is not a replacement for full game dogfooding; it is a front-door guardrail before deeper per-game smoke tests.
