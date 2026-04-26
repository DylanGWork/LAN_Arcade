# Strategy Game Spike

This note tracks the first pass at "fancier" strategy games for the camping LAN
arcade. The goal is not just visual ambition; the game has to survive offline,
work on mobile-class clients, and fit a Raspberry Pi 4 with 8 GB RAM.

## Freeciv-web

Freeciv-web is the impressive browser option: real map graphics, Civilization-like
rules, and no client installation beyond a browser.

Current VM spike:

- Docker image built successfully from a fresh shallow clone.
- Image size: about 3.56 GB.
- Home page rendered at `http://127.0.0.1:18080/`.
- Single-player modal rendered with the real Freeciv UI.
- Corrected browser smoke could fill the player name and click Start Game.
- Post-start page reached the in-game shell, but the main map did not fully render.
- Browser smoke saw server 500 responses during game start.
- External requests were still attempted for Google platform JS, cdnjs mousewheel,
  Bootstrap, Font Awesome, Google Fonts, webglstats, and YouTube embeds depending
  on page path.

Memory observations from Docker:

```text
Clean startup after first ready response: 403 MiB cgroup memory, 64 PIDs
After server slots warmed up:           900 MiB cgroup memory, 90 PIDs
After three browser clients:            1.30 GiB cgroup memory, 117-121 PIDs
Summed process RSS after three clients: about 1.63 GiB
```

Screenshots and raw reports from this spike:

```text
qa/reports/strategy-spike/freeciv-home.png
qa/reports/strategy-spike/freeciv-singleplayer.png
qa/reports/strategy-spike/freeciv-game-after-start.png
qa/reports/strategy-spike/freeciv-load-client-1.png
qa/reports/strategy-spike/freeciv-load-client-2.png
qa/reports/strategy-spike/freeciv-load.json
```

Recommendation: keep Freeciv-web as an experimental research target, not a
camping-critical game yet. It may fit in 8 GB if tuned, but the default stack is
large and not offline-clean. Before promoting it, prune unused game slots, remove
or localize remote assets, fix game-start 500s, and rerun a 2-4 player smoke on
the actual Pi.

## Unciv

Unciv is the better near-term strategy fit. Phones and desktops run the native
Unciv client, while the Raspberry Pi serves multiplayer turn files. That gives us
Civilization-style gameplay without asking the Pi to run a heavy browser game
stack.

Added files:

```text
services/unciv/Dockerfile
services/unciv/entrypoint.sh
deploy/unciv.compose.yml
docs/UNCIV_SERVER.md
```

Current VM spike:

```text
Image size:                  about 331 MB
Java runtime needed:         Java 21
Idle container memory:       about 127 MiB
After 500 /isalive checks:   about 137 MiB
Request result:              500/500 HTTP 200
Raw report:                  qa/reports/strategy-spike/unciv-load.json
```

Recommendation: promote Unciv as the first fancier turn-strategy service if the
real phone/client connection test passes. It is much lighter than Freeciv-web,
but it still needs a complete create-game, upload-turn, and download-turn loop
from actual clients before camping.

## Mindustry

Mindustry remains the best real-time "wow" multiplayer candidate. Like Unciv,
the Pi hosts the server while players' devices do the graphics and controls.

Recommendation: keep it optional and test it on the actual Pi with two clients.
Start with a 512 MB JVM heap and a small map.
