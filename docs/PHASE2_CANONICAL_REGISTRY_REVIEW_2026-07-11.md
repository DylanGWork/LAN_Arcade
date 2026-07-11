# Phase 2 Canonical Registry Review - 2026-07-11

## Verdict

PASS after semantic correction. The library now leads with the complete
canonical inventory instead of presenting 153 navigation cards as the game
count. Confirmed aliases and editions are grouped, uncertain matches remain
separate with review flags, and nested collections still open individual
launchers.

Phase 2 does not decide whether a game works. It records inventory, local files,
and possible launch paths. Phase 3 owns readiness and quarantine decisions.

## Deployed Inventory

| Metric | Count | Meaning |
| --- | ---: | --- |
| Canonical titles | 1,106 | Title entities after confirmed aliases and editions are grouped. Collection wrappers and curated-membership rows are excluded. |
| Titles with local files | 879 | At least one ROM, Classic PC bundle, or native package payload is present locally. File presence is not proof of play. |
| Local launch candidates | 790 | At least one local target exists for a launch attempt. This is not a ready-to-play count. |
| Top-level library cards | 153 | Home-screen cards, including collection wrappers. This is navigation, not total inventory. |
| Recorded checks | 12 | Any structured check is present, including mixed launch/service tiers. This is not gameplay verification. |
| Recorded meaningful actions | 2 | Existing source evidence explicitly records an in-game action: Pillage First world creation and SimCity zoning/funds change. Phase 3 will validate evidence authority. |
| Installed native package sets | 91 | All declared seed packages are installed on this VM. This is VM state, not client compatibility. |
| Collection/research rows | 207 | Seven collection wrappers plus 200 board-game research rows. |
| Curated Game Boy memberships | 201 | Curated rows linked to records in the 743-title vault; they add no titles. |
| Resolved duplicate records | 11 | Source title rows absorbed by confirmed canonical groups. |
| Possible duplicates awaiting review | 5 | Similar cross-platform records deliberately kept separate. |
| Total represented source records | 1,449 | Launcher, title, research, membership, and package-evidence records. |

## Count Derivation

    146 top-level title cards (153 cards minus 7 collection wrappers)
    743 Game Boy / Game Boy Color vault records
    200 board-game rows
     28 Classic PC rows
    ---
    1,117 raw title-bearing rows
    - 11 records absorbed by confirmed groups
    ---
    1,106 canonical title entities

The 201 curated Game Boy rows match vault source IDs and SHA-256 values, so they
are memberships rather than an additional 201 games.

Confirmed grouping covers seven board rows linked to local implementations,
three same-title GB/GBC edition pairs, and the browser/Classic PC Lemmings
editions. Five cross-collection pairs remain separate pending manual identity
review. Catan and Pioneers remain an analog relationship, not a duplicate.

## Registry Contract

The deployed canonical-registry.json contains stable entity and record IDs,
platforms, collection memberships, launcher targets, confirmed relationships,
review flags, source hashes, and explicit inventory dimensions.

It deliberately contains no playableNow, readyNow, or qaVerified keys. Instead:

- localPayload means local files were observed;
- localLaunchCandidate means a local launch can be attempted;
- checksRecorded means some check exists, regardless of tier; and
- meaningfulActionEvidence records a claimed game action for Phase 3 review.

External URLs and operator filesystem paths are rejected from the public
registry. Fixed inputs and timestamps produce byte-identical output.

## Public Library

The status row now begins with:

    1106 titles across every shelf
    879 with local files
    790 launch paths to try
    2 with recorded game actions
    153 library cards

It makes no aggregate ready-to-play claim. Large collections remain nested and
deep search still opens individual Classic PC and Game Boy entries.

## Safe Deployment

LAN_ARCADE_REGISTRY_INDEX_ONLY=1 regenerates only the registry and public
library index. Hash guards confirmed catalog, launcher adapters, filters, wiki,
account, admin, downloads, and game payloads were unchanged.

## Verification

- Canonical invariants and fixed-input byte reproducibility: PASS.
- Legacy readiness-key rejection: PASS.
- Lemmings canvas-start evidence is not a meaningful action: PASS.
- LAN Chromium UI smoke: PASS, including status wording and no external requests.
- SimAnt nested search/direct target: PASS. This is a launch-route test, not a
  gameplay test.
- Adventures of Lolo nested search/direct target: PASS.
- Static audit: 153/153 entries OK with zero entrypoint external references.
- Secret and Git identity checks: PASS.
- Full offline-link audit: still fails on pre-existing Pillage First inspection
  content outside this phase; Phase 4 owns that remediation.

Evidence: qa/reports/canonical-registry-phase2-20260711/.

## Residual Risks

- The public registry is roughly 3 MB; a compact summary may help low-power
  clients later.
- Five possible duplicate relationships require manual confirmation.
- Local package and installed-package counts do not imply architecture,
  operating-system, controller, or gameplay compatibility.
- Most titles do not yet have accepted meaningful-action evidence.
- Phase 3 must consume current evidence and quarantine failures before the
  player UI may use words such as Ready or Playable.
