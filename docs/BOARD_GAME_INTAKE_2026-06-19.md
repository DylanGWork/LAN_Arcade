# Board Game Intake - 2026-06-19

This pass added the first dedicated multiplayer-board-game shelf to LAN Arcade.
The rule for this batch was stricter than a launcher/page check: a game can be
called playable only when the VM reached a meaningful board state with outbound
networking disabled. Hubs can still pass browser-page QA while the native game is
marked partial or blocked.

## Scope

- Source metadata: `scripts/native_board_game_data.py`
- Hub generator: `scripts/generate_native_board_game_hubs.py`
- Package/docs cache: `scripts/cache_native_board_game_assets.py`
- Native smoke scripts:
  - `scripts/native_board_game_play_smoke.sh`
  - `scripts/native_board_game_expanded_smoke.sh`
- Deployed hub paths: `/var/www/html/mirrors/<game-id>/`
- NFS-backed package shelf: `/var/www/html/mirrors/games/downloads/native/<slug>/`

## Result Summary

| Game | Native Status | Evidence | Notes |
| --- | --- | --- | --- |
| `pioneers-lan` | PASS | `qa/reports/native-board-game-play/pioneers-lan-20260618T194900Z` | Local Pioneers server, three AI players, GUI client joined and board/AI activity captured. |
| `teg-lan` | PASS | `qa/reports/native-board-game-play/teg-lan-20260618T194900Z` | `tegserver` with metaserver disabled, bots joined, GUI reached map/player state. |
| `ksirk-lan` | PASS | `qa/reports/native-board-game-play/ksirk-lan-20260618T194900Z` | Local KsirK game reached board/army-placement state. |
| `atlantik-lan` | PARTIAL | `qa/reports/native-board-game-play/atlantik-lan-20260618T194900Z` | Local `monopd` lobby works; full board start needs two clients. |
| `triplea-lan` | BLOCKED | `qa/reports/native-board-game-play/triplea-lan-20260618T194900Z` | Launch path still attempts GitHub/update/map checks before playable local-map proof. |
| `biloba-lan` | PASS | `qa/reports/native-board-game-expanded/biloba-lan-20260618T195446Z` | Board with pieces and active turn captured. |
| `ricochet-lan` | PASS | `qa/reports/native-board-game-expanded/ricochet-lan-20260618T195446Z` | Local `rrserve` plus client reached active puzzle board. |
| `bovo-lan` | PASS | `qa/reports/native-board-game-expanded/bovo-lan-20260618T195446Z` | Gomoku board accepted moves; X/O stones captured. |
| `kfourinline-lan` | PASS | `qa/reports/native-board-game-expanded/kfourinline-lan-20260618T195446Z` | Connect Four game started and accepted a piece drop. |
| `kreversi-lan` | PASS | `qa/reports/native-board-game-expanded/kreversi-lan-20260618T195446Z` | Reversi board, score, and turn text captured. |
| `kigo-lan` | PASS | `qa/reports/native-board-game-expanded/kigo-lan-20260618T195446Z` | Kigo with local GNU Go engine reply and move list captured. |
| `pentobi-lan` | PASS | `qa/reports/native-board-game-expanded/pentobi-lan-20260618T195446Z` | Pentobi board/pieces captured after play input. |
| `gnubg-lan` | PASS | `qa/reports/native-board-game-expanded/gnubg-lan-20260618T195446Z` | GNU Backgammon GUI reached board/match state. |
| `knavalbattle-lan` | PARTIAL | `qa/reports/native-board-game-expanded/knavalbattle-lan-20260618T195446Z` | Single-player setup and first ship placement work; firing turn still needs proof. |
| `xfrisk-lan` | PARTIAL | `qa/reports/native-board-game-expanded/xfrisk-lan-20260618T195446Z` | Server/client/AIs and setup map captured; first turn still needs proof. |

## Browser Hub QA

Each board-game hub passed focused desktop and mobile browser-page regression
after the hubs were generated and deployed. Latest focused reports are under:

```text
qa/reports/game-regression/*-20260618T1946*Z-desktop
qa/reports/game-regression/*-20260618T1946*Z-mobile
```

The page smoke proves the hub, downloads, manual links, and mobile layout. It
does not replace the native no-internet gameplay smoke above.

## Offline Catalog Audit

After mirror repair, `npm run qa:patch-mirrors`, fixing the EmulatorJS runtime
directory permissions, and quarantining the known browser blockers, the latest
LAN-origin audit was:

```text
qa/reports/offline-catalog-audit-20260618T202234Z-lan-after-runtime
```

Summary from that report:

- Catalog entries discovered: 124
- Strict passed: 101/124
- Warnings: 20
- Blockers: 3
- Hidden by admin filters: 3
- Hidden blockers: `farm-clicker`, `koutoftimer-idle-miner`, `solaris`

All 15 board-game hubs were in the `keep` bucket for browser-page/offline hub
checks. Do not read that as native gameplay proof for `triplea-lan`,
`atlantik-lan`, `knavalbattle-lan`, or `xfrisk-lan`; their native status is the
table above.

## Deployment Notes

- The board-game hubs are small `LOCAL_DIR` pages in Git. Their packages and
  mirrored docs remain on the NFS-backed native shelf outside Git.
- `supertasball` remains skipped because its mirror did not produce a usable
  entrypoint.
- The EmulatorJS runtime exists outside Git at
  `/var/www/html/mirrors/emulatorjs-runtime/4.2.3/`. Its nested `data/`
  directory was repaired to browser-readable permissions after the audit caught
  LAN-origin runtime 404s.
- The webserver container serves `/mirrors/` from the host bind mount at
  `/var/www/html/mirrors` into container path `/mirrors`.

## Status Definitions

- PASS: no-internet namespace, game reached meaningful board/gameplay state, and
  screenshot/log evidence exists.
- PARTIAL: offline launch/server path works, but the smoke stopped before real
  gameplay because another client, turn, or step is still required.
- BLOCKED: launch path depends on external network or otherwise fails before a
  playable state.

## Follow-Ups

1. Patch/configure TripleA so local maps work with update/map checks disabled,
   then make a first-turn smoke.
2. Add two-client smokes for Atlantik and real-LAN table smokes for Pioneers,
   TEG, Ricochet, KNavalBattle, and XFrisk.
3. Continue repairing the 20 warning entries from the latest LAN-origin catalog
   audit.
4. Continue keeping older browser-game warning buckets separate from board-game
   native playability so a clean hub never implies unproven native gameplay.
