# Travian-like Strategy Intake - 2026-06-18

Added a staged Travian-like strategy batch.

Live now:

- Pillage First! is deployed as a static mirror at `/var/www/html/mirrors/pillage-first/` and served at `/mirrors/pillage-first/`.
- The arcade catalog entry is `pillage-first-lan`, a hub page that links to the live mirror so safe metadata regeneration will not overwrite the built upstream app.
- Build/rebuild script: `scripts/build_pillage_first_mirror.sh`.
- Upstream: `https://github.com/jurerotar/Pillage-First-Ask-Questions-Later`, commit `54451093040b3934382fa585be2b61f26a653bfb`, license `AGPL-3.0-or-later`.
- LAN build patch: Vite/manifest paths use `/mirrors/pillage-first/`; prerendered HTML is patched for subpath hosting; landing screenshots are copied from upstream `.github/assets`; automatic PeerJS advertiser is removed from `root.tsx` so the app does not attempt background cloud discovery on page load.

Cached candidates, not live:

- Vallorium: MIT, persistent Travian-inspired browser multiplayer, backend still in development upstream.
- TravianZ: GPL-3.0, PHP/MariaDB Travian-like multiplayer stack. Needs isolated Docker install/admin/legal/branding review before live use.
- Freeciv-web: related browser 4X service candidate; native Freeciv already has a hub.
- Unknown Horizons: related native settlement/economy game candidate.

Source shelf:

- `/var/www/html/mirrors/games/downloads/native/travian-like/`
- Web: `/mirrors/games/downloads/native/travian-like/`
- Cache script: `scripts/cache_travian_like_assets.py`
- Current shelf size after this pass: about 399 MB, mostly Unknown Horizons and Freeciv-web source archives, stored on the NFS-backed native downloads mount.

Operational rule:

Keep Pillage First live. For Vallorium, TravianZ, Freeciv-web, or Unknown Horizons, start only one stack at a time, run a real gameplay/service smoke, record CPU/RAM/ports/logs, and stop it afterward.
