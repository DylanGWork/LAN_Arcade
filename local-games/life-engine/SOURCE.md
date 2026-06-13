# The Life Engine Source

This LAN Arcade offline build is based on The Life Engine.

Upstream: https://github.com/MaxRobinsonTheGreat/LifeEngine
Commit: 15bb2fe444d3c5c0024dc92183fbda8249813fbb
License: GPL-3.0; see LICENSE.

Offline LAN changes in this copy:

- Removed CDN Font Awesome dependency and replaced it with local icon CSS.
- Replaced remote CanvasJS with a small local chart shim for the in-game stats panel.
- Removed the embedded YouTube video and external community links from the start panel.
- Disabled remote mod links in assets/mods/_list.json.

Build notes:

- npm install
- npm run build
