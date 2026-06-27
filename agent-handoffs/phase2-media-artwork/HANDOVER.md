# Phase 2 Media / Artwork Agent Handover

## Start Here
You are working on Dylan's LAN Arcade project on the GannanNet VM.

VM:
- SSH: dylan@192.168.1.106
- Repo: /home/dylan/LAN_Arcade
- Public arcade: http://192.168.1.106/mirrors/games/

Workspace for this task:
- /home/dylan/LAN_Arcade/agent-handoffs/phase2-media-artwork

Read before working:
- /home/dylan/LAN_Arcade/AGENTS.md
- /home/dylan/LAN_Arcade/docs/AGENT_HANDOVER.md
- /home/dylan/LAN_Arcade/docs/VM_DEVELOPMENT_AND_QA.md
- /home/dylan/LAN_Arcade/agent-handoffs/phase2-media-artwork/HANDOVER.md

## Mission
Find and prepare better player-facing artwork/media for LAN Arcade cards and shelves, especially entries currently using fallback initials, blank screenshots, or confusing placeholder art.

This is a media-preparation task, not a deployment task. Do not edit production catalogue files unless Dylan or the main agent explicitly asks. Prepare assets, manifests, source notes, and recommendations for the main agent to review and integrate.

## Recommended Model
Use Codex / GPT-5 medium or equivalent medium-reasoning coding agent.

This task benefits from careful judgement but does not need extra-high reasoning. Escalate to a stronger agent only for copyright/licensing ambiguity, confusing game identity, or batch automation that may affect production files.

## Scope
Prioritise in this order:
1. Featured/top-shelf cards.
2. Cards using fallback initials such as DOS, EMU, PILL, TZ, MGL, DCSS, FLAR, etc.
3. Classic PC / DOS entries.
4. Board-game entries.
5. Native/server game hubs.
6. Emulator shelves and curated retro entries.

The goal is recognisable player-facing media: box art, title screens, real gameplay screenshots, official screenshots, or clean LAN Arcade screenshots.

## What Good Looks Like
A normal user should glance at a card and recognise what kind of game it is. Avoid art that looks like an internal placeholder, broken logo, random icon, or admin status block.

Good sources:
- Official project websites/media kits.
- Official GitHub/GitLab repos where screenshots are committed.
- Official wiki/manual screenshots.
- Existing local screenshots already captured by LAN Arcade QA.
- Dylan-provided game packages/screenshots.
- Public-domain/open-source/homebrew screenshots where licensing is clear.

Avoid:
- Random unverified image-search thumbnails with unknown provenance.
- Watermarked images.
- Fan art presented as official art.
- Low-resolution images when a better source exists.
- Duplicate regional variants unless the game entry specifically needs that version.
- Anything that makes a game look playable if it is not actually playable.

## Required Outputs
Write all outputs inside:
- /home/dylan/LAN_Arcade/agent-handoffs/phase2-media-artwork

Use these locations:
- artwork-candidates/: proposed images, grouped by game id or slug.
- work/missing-art-manifest.csv: catalogue entries needing art.
- work/artwork-recommendations.csv: proposed mapping from game id to candidate image.
- work/source-notes.md: source URLs, license notes, and confidence notes.
- logs/: command logs or scrape logs.
- status/STATUS.md: current progress and summary.
- outbox/: final notes for the main LAN Arcade agent.
- inbox/: questions or blockers for Dylan/main agent.

Recommended CSV columns for artwork-recommendations.csv:
- game_id
- title
- current_problem
- proposed_image_path
- image_type
- source_url
- source_kind
- license_or_rights_note
- confidence_high_medium_low
- needs_human_review_yes_no
- notes

## Discovery Hints
Start by finding catalogue/metadata files rather than reading the entire repo. Likely useful searches:

```sh
cd /home/dylan/LAN_Arcade
rg -n "fallback|initial|image|screenshot|media|card|cover|art" config local-games scripts packages services docs
rg -n "PILL|EMU|DOS|TZ|MGL|DCSS|FLAR" config local-games packages services
find /var/www /srv /home/dylan/LAN_Arcade -maxdepth 5 -iname '*screenshot*' -o -iname '*cover*' -o -iname '*.png' -o -iname '*.jpg' | head
```

If a generated catalogue exists, use it as the source of truth for game ids and current image paths.

## Safety Rules
- Do not delete or overwrite existing production artwork.
- Do not run the full Apache-first installer from the README.
- Do not deploy or regenerate the arcade unless the main agent asks.
- Do not download huge media dumps.
- Do not import copyrighted commercial box art in bulk without source notes. If uncertain, mark for review.
- Do not expose secrets or tokens.
- Keep work VM-local.

## Communication Protocol
Update status/STATUS.md as you work.

Use outbox/READY_FOR_MAIN_AGENT.md when a batch is ready. Include:
- count of games scanned
- count needing artwork
- count with proposed artwork
- high-confidence list
- needs-review list
- any scripts used
- where the images are stored

Use inbox/BLOCKERS.md if you need Dylan/main agent input.

## Initial Batch Recommendation
Start with the first 30-50 most visible items. Do not try to solve the whole catalogue in one pass. High-quality visible fixes are better than hundreds of questionable images.
