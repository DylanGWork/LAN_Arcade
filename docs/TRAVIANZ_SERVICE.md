# TravianZ LAN Service

TravianZ is kept as an isolated, on-demand service candidate rather than a static mirror.

- Hub: `/mirrors/travianz-lan/`
- Service URL: `http://192.168.1.106:8092/`
- Source archive: `/var/www/html/mirrors/games/downloads/native/travian-like/travianz/travianz-d00826167857.tar.gz`
- Runtime folder: `$HOME/.lan-arcade/services/travianz/`
- Compose file: `deploy/travianz.compose.yml`

Commands:

```bash
scripts/prepare_travianz_service.sh start
scripts/prepare_travianz_service.sh status
node qa/travianz-smoke.mjs
scripts/prepare_travianz_service.sh stop
```

The smoke test installs the game if needed, captures screenshots, blocks off-LAN requests in Playwright, and checks that the live game/register pages render. It is intentionally stronger than a 200-only check.
