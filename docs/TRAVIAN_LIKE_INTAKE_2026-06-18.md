# Travian-like Strategy Intake - 2026-06-18

Added a staged Travian-like strategy batch.

Live now:

- Pillage First! is deployed as a static mirror at `/var/www/html/mirrors/pillage-first/` and served at `https://192.168.1.106/mirrors/pillage-first/` for real LAN clients. Plain HTTP requests to `/mirrors/pillage-first/` redirect to HTTPS because Chromium blocks OPFS storage on plain HTTP LAN IP origins.
- The arcade catalog entry is `pillage-first-lan`, a hub page that links to the live mirror so safe metadata regeneration will not overwrite the built upstream app.
- Build/rebuild script: `scripts/build_pillage_first_mirror.sh`.
- Upstream: `https://github.com/jurerotar/Pillage-First-Ask-Questions-Later`, commit `54451093040b3934382fa585be2b61f26a653bfb`, license `AGPL-3.0-or-later`.
- LAN build patch: Vite/manifest paths use `/mirrors/pillage-first/`; prerendered HTML is patched for subpath hosting; the official `@pillage-first/graphics` pack is injected and rewritten under `/mirrors/pillage-first/graphic-packs/`; landing screenshots are copied from upstream `.github/assets`; automatic PeerJS advertiser is removed from `root.tsx` so the app does not attempt background cloud discovery on page load; generated JS gets a `crypto.randomUUID` fallback for non-localhost origins.

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

Keep Pillage First live over HTTPS. The VM webserver config in `/home/dylan/wordpress/nginx-conf/nginx.conf` now redirects `/mirrors/pillage-first/` HTTP traffic to HTTPS and uses a self-signed LAN certificate in `/home/dylan/wordpress/nginx-conf/certs/`; backups were written with the suffix `.bak-lan-arcade-https-20260618T083822Z`. For Vallorium, TravianZ, Freeciv-web, or Unknown Horizons, start only one stack at a time, run a real gameplay/service smoke, record CPU/RAM/ports/logs, and stop it afterward.

Regression review on 2026-06-18:

- `qa/pillage-first-live-smoke.mjs` now checks both `http://127.0.0.1/mirrors/pillage-first/` and `https://192.168.1.106/mirrors/pillage-first/` by default.
- The focused smoke creates a new world and waits for the resource/gameplay screen, with external requests blocked.
- Passing reports:
  - `qa/reports/pillage-first-live-smoke-20260618T083937Z`
  - `qa/reports/pillage-first-live-smoke-20260618T084057Z`
- Recent arcade-entry sweep against the real LAN HTTPS catalog passed for 36 newly added entries in both desktop and mobile profiles: `qa/reports/recent-lan-review-20260618T0843Z`.
- Graphics review found the official `@pillage-first/graphics` AVIF pack was not being copied by the LAN build; rebuilds now deploy it and rewrite `/graphic-packs/` URLs for subpath hosting.

Known client note:

- First visit to `https://192.168.1.106/mirrors/pillage-first/` may require accepting the VM's self-signed certificate in the browser.
