# QA Readiness Contract

The public library must never infer playability from a 200 response, a canvas, a package file, launcher wording, or an old smoke report.

## Evidence tiers

- T0 Inventory: identity, metadata, or local-file observation.
- T1 Surface: page, service, canvas, or package surface responds.
- T2 Launch and input: target launches and accepts relevant player input.
- T3 Meaningful single-player action: a title-specific action changes game state.
- T4 End-to-end persistence or multiplayer: save/reload restores state, or real clients complete a multiplayer flow.

A single-player title is Ready only with a current offline T3 pass. Hosted and multiplayer titles require a current offline T4 pass. Collections are navigation, and research rows are never playable titles.

## Receipt requirements

Every receipt identifies the canonical entry, exact target, content type, registry-source SHA-256 fingerprint, runner, environment, tier, outcome, assertions, observation time, expiry, and repository evidence paths.

Receipts are rejected when their target, record identity, entity identity, content type, or source fingerprint no longer matches the current canonical registry. Receipts must expire. A current failure or blocker at least as new as the newest qualifying pass quarantines the entry. A newer qualifying pass can clear an older failure.

## Public states

- Ready to play: current offline evidence meets the required tier.
- Needs play testing: a launch route exists, but evidence is missing, stale, partial, or below the required tier.
- Not ready: a current failure or blocker is recorded.
- Planning only: research or intake data, not a playable game.
- Open collection: navigation wrapper, not a game.

Users may still choose Try for limited entries. The label is deliberately honest: Try is not a QA pass.

## Promotion workflow

1. Run a title-specific blocked-network test.
2. Capture screenshots, logs, assertions, and the meaningful state transition.
3. Add or replace the receipt in qa/readiness/evidence.json.
4. Run npm run qa:readiness.
5. Review readiness.json and qa-quarantine.json.
6. Deploy the registry/index-only path and run the blocked-network browser smoke.
7. Commit evidence and reports together.

Do not manually set Ready in launcher metadata.
