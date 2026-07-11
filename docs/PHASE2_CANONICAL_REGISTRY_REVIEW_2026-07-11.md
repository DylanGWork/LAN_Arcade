# Phase 2 Canonical Registry Review - 2026-07-11

## Verdict

PASS for Phase 2. The deployed library now leads with the complete canonical
title inventory instead of presenting 153 navigation cards as the game count.
Confirmed aliases and editions are grouped, uncertain matches stay separate
with review flags, large collections remain nested, and deep search still opens
individual Classic PC and Game Boy launchers.

The full-repository offline-link audit still reports pre-existing external text
inside the deployed Pillage First and Pillage First Inspect mirrors. Those paths
were not changed because they are outside the Phase 2 ownership boundary. The
new registry and library browser flow made no external requests.

## Deployed Inventory

| Metric | Count | Definition |
| --- | ---: | --- |
| Distinct canonical titles | 1,106 | Title entities after confirmed aliases and editions are grouped. Collection wrappers, curated membership rows, and package-evidence rows are excluded. Review-flagged pairs remain separate, so this is not labelled unique. |
| Top-level launcher cards | 153 | Navigation cards in `catalog.json`, including collection wrappers. This is a secondary navigation metric, not the complete inventory. |
| Playable-now titles | 790 | Canonical title entities with at least one direct local launcher that is not blocked. Package-only native hubs do not qualify. |
| Locally packaged titles | 879 | Canonical title entities with an observed ROM, Classic PC bundle/package, or native package-shelf payload. This does not imply playable-now status. |
| Local package records | 882 | Package-bearing source/evidence records before canonical edition grouping. |
| Installed native title package sets | 91 | Canonical titles for which all manifest-declared native seed packages are currently installed on GannanNet. This live VM state may change. |
| QA-verified titles | 12 | Titles with a structured gameplay/service smoke state, a board `playable-local` state, or the reviewed Lemmings browser-adapter smoke override. Inferred readiness is excluded. |
| Collection/research rows | 207 | Seven collection-wrapper launcher records plus 200 board-game research rows. This is a row count, not a game count. |
| Curated Game Boy memberships | 201 | Curated rows linked to existing vault entities by source ID and SHA-256. They create no additional titles. |
| Resolved duplicate title records | 11 | Raw title rows absorbed by confirmed canonical groups. |
| Unresolved possible duplicates | 5 | Possible duplicate/edition pairs deliberately kept separate pending review. |
| Manual-review relationships | 6 | The five possible-duplicate pairs plus the separate Catan/Pioneers analog relationship. |
| Canonical collection wrappers | 7 | Launcher cards explicitly modelled as collections or research shelves, not games. |
| Total source records | 1,449 | Launcher, title, research, curated-membership, and package-evidence records represented by the registry. |

The playable-now total is composed of 740 canonical Game Boy titles, 14
non-blocked packaged Classic PC titles, and 36 ready top-level title entities.
The local-package total is composed of 740 canonical Game Boy titles, 15
Classic PC package records, and 124 native package-shelf title entities.

## Count Derivation

The canonical title calculation starts with title-bearing rows only:

```text
146 top-level title cards (153 cards minus 7 collection wrappers)
743 Game Boy / Game Boy Color vault records
200 board-game rows
 28 Classic PC rows
---
1,117 raw title-bearing rows
- 11 records absorbed by confirmed groups
---
1,106 canonical title entities
```

The 201-title curated Game Boy collection is not added to this calculation. All
201 source IDs and SHA-256 values match records in the 743-record vault, so the
registry emits `collection-membership` records attached to those vault entities.

The 11 confirmed reductions are:

- Seven board rows linked by their structured manifest URLs to Kigo/GNU Go,
  GNU Backgammon, KReversi, KFourInLine, KNavalBattle, Nine Men's Morris, and
  Bovo Gomoku.
- Three same-title Game Boy/Game Boy Color edition pairs: Pocket Bomberman,
  Space Invaders, and Wario Land II.
- The top-level browser-native Lemmings adapter and the Classic PC Lemmings row,
  which represent editions using the same locally cached game data.

Five same-title cross-collection pairs remain separate and flagged:

- Board Backgammon versus the Game Boy Color adaptation.
- Board UNO versus the Game Boy Color adaptation.
- Grand Theft Auto on Game Boy Color versus the Classic PC candidate.
- Prince of Persia on Game Boy Color versus the Classic PC package.
- Road Rash on Game Boy Color versus the Classic PC candidate.

Catan and Pioneers also remain separate. Their relationship is explicitly an
analog implementation, not a duplicate merge.

## Registry Contract

The deployed `canonical-registry.json` contains:

- Stable `entityId` values for canonical titles and separate collection wrappers.
- Stable `recordId` values for launcher cards, title rows, research rows,
  curated memberships, and native package evidence.
- Platforms, source collection memberships, launcher targets, aliases/edition
  relationships, readiness dimensions, evidence dimensions, and review flags.
- Machine-readable definitions for every metric and readiness/evidence field.
- Content hashes for each source collection and a combined input digest.
- Only local `/mirrors/` launcher targets. External URLs and operator filesystem
  paths are rejected before the public JSON can be written.

Generation is deterministic for fixed inputs and a fixed `--generated-at`
value. `SOURCE_DATE_EPOCH` is also supported. The normal deployment records the
actual generation time and current dpkg installation state.

## Public Library

The public status row now begins with:

```text
1106 titles across every shelf
153 launch cards
790 ready to play
```

The former shelf-by-shelf status chips were removed because adding 743 vault
records, 201 curated memberships, 200 board rows, and 28 Classic PC rows would
misrepresent overlapping collections. Shelf links still show their own scoped
membership/listing counts. Game Boy, Classic PC, and board collections remain
nested, while the existing deep-search manifests remain unchanged.

## Safe Deployment

The setup script now supports a narrowly scoped regeneration mode. It exits
before shared-asset or bundled-game deployment, catalog generation, account,
wiki, admin, downloads, sanitization, or service setup:

```sh
ARCADE_NAME=GannanNet \
LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 \
LAN_ARCADE_SKIP_ADMIN_AUTH=1 \
LAN_ARCADE_SKIP_MIRROR=1 \
LAN_ARCADE_CATALOG_SOURCE=metadata-existing \
LAN_ARCADE_SKIP_DEVICE_CHECKS=1 \
LAN_ARCADE_SKIP_OFFLINE_PATCH=1 \
LAN_ARCADE_SKIP_TANK_SERVICE=1 \
LAN_ARCADE_REGISTRY_INDEX_ONLY=1 \
bash ./setup_lan_arcade.sh
```

Before/after SHA-256 checks confirmed that catalog, launcher adapters, filters,
wiki, account, admin, and downloads pages were unchanged. Only the two approved
deployed files were regenerated.

Deployed SHA-256 values from the Phase 2 run:

```text
c66d0d144b23f27516a4572de106d6c526beaee11b06855d549f52c73259709e  canonical-registry.json
1eb2df03efa5406e224cfd6a6ba94a68f49aa435da5c6a06654a4453e7b4e550  index.html
```

## Verification

- `python3 qa/canonical-registry-invariants.py`: PASS. It generated the registry
  twice with a fixed timestamp and no live dpkg query, compared bytes, checked
  exact source/metric counts, verified all 201 curated overlaps, checked every
  confirmed merge, and confirmed all review relationships remain separate.
- `bash -n setup_lan_arcade.sh`: PASS.
- `node --check qa/canonical-registry-ui-smoke.mjs`: PASS.
- `npm run qa:static`: PASS, 153 scanned, 153 OK, zero entrypoint external refs.
- LAN-origin Chromium smoke: PASS, 22/22 checks, no page errors, no failed local
  responses, and no external requests. Report:
  `qa/reports/canonical-registry-phase2-20260711/`.
- SimAnt search: PASS. Direct launcher opened
  `/mirrors/private-dos-vault/play.html?id=simant-ma` with HTTP 200.
- Game Boy search: PASS. Adventures of Lolo appeared once and opened
  `/mirrors/private-rom-vault/play.html?id=adventures-of-lolo` with HTTP 200.
- Library and registry HTTP checks: PASS, both HTTP 200.
- `npm run qa:offline-links`: FAIL on pre-existing Pillage First/Pillage First
  Inspect external text. The Phase 2 browser smoke observed zero external
  requests, and registry generation rejects external URLs.

## Deployed URLs

- Library: `http://192.168.1.106/mirrors/games/`
- Canonical registry: `http://192.168.1.106/mirrors/games/canonical-registry.json`
- SimAnt direct result: `http://192.168.1.106/mirrors/private-dos-vault/play.html?id=simant-ma`
- Game Boy direct result: `http://192.168.1.106/mirrors/private-rom-vault/play.html?id=adventures-of-lolo`

## Residual Risks

- Five possible duplicate/edition relationships still need manual identity
  confirmation; they are intentionally counted separately today.
- The public registry is 3,128,641 bytes. It loaded successfully in the real LAN
  Chromium smoke, but a future compact summary endpoint could reduce cold-load
  cost on very low-powered clients.
- `locallyInstalledNativeTitles` is a current VM observation, not a portable or
  client-install count. Twenty-four native manifests have no seed-package list
  and therefore cannot qualify through this dimension.
- QA verification is conservative evidence classification, not a claim that all
  740 canonical Game Boy titles have received individual gameplay playthroughs.
- The full offline-link audit remains blocked by unrelated Pillage First mirror
  content and should be repaired in that component's own scope.
