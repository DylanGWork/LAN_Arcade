# Game Intake Agent Handover

Created: 2026-06-19

This document is for agents whose job is to discover, triage, and prepare new
LAN Arcade game candidates before a build/test agent promotes them into the
live arcade.

## Start Here

Work on the GannanNet VM, not on Dylan's laptop.

```sh
cd /home/dylan/LAN_Arcade
sed -n '1,220p' AGENTS.md
sed -n '1,260p' docs/AGENT_HANDOVER.md
sed -n '1,260p' docs/VM_DEVELOPMENT_AND_QA.md
sed -n '1,220p' docs/EMULATOR_LIBRARY_PLAN.md
sed -n '1,260p' docs/GAME_INTAKE_AGENT_HANDOVER.md
```

Do not run the full Apache-first installer from the README. If you need to
regenerate the existing nginx-served arcade pages, use the safe VM regeneration
path from `docs/VM_DEVELOPMENT_AND_QA.md`.

## Work Areas

- Git-tracked candidate notes and small metadata:
  `/home/dylan/LAN_Arcade/game-intake/`
- VM-local/NFS-backed installer and archive cache:
  `/srv/lan-arcade/native-downloads/intake/`
- Browser-visible native download shelf for cached files:
  `/mirrors/games/downloads/native/intake/`
- Existing private emulator vault tooling:
  `/home/dylan/LAN_Arcade/docs/EMULATOR_LIBRARY_PLAN.md`
- Promoted playable hubs, after approval:
  `/home/dylan/LAN_Arcade/local-games/<game-id>/`

Keep large files out of Git. The repo should contain source scripts, metadata,
checksums, hand-written hub pages, and reports. It should not contain commercial
game archives, private ROMs, installers, ISO files, or extracted game assets.

## Intake Mission

The intake agent should build a ranked, evidence-backed queue of games worth
adding to LAN Arcade. It may research sites such as My Abandonware, open-source
game directories, project homepages, itch.io, GitHub/GitLab, source package
repositories, and official mirrors.

For each candidate, record:

- What the game is and why it is worth trying.
- Platform and expected runtime: browser, EmulatorJS, DOSBox, ScummVM, native
  client, LAN server, or heavier service stack.
- License and redistribution status.
- Offline strategy: what must be cached locally so a new player can install or
  play without internet.
- Estimated disk size, RAM/CPU needs, and whether it is suitable for the Pi
  camping shelf, GannanNet full shelf, or future heavier hardware.
- Test plan that proves actual gameplay, not just HTTP 200 or successful launch.

## Legal And Redistribution Rules

Treat abandonware sites as discovery sources, not automatic permission to mirror
or redistribute. A candidate is safe to cache or publish only when one of these
is true:

- It is open source with a license that permits redistribution.
- It is freeware/public-domain with explicit rights-holder permission to
  redistribute.
- It is a demo/shareware release where redistribution is allowed.
- It is a package from a Debian/official package repository that we can cache
  with normal package metadata.
- Dylan supplies private files for personal VM-local use. In that case, keep the
  files out of GitHub and label the shelf private.

If a commercial game has no clear redistribution permission, set
`license_status=legal-review` and do not mirror the binary into the public
arcade. You may still record metadata, screenshots from official pages where
permitted, and a note that Dylan can provide private files later.

Never commit credentials, access tokens, private commercial files, ROMs, ISOs,
serial keys, cracked executables, or generated private archives.

## Candidate Status Values

- `discovery`: found, not evaluated yet.
- `legal-review`: interesting, but redistribution rights are unclear.
- `license-clear`: rights appear compatible with LAN Arcade caching.
- `download-cached`: files are cached on the VM/NFS shelf with checksums.
- `hub-draft`: a local hub page exists but gameplay is not proven.
- `smoke-pass`: real no-internet gameplay evidence exists.
- `partial`: launches or joins but gameplay proof is incomplete.
- `blocked`: technical blocker or external network dependency.
- `rejected`: not suitable, duplicate, unsafe, non-English only, or not fun.

## Test Standard

Do not mark a game playable because a page returns HTTP 200. A pass needs
evidence that a user can do something meaningful without internet.

Minimum evidence for a promoted game:

- The player can access the game page from `/mirrors/`.
- Any required client/server/download is available locally.
- External network is blocked during the smoke test.
- The game reaches a real title/menu/gameplay/setup state.
- Screenshots and logs are saved under `qa/reports/` or the relevant VM-local
  report shelf.
- For heavy services, only one stack is started at a time and it is stopped
  after testing.

For emulator shelves, use the no-AI smoke runner from
`docs/EMULATOR_LIBRARY_PLAN.md`. It captures game screenshots and writes a single
visual report, so bulk checks do not require an agent to watch every game.

## My Abandonware Intake Notes

My Abandonware can be useful for discovery, historical metadata, platform tags,
and finding candidate names like Tycoon, SimCity, Civilization, DOS, Windows,
Amiga, and console-era games. Use it carefully:

- Do not bulk scrape or bulk download the site.
- Rate-limit requests and keep notes/checksums of anything cached.
- Prefer official freeware/open-source releases, demos, shareware, or games with
  explicit redistribution permission.
- Commercial full-game downloads with unclear rights go to `legal-review`.
- For private Dylan-provided files, build a private VM-local shelf like the
  existing emulator vault, not a public GitHub mirror.

## Expected Deliverables

Update the files under `game-intake/` as you work:

- `candidates.csv`: one row per candidate, with status and next action.
- `source-notes.md`: source directories, search terms, and notable findings.
- Optional per-batch markdown reports, for example
  `game-intake/batch-2026-06-19-myabandonware.md`.

If downloads are cached, write a small manifest beside them on the native shelf
with URL, timestamp, file size, checksum, license notes, and whether the file is
public-cache-safe or private-only.

## Promotion Gate

Do not add a candidate to the main catalog until it has passed the relevant
gate:

- Browser/emulator game: local play page works, offline blocked-network smoke
  has screenshots, and metadata is clear.
- Native client game: installer/package is cached locally, client launches from
  local instructions, and a gameplay screenshot exists.
- LAN/server game: service start/stop command is documented, ports are known,
  one-at-a-time smoke succeeds, and resource usage is recorded.
- Private game files: private-only label, no files in GitHub, no public claims
  that redistribution is allowed.

When in doubt, leave the item in `game-intake/` and ask Dylan or the build/test
agent before mirroring.
