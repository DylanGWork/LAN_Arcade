# Phase 23 Review: Platform Cleanup, Social API, And Deployment Modes

Date: 2026-06-28

## Scope

Continued the approved platform cleanup phases after the media and gameplay-QA handoff agents were started. This phase focused on safety guardrails, player-facing wording, direct Classic PC search/launch flow, account social primitives, and deployment-mode documentation.

## Completed

- Added Git identity guardrails and `.mailmap` to prevent future contributor-attribution drift from VM default commit metadata.
- Added media/artwork and gameplay-QA handoff workspaces under `agent-handoffs/`.
- Merged 15 high-confidence/no-review artwork candidates into production card previews.
- Reviewed gameplay-QA agent results and kept partial/title-screen results as evidence rather than promotions.
- Reworded public game-library labels away from intake/admin language.
- Rebuilt the Classic PC shelf so known playable games such as SimAnt appear from library search as direct play links.
- Added account-backed friends and local messages to the Arcade API.
- Rebuilt and restarted the `lan-arcade-api` Docker container so the live API now advertises `account-friends` and `account-messages`.
- Added `scripts/backup_arcade_user_data.sh` and `npm run backup:user-data` for account/save DB backup snapshots.
- Validated existing official-site/wiki guide mirrors and repaired the FreeCiv docs mirror to remove a leftover external Twitter widget reference.
- Added deployment-mode documentation for Full GannanNet mode vs Camping/Pi mode.

## Verification

Passed:

- `npm run qa:git-identity`
- `npm run test -w @lan-arcade/arcade-api`
- `npm run qa:library-discovery -- --report-dir qa/reports/phase-platform-cleanup`
- Live `curl http://127.0.0.1/arcade-api/health`
- Live `/arcade-api/server-info` contains `account-friends` and `account-messages`.

Library discovery reports:

- `qa/reports/phase-platform-cleanup/result.md`
- `qa/reports/phase23-final-library-discovery/result.md`
- `qa/reports/phase23-artwork-library-discovery/result.md`

Docs mirror reports:

- `qa/reports/phase23-docs-mirror/`

Backup smoke:

- `/home/dylan/backups/lan-arcade/user-data/20260627T152916Z`

## Review Notes

- The public library is better, but still needs the artwork/media sub-agent output before featured cards stop relying on initials/fallback art.
- The Classic PC shelf now distinguishes playable browser packages from listed entries, but deeper gameplay QA still belongs to the dedicated gameplay-QA agent.
- Account friends/messages are primitives only. Presence, chat UI polish, invitations into specific games, and parental rules remain later work.
- Email-backed account recovery is documented as Full server mode only. Camping/Pi mode should remain usable without Mailu.

## Next Safe Work

- Review the 19 skipped artwork candidates from `agent-handoffs/phase2-media-artwork/`.
- Convert gameplay evidence from `agent-handoffs/phase5-gameplay-qa/` into targeted per-game QA scripts.
- Add a player-facing admin/operator split so QA and intake details stop leaking into public shelves.
- Add account-scoped emulator save sync after launcher limitations are proven per core.
