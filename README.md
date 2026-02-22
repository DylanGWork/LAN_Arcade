# LAN Arcade

Self-hosted **offline browser game arcade** that sets itself up with a single script.

LAN Arcade is a small project I built so my kids can enjoy fun browser games and a taste of what the old web used to feel like – without all the ads, tracking, loot boxes and “please sign up” pop-ups that come with the modern internet. Everything runs locally on our own network, no accounts needed and no data going anywhere.

It’s lightweight enough to host on a Raspberry Pi or tiny VM, so you can throw it in a bag for long road trips or holidays. Power it up, connect devices to its Wi-Fi or LAN, and the kids get a fast, ad-free game portal that works even when there’s no internet at all.

**This is unfinished BETA - assume nothing works**

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

Whatever you type becomes the ```<title>``` and ```<h1>``` on the homepage
(e.g. SmithNet LAN Arcade). Press Enter to accept the default.

The script will then:
1. Install Apache + helper tools (if they’re not already installed)
2. Mirror each configured game into /var/www/html/mirrors/<game>/
3. Regenerate /var/www/html/mirrors/games/index.html with pretty cards
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
- Play button with a little emoji
Click a card to launch the game.

# Updating / redeploying

Whenever you pull new changes from git (e.g. new games added):
```
cd /opt/lan-arcade
git pull
sudo ./setup_lan_arcade.sh
```

The script is safe to rerun:
- Existing game folders are left in place (no re-download unless you delete them)
- The homepage HTML is rebuilt every time so new games appear automatically

# Customisation
Change the arcade name (title/header)

Two options:
- Interactive – just type a new name at the prompt when you run the script.
- Non-interactive – set ARCADE_NAME in the environment:
```
ARCADE_NAME="Magical LAN" sudo ./setup_lan_arcade.sh
```
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

Special case: some games can be pulled from a GitHub ZIP.
For those you can use a magic value (e.g. ZIP_GITHUB_REPO) and handle them
inside setup_lan_arcade.sh (see the typing-test example in the script).

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

If a folder exists under /var/www/html/mirrors/ but isn’t in GAME_INFO,
the script falls back to a generic “HTML5 · Offline” card for that folder.

3. Run the setup script again

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
