# LAN Arcade

Self-hosted **offline browser game arcade** that sets itself up with a single script.

LAN Arcade is a small project I built so my kids can enjoy fun browser games and a taste of what the old web used to feel like – without all the ads, tracking, loot boxes and “please sign up” pop-ups that come with the modern internet. Everything runs locally on our own network, no accounts needed and no data going anywhere.

It’s lightweight enough to host on a Raspberry Pi or tiny VM, so you can throw it in a bag for long road trips or holidays. Power it up, connect devices to its Wi-Fi or LAN, and the kids get a fast, ad-free game portal that works even when there’s no internet at all.

**This is unfinished BETA - assume nothing works**

This repo contains:

- `setup_lan_arcade.sh` – installer + HTML generator
- `games.meta.sh` – list of games and metadata (titles, icons, descriptions, tags, categories)

The script mirrors a bunch of HTML/JS games (mostly idle / clicker / educational) into
`/var/www/html/mirrors/` and builds a nice card-based homepage at:

> `/var/www/html/mirrors/games/index.html`

So anyone on your LAN can visit:

```text
http://<server-ip>/mirrors/games/
```

# Features

- 🕹 Offline-friendly – games are mirrored locally with wget
- 🎨 Pretty UI – card-based public index generated from `catalog.json`
- 🗂 Category-aware – public category chips + admin filters across educational, ages 5+/10+/13+, maths, english, typing, and genre categories
- 🔐 Admin controls – password-protected admin page to disable full categories or individual games
- 📚 Offline wiki – local wiki page with docs + searchable game catalog at `/mirrors/games/wiki/`
- 🔁 Idempotent – safe to rerun; completed game folders are skipped via marker files
- 🧩 Easy to extend – update URLs, card data, and categories in `games.meta.sh`

# Requirements
On the machine you’re deploying to:
- Debian/Ubuntu/Raspberry Pi OS (or similar)
- bash
- Internet access for the first run (to mirror the games)
- git installed
The script will install these packages automatically:
- apache2
- apache2-utils
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

2. Pick an install directory
This repo doesn’t have to live in /opt, but it’s a nice conventional place.
```
sudo mkdir -p /opt/lan-arcade
sudo chown "$USER":"$USER" /opt/lan-arcade
cd /opt/lan-arcade
```
3. Clone the repo
```
git clone https://github.com/DylanGWork/LAN_Arcade.git .
```

You should now see:
```
/opt/lan-arcade
  ├─ setup_lan_arcade.sh
  ├─ games.meta.sh
  └─ README.md
```

Make the setup script executable (one-time):
```
chmod +x setup_lan_arcade.sh
```

4. Run the setup script
```
sudo ./setup_lan_arcade.sh
```

You’ll be asked:
```
Enter a name for your LAN arcade (e.g. 'GannanNet', 'SmithNet', 'Magical LAN') [GannanNet]:
```

On first run you’ll also be asked to set an admin password for the protected admin panel.

Whatever you type becomes the ```<title>``` and ```<h1>``` on the homepage
(e.g. SmithNet LAN Arcade). Press Enter to accept the default.

The script will then:
1. Install Apache + helper tools (if they’re not already installed)
2. Create or reuse admin credentials
3. Mirror each configured game into /var/www/html/mirrors/<game>/
4. Build `/var/www/html/mirrors/games/catalog.json`
5. Regenerate `/var/www/html/mirrors/games/index.html` (public page)
6. Regenerate `/var/www/html/mirrors/games/wiki/index.html` (offline wiki page)
7. Regenerate `/var/www/html/mirrors/games/admin/index.html` + save endpoint
8. Configure Apache Basic Auth for `/mirrors/games/admin/`
    🔧 You do not run games.meta.sh yourself.
    It’s automatically loaded by setup_lan_arcade.sh and used as a config file.

5. Open the arcade
On any device on the same network:
```
http://<server-ip>/mirrors/games/
```
If you access it from the server itself you can usually use:
```
http://localhost/mirrors/games/
```
You should see a grid of cards with:
- Game title
- Genre meta line (e.g. UTILITY · INCREMENTAL)
- Short description
- Tag “pills”
- Category filter chips at the top of the page
- Play button with a little emoji
Click a card to launch the game.

Admin panel (login required):
```text
http://<server-ip>/mirrors/games/admin/
```
Use it to disable:
- Whole categories (e.g. `age-13-plus`, `maths`, `typing`)
- Individual games

The public index automatically applies those saved filters.

Offline wiki (no login required):
```text
http://<server-ip>/mirrors/games/wiki/
```
Use it as a LAN-local reference for:
- Game list + search/filter
- Category/tag overview
- Admin control instructions
- Important files/paths

# Admin controls

Admin URL (HTTP Basic Auth):
```text
http://<server-ip>/mirrors/games/admin/
```

The admin page has three main actions:
- **Save Changes**: writes your current checkbox selections to `/var/www/html/mirrors/games/admin.filters.json`.
- **Enable All**: unchecks all category/game disables in the UI. Click **Save Changes** after this to persist.
- **Reload From Disk**: reloads catalog + filters from disk and discards unsaved UI state.

Recommended workflow:
1. Disable categories and/or individual games.
2. Click **Save Changes**.
3. Open the public page and verify visibility.
4. If you want to undo all filtering, click **Enable All** then **Save Changes**.

Credential behavior:
- First setup prompts for admin password unless `ADMIN_PASSWORD` is already provided.
- On reruns, existing credentials are reused if `ADMIN_PASSWORD` is not set.
- To rotate password:
```
ADMIN_PASSWORD="new-strong-password" sudo ./setup_lan_arcade.sh
```
- To rotate username + password:
```
ADMIN_USER="newadmin" ADMIN_PASSWORD="new-strong-password" sudo ./setup_lan_arcade.sh
```
- `ADMIN_USER` allows letters, numbers, `.`, `_`, and `-`.

# Updating / redeploying

Whenever you pull new changes from git (e.g. new games added):
```
cd /opt/lan-arcade
git pull
sudo ./setup_lan_arcade.sh
```

The script is safe to rerun:
- Existing game folders are left in place (no re-download unless you delete them)
- Catalog and pages are rebuilt every run so metadata/category changes appear automatically

# Customisation
Change the arcade name (title/header)

Two options:
- Interactive – just type a new name at the prompt when you run the script.
- Non-interactive – set ARCADE_NAME in the environment:
```
ARCADE_NAME="Magical LAN" sudo ./setup_lan_arcade.sh
```

Set admin credentials non-interactively:
```
ADMIN_USER="arcadeadmin" ADMIN_PASSWORD="strong-password" sudo ./setup_lan_arcade.sh
```

If admin credentials already exist and `ADMIN_PASSWORD` is omitted, existing credentials are kept.
If you run in a non-interactive environment and credentials do not exist yet, you must set `ADMIN_PASSWORD`.

# Add or edit games (for people hacking on the repo)

All game definitions live in games.meta.sh.

1. Add a new game source URL
In the **GAMES** array:
```
declare -A GAMES=(
  # existing entries...

  ["my-new-game"]="https://example.github.io/my-new-game/"
)
```

Special cases:
- `ZIP_GITHUB_REPO::owner/repo::branch` downloads a repo ZIP and copies its extracted files into the game folder.
- `GIT_GITHUB_REPO::owner/repo::branch` performs a shallow git clone with submodules and copies files into the game folder (useful when ZIP archives omit submodule content).
- `ZIP_GITHUB_REPO` remains as a legacy shortcut for the existing `typing-test` source.
- `ZIP_GITHUB_FILE::owner/repo::branch::path/to/file.html` downloads a repo ZIP and promotes that file to `index.html`.
- For `ZIP_GITHUB_REPO::...`, if the repo has no `index.html`, the first discovered HTML file is copied to `index.html`.

Example:
```
["crossword-classic"]="ZIP_GITHUB_REPO::deepakshajan/Crossword-Puzzle::master"
["game-of-sums"]="ZIP_GITHUB_FILE::jkanev/educational-html-games::master::game-of-sums.html"
```

2. Add pretty card metadata
In the GAME_INFO array, add a line using:
```
["my-new-game"]="Nice Game Title|🎮|GENRE · SUBGENRE|Short one-line description.|PrimaryTag,SecondaryTag"
```
- Title – card heading
- Icon – emoji shown in the Play button
- META line – small caps genre row (e.g. SPACE · IDLE)
- Description – short blurb for the card
- Tags – comma-separated list. First tag gets the highlighted pill style.

3. Add categories used by admin filtering
In the GAME_CATEGORIES array:
```
["my-new-game"]="educational,typing,english,age-10-plus"
```

Suggested category style:
- Audience: `age-5-plus`, `age-10-plus`, `age-13-plus`
- Learning: `educational`, `maths`, `english`, `typing`
- Genre/theme: `arcade`, `puzzle`, `idle`, `strategy`, `simulation`, `rpg`, etc.

If a folder exists under /var/www/html/mirrors/ but isn’t in GAME_INFO,
the script falls back to a generic “HTML5 · Offline” card for that folder.

4. Run the setup script again

After editing games.meta.sh and committing/pushing if you’re using git:
```
# on the server
cd /opt/lan-arcade
git pull           # if you pushed from your dev machine
sudo ./setup_lan_arcade.sh
```
You’ll get updated cards and any new games will be mirrored.

# Recommended dev workflow

For people maintaining the project:
1. On your main computer
- Clone this repo.
- Open it in VS Code.
- Edit games.meta.sh / setup_lan_arcade.sh.
- Commit and push using git.

2. On your server / VM / Pi
- cd /opt/lan-arcade
- git pull
- sudo ./setup_lan_arcade.sh

This is exactly the flow a “real” user would follow.

# Notes

- Games are mirrored for personal / LAN / offline use.
Please respect original licences and don’t publicly rehost in ways the authors
wouldn’t approve.
- First run needs internet to download the games. After that, everything
runs from your server.
- Script currently targets Debian-style systems. Other distros may need tweaks
to package names and service commands.
