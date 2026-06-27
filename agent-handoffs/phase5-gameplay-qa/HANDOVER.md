# Phase 5 Gameplay QA Agent Handover

## Start Here
You are working on Dylan's LAN Arcade project on the GannanNet VM.

VM:
- SSH: dylan@192.168.1.106
- Repo: /home/dylan/LAN_Arcade
- Public arcade: http://192.168.1.106/mirrors/games/

Workspace for this task:
- /home/dylan/LAN_Arcade/agent-handoffs/phase5-gameplay-qa

Read before working:
- /home/dylan/LAN_Arcade/AGENTS.md
- /home/dylan/LAN_Arcade/docs/AGENT_HANDOVER.md
- /home/dylan/LAN_Arcade/docs/VM_DEVELOPMENT_AND_QA.md
- /home/dylan/LAN_Arcade/agent-handoffs/phase5-gameplay-qa/HANDOVER.md

## Mission
Perform real gameplay QA for LAN Arcade entries. A page loading, service returning HTTP 200, or emulator canvas appearing is not enough. You must verify whether a normal player can actually start and interact with the game.

This is an investigation/reporting task by default. Do not change game code, catalogue files, nginx config, services, or packages unless Dylan/main agent explicitly asks.

## Recommended Model
Use Codex / GPT-5 medium with browser automation and screenshot support.

Medium reasoning is suitable for repeated gameplay QA. Escalate to GPT-5 high/extra-high only for games that require code debugging, complex emulator configuration, service orchestration, or unclear legal/source decisions.

## QA Principle
A game is only "tested playable" if you actually played enough to prove the main loop starts.

Minimum proof examples:
- Strategy game: started a new map/game, selected unit/city/building, performed one meaningful action.
- DOS game: booted in emulator, started or loaded a game, clicked/typed through first meaningful action.
- Browser game: started game, moved/selected/acted, observed state change.
- Native/server game: server starts, client install/download path is clear, join flow is documented or tested where possible.
- Board game: rules/player count/setup are clear, not just a dead info page.

## Required Result Categories
Use these result labels exactly:
- playable: real gameplay verified.
- partly_playable: launches but has issues, missing docs, confusing controls, or incomplete first action.
- not_playable: crashes, blank screen, missing files, broken controls, or cannot start game.
- needs_manual_human_test: agent cannot reasonably validate but game may be playable.
- blocked_missing_files: package/ROM/client files unavailable.
- blocked_external_dependency: requires internet or external account/service.

## Required Outputs
Write all outputs inside:
- /home/dylan/LAN_Arcade/agent-handoffs/phase5-gameplay-qa

Use these locations:
- work/qa-targets.csv: candidate games selected for QA.
- work/gameplay-results.csv: structured results.
- screenshots/: proof screenshots, grouped by game id/slug.
- logs/: browser logs, console logs, service logs, command logs.
- status/STATUS.md: current progress and summary.
- outbox/: final notes for the main LAN Arcade agent.
- inbox/: questions or blockers for Dylan/main agent.

Recommended columns for gameplay-results.csv:
- game_id
- title
- platform_or_type
- url_or_launch_path
- result
- tested_on
- offline_checked_yes_no
- save_checked_yes_no
- first_action_verified
- screenshot_path
- log_path
- player_facing_issue
- technical_issue
- recommended_next_action
- notes

## Test Flow
For each game:
1. Open the user-facing game page from the deployed arcade route.
2. Confirm the page explains what the game is and what to click.
3. Launch or follow the install/start path.
4. Start a new game/session if possible.
5. Perform one meaningful in-game action.
6. Capture screenshot evidence.
7. Check for console errors, missing files, excessive memory, broken controls, or confusing wording.
8. If practical, reload/resume or save/load.
9. If practical, run a no-internet/offline check or confirm no external network is needed.
10. Record result in gameplay-results.csv.

## First Priority Batches
Start small. Do not burn hours blindly.

Batch 1: 10 visible/high-risk games:
- SimAnt / Classic PC
- SimCity Classic DOS
- Prince of Persia DOS
- Lemmings DOS
- The Incredible Machine DOS
- Unciv LAN Server
- Mindustry LAN Server
- Pillage First!
- EvoLab
- one Game Boy title that already works well

Batch 2 after reporting:
- remaining playable Classic PC/DOS packages
- top featured/native LAN games
- board-game entries with weak start flow

## Safety Rules
- Do not delete or overwrite saves.
- Do not modify production data unless explicitly asked.
- Do not run many heavy services at once. Start/test/shut down one heavy game at a time.
- Do not run the full Apache-first installer from the README.
- Do not mark something playable unless you actually played it.
- Keep work VM-local.
- If browser testing must touch Dylan's active game, do not reset or disrupt it.

## Communication Protocol
Update status/STATUS.md after each mini-batch.

Use outbox/READY_FOR_MAIN_AGENT.md when a batch is complete. Include:
- attempted count
- playable count
- partly playable count
- not playable count
- missing files/external dependency count
- screenshots directory
- major player-facing wording problems
- major technical problems

Use inbox/BLOCKERS.md for questions or risks.

## Regression Rule
If you find a failure that would have passed old page-load QA, call it out explicitly. These are the most valuable findings.
