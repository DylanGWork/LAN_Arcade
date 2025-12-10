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
```

# Features

- 🕹 Offline-friendly – games are mirrored locally with wget
- 🎨 Pretty UI – cards with icons, genre line, description and tags
- 🔁 Idempotent – safe to rerun; existing game folders are skipped
- 🧩 Easy to extend – add more games by editing a single metadata file
- 🧪 Realistic deployment – edit locally, push via git, pull on a VM/RPi

# Requirements
On the machine you’re deploying to:
- Debian/Ubuntu/Raspberry Pi OS (or similar)
- bash
- Internet access for the first run (to mirror the games)
- git installed
The script will install these packages automatically:
- apache2
- wget
- unzip
It’s been used on:
- A Debian VM 
- Raspberry Pi-class hardware should also be fine

# Quick start – install on your server

These are the steps someone else would follow on their Debian/Ubuntu/RPi box.

1. Install git (if needed)
```
sudo apt update
sudo apt install -y git
```
