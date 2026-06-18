# Pillage First Fork Review - 2026-06-18

Context: after fixing the LAN mirror to include the official upstream graphics pack, the village/resource screens still looked very plain. Dylan asked whether forks of the open-source Pillage First project contain useful upgrades we could safely add to the LAN Arcade mirror.

Reviewed sources:

- Upstream: https://github.com/jurerotar/Pillage-First-Ask-Questions-Later
- Fork network: https://github.com/jurerotar/Pillage-First-Ask-Questions-Later/forks
- Open PR queue: https://github.com/jurerotar/Pillage-First-Ask-Questions-Later/pulls
- Visual fork: https://github.com/sauhumatti/Pillage-First-Ask-Questions-Later

## Summary Decision

Do not merge any fork or open PR directly into the live `/mirrors/pillage-first/` build yet.

The best short-term candidate is `sauhumatti/Pillage-First-Ask-Questions-Later`, which adds village building graphics and visual treatment. It is worth testing as an optional experimental LAN skin, but not as the default live build until asset provenance is clearer and the fork delta is isolated against current upstream.

The strongest gameplay candidates are upstream PRs for combat reports and resource transfers. They are interesting, but they touch persistence, event resolution, and core game state, so they should be tested in disposable preview builds only. Wait for upstream merge where possible.

## Candidate Matrix

| Candidate | What it adds | Value | Risk | Recommendation |
| --- | --- | --- | --- | --- |
| `sauhumatti` fork | Village building graphics, background treatment, building badge placement, CSS fixes for building images | High visual value. Addresses Dylan's main complaint that the village view looks unfinished. | Medium. Assets are AI-generated according to commit messages, and no separate asset provenance/license note was found beyond repo AGPL. Fork is also behind current upstream. | Make a separate experimental build/skin first, with attribution and screenshots. Do not replace live default yet. |
| PR #208 demolition timer | Adds demolition/downgrade timer in left sidebar | Small but sensible UX improvement. | Low to medium. Small UI surface, Netlify preview reportedly ready, but still unmerged. | Good first upstream PR candidate after a throwaway build test. |
| PR #201 cavalry icons | Visual unit icon improvement | Likely useful polish. | Unknown until branch/file review. | Inspect next. If asset provenance is clean and code surface is small, it may be safe. |
| PR #140 wiki pages | Adds in-game/wiki pages | High value for our offline arcade manual goal. | Medium. Older branch; may be divergent. | Prefer upstream merge, or scrape/rewrite the docs into our LAN page rather than merging app routes. |
| PR #205 combat reports | Real attack/raid resolution, loot handling, report DB/API/UI | Very high gameplay value. Makes Pillage First feel more like a real Travian-style loop. | High. Touches combat, DB schema, events, troop movement, reports, and resource mutation. Needs real dogfooding. | Test in isolated preview only. Do not live-merge until upstream stabilizes or we build a full regression path. |
| PR #219 resource transfers/merchants | Send resources between villages, merchant overview/table | High midgame value. | High. Large stateful change; GitHub preview showed failed deploy at time of review. | Watch upstream. Only test on disposable branch. |
| PR #185 scheduled construction | More construction scheduling | High convenience value. | Unknown to high. Likely core scheduler/state changes. | Inspect after simpler PRs. |
| PR #166 battle simulator | Battle simulator | Potentially useful. | Very high. Branch appeared heavily divergent from current upstream in local clone comparison. | Idea source only. Do not merge as-is. |
| `MarkBlatnik` fork | Early resource-view graphics and selector ideas | Useful idea history. | High. Uses older app paths and is far behind current upstream. | Do not merge. Mine only for design ideas if needed. |
| `Na9rawy9` fork | Generic PWA/deploy changes | Low for our LAN setup. | Low value; may duplicate our wrapper/mirror handling. | Skip. |

## Details

### Visual Fork: `sauhumatti`

GitHub compare showed 9 commits and 74 files changed. The visible commit subjects include:

- `feat: add AI-generated building graphics for all 33 village buildings`
- `fix: persist custom building graphics through inject-graphics wipe`
- `fix: apply building graphics CSS class to village buildings (IDs 19+)`
- `feat: add village background + move level badge to bottom-right`
- follow-up transparency/background fixes, including a switch from AVIF to PNG for alpha preservation.

Local clone inspection found these relevant asset areas:

- `custom-graphics/backgrounds/`
- `apps/web/public/graphic-packs/default/buildings/village/`

The fork appears to solve exactly the thing Dylan noticed: the current upstream village view is functionally playable but visually sparse. However, the commit messages say the building graphics were generated with Gemini. The fork inherits AGPL project licensing, but there is no separate asset provenance note explaining whether those generated images are intended for redistribution as game assets. For our LAN mirror, that makes the safe path an opt-in experimental skin with attribution, not a silent default replacement.

### Open Upstream PRs

The upstream project currently shows 8 open pull requests. The important ones for us are:

- #208: demolition timer. Smallest candidate to test first.
- #205: combat reports. Very valuable but stateful and risky.
- #219: resource transfer and merchant overview. Valuable but large and preview deploy was failing during review.
- #140: wiki pages. Good fit for our offline documentation goal, but probably better mirrored/rewritten into LAN Arcade docs if the branch is old.

PR #205's own summary says it wires combat into attack/raid movement resolution, implements loot, adds reports schema/endpoints/UI, and enables attack/raid UI. That is exactly the kind of feature that can make the game more compelling, but it also means we need game-world creation, attack/raid, timer completion, report viewing, loot accounting, and reload/offline persistence tests before it is trusted.

PR #219 adds the ability to send resources between villages and merchant UI. Because it affects resources, events, and scheduling, it should be treated with the same caution as combat reports.

## Recommended Next Safe Action

Create a separate Pillage First experimental graphics branch/build, for example `/mirrors/pillage-first-experimental/`, using only the visual skin pieces from `sauhumatti`.

Acceptance checks before promoting it:

1. Build from source on the VM with our existing mirror script approach.
2. Keep `/mirrors/pillage-first/` unchanged while testing.
3. Verify game-world creation, resources, village, map, building upgrade, queue timer, reload, offline mode, and source-map absence.
4. Capture screenshots for desktop and mobile widths.
5. Record attribution and asset provenance in the local page/manual.
6. If the graphics are clearly better and tests pass, decide whether to expose it as a separate launch card or make it the default.

After that, test PR #208 as the first code-behavior PR. Leave #205 and #219 for later isolated dogfooding because they change the actual game economy/combat loop.
