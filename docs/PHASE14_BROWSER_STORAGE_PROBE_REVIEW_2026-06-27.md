# Phase 14 Browser Storage Probe Review - 2026-06-27

Status: complete.
Scope: non-destructive tooling for emulator/DOS save investigation. No production launcher behavior changed.

## What Changed

- Added `scripts/probe_browser_save_storage.mjs`.
- The probe opens a URL in a fresh Playwright browser context and records:
  - localStorage keys and value sizes
  - sessionStorage keys and value sizes
  - IndexedDB database names/versions when the browser exposes them
  - CacheStorage names
  - page errors and console warnings
- It supports optional click/eval actions for future full-flow save probes.

## Checks Run

```sh
node --check scripts/probe_browser_save_storage.mjs
npm run qa:static
node scripts/probe_browser_save_storage.mjs --url http://127.0.0.1/mirrors/gb-2048/ --wait-ms 2500 --output /tmp/probe-gb-2048.json
node scripts/probe_browser_save_storage.mjs --url 'http://127.0.0.1/mirrors/private-dos-vault/play.html?id=simant-ma' --wait-ms 3500 --output /tmp/probe-simant-dos.json
```

Static mirror audit:

- 152/152 OK
- 0 external dependency refs

## Probe Findings

EmulatorJS sample: `/mirrors/gb-2048/`

- Page errors: 0
- Console warnings: audio autoplay/WebGL performance warnings only
- localStorage keys: 0
- sessionStorage keys: 0
- IndexedDB databases: `/data/saves`, `EmulatorJS-core`, `EmulatorJS-roms`

js-dos sample: `/mirrors/private-dos-vault/play.html?id=simant-ma`

- Page errors: 0
- Console warnings: 1 audio warning
- localStorage keys: `jsdos.8.renderBackend`, `jsdos.8.worker`
- IndexedDB databases observed in initial window: 0

## Review Findings

- EmulatorJS save handling is IndexedDB-backed, not compatible with the simple browser-localStorage adapter used in Phase 12.
- The EmulatorJS adapter should focus on database export/import or runtime-supported save APIs, not raw localStorage keys.
- js-dos initial state in this probe used localStorage runtime settings only; actual DOS game save files likely require in-emulator filesystem inspection after gameplay/save actions.
- The new probe gives us a safe way to compare storage before/after gameplay actions without changing production code.

## Known Limits

- This probe lists storage surfaces; it does not yet export database contents.
- The sample probes did not perform in-game save actions.
- SimAnt was only observed long enough to inspect launcher/runtime storage, not to validate DOS filesystem saves.
- IndexedDB database names are browser-reported and may vary by EmulatorJS version/core.

## Phase Review Decision

Proceed only after a per-runtime experiment plan:

1. EmulatorJS: create a before/after probe for one small homebrew ROM with a real in-game save or save-state action, then test export/import in a fresh context.
2. js-dos: create a before/after probe for one small DOS game with an explicit in-game save file, then inspect whether js-dos exposes bundle/filesystem export.
3. Keep production emulator/DOS launchers unchanged until restore into a fresh browser context is proven.
