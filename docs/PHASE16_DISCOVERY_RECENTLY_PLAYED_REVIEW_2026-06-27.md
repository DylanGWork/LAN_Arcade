# Phase 16 Discovery And Recently Played Review - 2026-06-27

## Scope

Verified the deployed game-library discovery flow after Phase 15 regeneration, focusing on the reported `SimAnt` search issue and the recently played shelf.

## Findings

- Searching `simant` on `/mirrors/games/` now returns a direct `SimAnt` card.
- The direct card launches `/mirrors/private-dos-vault/play.html?id=simant-ma`.
- The main library also still shows the relevant parent shelves (`Classic PC Games`, `Emulator Library`) in search results.
- Clicking the `SimAnt` card records it in `lanArcadeRecentlyPlayed.v1`.
- Returning to `/mirrors/games/` displays the `Recently played` shelf with `SimAnt`.

## Checks

Playwright against the deployed VM page:

- Loaded `http://127.0.0.1/mirrors/games/`.
- Entered `simant` into `#searchInput`.
- Verified visible titles included `SimAnt`.
- Clicked the `SimAnt` card.
- Returned to `/mirrors/games/`.
- Verified `#recentShelf` was visible and contained `SimAnt`.
- Verified no page errors were emitted during the test.

## Decision

No Phase 16 code change was required. The likely user-facing issue was stale deployed/generated content or browser cache before the current regeneration.

## Remaining Risk

The recently played shelf is browser-local for guests. Signed-in recent activity is supported separately by the account API, but cross-device recent-play visibility still depends on users signing in.
