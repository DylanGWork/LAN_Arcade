# LAN Arcade

Self-hosted **offline browser game arcade** that sets itself up with a single script.

This repo contains:

- `setup_lan_arcade.sh` – installer + HTML generator
- `games.meta.sh` – list of games and their metadata (titles, icons, descriptions, tags)

The script mirrors a bunch of HTML/JS games (mostly idle / clicker / educational) into
`/var/www/html/mirrors/` and builds a nice card-based homepage at:

> `/var/www/html/mirrors/games/index.html`

So anyone on your LAN can visit:

```text
http://<server-ip>/mirrors/games/
