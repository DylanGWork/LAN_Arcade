# Phase 5 Arcade API Deploy Review - 2026-06-27

Scope: make the tested LAN Arcade API account/profile service reachable through the existing Docker nginx webserver at `/arcade-api/`.

## Changes

- Started the existing `deploy/lan-arcade-api.compose.yml` service as container `lan-arcade-api` on the existing `wordpress_app-network` Docker network.
- Updated `deploy/nginx-arcade-api-location.conf` to match the working live nginx proxy pattern.
- Inserted the `/arcade-api/` location into the live webserver config:
  - `/home/dylan/wordpress/nginx-conf/nginx.conf`
- Created live nginx config backup before editing:
  - `/home/dylan/wordpress/nginx-conf/nginx.conf.bak-20260627T045627Z-lan-arcade-api`

## Live Route

```text
/arcade-api/health      -> lan-arcade-api:3100/health
/arcade-api/server-info -> lan-arcade-api:3100/server-info
/arcade-api/accounts    -> lan-arcade-api:3100/accounts
```

The proxy strips the `/arcade-api/` prefix before forwarding to the API.

## Review Results

- `docker compose -f deploy/lan-arcade-api.compose.yml up -d --build`: pass.
- `docker exec webserver nginx -t`: pass.
- `docker exec webserver nginx -s reload`: pass.
- `curl http://127.0.0.1/arcade-api/health`: pass.
- `curl http://127.0.0.1/arcade-api/server-info`: pass, advertised account capabilities.
- `curl http://127.0.0.1/arcade-api/accounts`: pass, returned an empty account list.
- `curl -k https://127.0.0.1/arcade-api/health`: pass.
- `npm run qa:static`: pass, 152 scanned, 152 OK, 0 external entrypoint refs.
- `npm run qa:companion`: pass, report at `qa/reports/companion`.

## Issue Found And Fixed

The first nginx proxy attempt put `set $arcade_api_upstream ...` after `rewrite ... break`, which left the variable uninitialized and caused a 500. The fixed config sets the upstream before the rewrite.

## Known Limits

- The browser library still does not show an account picker or use account sessions.
- Mailbox provisioning remains pending; account emails are recorded as local addresses only.
- No persistent account was created during live smoke to avoid polluting the real account database.
- `/accounts` is still local/debug-oriented and must be admin-protected before exposing account management UI.
