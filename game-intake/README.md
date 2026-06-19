# Game Intake Workspace

This folder is the Git-tracked scratchpad for discovering and triaging future
LAN Arcade games. It is for small metadata, candidate lists, and hand-written
notes only.

Read first:

```text
docs/GAME_INTAKE_AGENT_HANDOVER.md
docs/EMULATOR_LIBRARY_PLAN.md
docs/VM_DEVELOPMENT_AND_QA.md
```

Large files go here instead:

```text
/srv/lan-arcade/native-downloads/intake/
```

That NFS-backed shelf is browser-visible at:

```text
/mirrors/games/downloads/native/intake/
```

Do not commit installers, ROMs, ISOs, ZIP archives, extracted commercial game
files, secrets, or private downloads to GitHub.

## Workflow

1. Add candidates to `candidates.csv`.
2. Record source/search notes in `source-notes.md`.
3. Cache only license-clear or private Dylan-provided files on the native shelf.
4. Record checksums and license notes beside cached files.
5. Leave candidates in this workspace until a build/test pass proves offline
   gameplay.
