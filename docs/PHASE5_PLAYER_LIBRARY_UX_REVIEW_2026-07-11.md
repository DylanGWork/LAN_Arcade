# Phase 5 Player Library UX Review - 2026-07-11

## Result

PASS for the player library surface.

The library no longer presents the 153 top-level navigation cards as the size of
the game collection. It distinguishes title inventory, collection wrappers, local
payloads, launch candidates, evidence-backed Ready entries, and visible cards.

## Changes

- The leading metric is now `1,106 game titles across every shelf`.
- The seven collection wrappers are shown as `7 collections`.
- `153 library cards` remains visible only as a secondary navigation metric.
- Ready totals come only from the readiness authority; the current total is three.
- Limited launcher actions are adapter-aware:
  - browser and emulator routes: `Try`;
  - desktop and package routes: `Install`;
  - hosted LAN routes: `Start / join`.
- The player sidebar no longer links to `Operator Tools`.
- Mailbox alias wording now says `family organizer`, not `family/admin`.
- Recent and saved-game shelves remain capped at four cards.
- Compact shelves hide long description/tag/detail blocks and constrain media to the
  card width.

## Verification

- Readiness unit suite: 8/8 pass, including adapter-specific action labels.
- Readiness live invariants: pass.
- Blocked-network readiness browser smoke: pass.
- Canonical registry browser smoke: pass.
- Library discovery/recent/favorites smoke: pass.
- Explicit assertions confirm:
  - 1,106 title count;
  - seven collection count;
  - 153 cards are secondary;
  - SimAnt uses `Try`;
  - Atlantik uses `Install`;
  - Tank uses `Start / join`;
  - recent media does not overflow;
  - no `Operator Tools` or `family/admin` wording appears in the player library.

## Boundaries

The generated Guides & Manuals page still contains legacy operator instructions and
technical file descriptions. It is not linked as operator tooling from the player
library, but Phase 8 must split player guides from operator documentation rather than
pretending that cleanup is complete.

The registry still records five unresolved possible duplicate relationships. For that
reason the UI says `game titles`, not `unique games`.
