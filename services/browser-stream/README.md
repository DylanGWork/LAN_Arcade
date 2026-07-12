# Browser Stream Service

This service gives six Linux desktop games a normal **Play in browser** action.
It runs one allowlisted game at a time in a disposable X11 container and streams
that window through the arcade's local noVNC page.

## Player behavior

- Signed-in players use a save directory derived from their stable Arcade account ID.
- Guests use a browser-generated UUID and keep a separate guest save directory.
- Save paths are created only by the server under:
  `/srv/lan-arcade/native-downloads/browser-stream/saves/`
- A second player sees that the stream is occupied; they cannot stop or replace its game.
- The idle cleaner stops abandoned sessions after 30 minutes.
- Browser streaming is currently silent. Linux download helpers remain available.

## Security boundary

- exact game IDs and command arrays from `config/browser-stream-games.json`;
- no arbitrary command or client-provided filesystem path;
- one fixed-name session container;
- Docker `--internal` network with no internet route;
- nginx joins that private network only to reach noVNC;
- protected noVNC HTML, assets, and WebSocket via a signed HttpOnly session cookie;
- account tokens validated against the local Arcade API;
- read-only root filesystem, dropped capabilities, `no-new-privileges`, and limits;
- no Docker socket inside the game container.

## Operator commands

```sh
python3 scripts/browser_stream_admin.py list
python3 scripts/browser_stream_admin.py status
python3 scripts/browser_stream_admin.py stop
```

The public controller is managed by
`lan-arcade-browser-stream-control.service`. Runtime game containers are
created only while a player is using the service.
