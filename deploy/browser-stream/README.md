# Browser Stream Deployment

The live GannanNet deployment uses:

- control service: `lan-arcade-browser-stream-control.service`
- player URL: `/browser-stream/`
- private noVNC upstream: `lan-arcade-browser-stream:6080`
- control upstream: `172.18.0.1:6081`
- internal Docker network: `lan-arcade-browser-stream-internal`
- NFS package cache: `/srv/lan-arcade/native-downloads/browser-stream/debian-bookworm-amd64/`
- NFS saves: `/srv/lan-arcade/native-downloads/browser-stream/saves/`

## Rebuild offline runtime

The cache step is the only internet-using step. Once cached, image construction
uses `docker build --network none`.

```sh
bash deploy/browser-stream/cache_packages.sh
bash deploy/browser-stream/build_image.sh
```

## Verification

```sh
bash qa/browser-stream-lifecycle.sh
LAN_ARCADE_QA_USERNAME=<local-user> \
LAN_ARCADE_QA_PASSWORD=<local-password> \
  python3 qa/browser-stream-live.py --report qa/reports/browser-stream-live
node qa/browser-stream-ui.mjs
```

These checks cover all six visible X windows, network-isolated runtime,
noVNC, authenticated and guest ownership, protected WebSocket access,
per-player persistence, hub-to-game launch, and cleanup.

Only one browser-streamed desktop game runs at once. Larger concurrency should
be added deliberately after measuring VM load.
