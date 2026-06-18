#!/usr/bin/env python3
"""Metadata for LAN Arcade native intake batch three."""
from __future__ import annotations

BATCH_THREE = [
    {
        "id": "armagetronad-lan", "download_slug": "armagetronad", "title": "Armagetron Advanced LAN Hub", "short_title": "Armagetron Advanced", "icon": "TRON", "meta": "Native Action - Light-Cycle Arena", "description": "Offline Armagetron Advanced hub with Debian package set, light-cycle rules, LAN server notes, and future two-client join proof.", "tags": "Action,Multiplayer,Native", "categories": "action,multiplayer,arcade,age-10-plus,casual", "eyebrow": "Native classic intake",
        "lede": "A Tron-like 3D light-cycle arena where players race, turn sharply, and trap each other behind glowing walls. It is small, fast, and naturally LAN-friendly.",
        "facts": ["Light-cycle arena", "LAN multiplayer", "Small package set", "Linux-first cache"], "source": "https://armagetronad.org/", "packages": ["armagetronad", "armagetronad-common"],
        "docs": {"dest": "armagetronad-site", "source_subdir": "armagetronad.org", "pages": ["https://armagetronad.org/", "https://armagetronad.org/downloads.php", "https://wiki.armagetronad.org/index.php?title=FAQ"]},
        "cards": [["Why play", "It gives the arcade a tiny, skill-based LAN action game that should run on weak hardware and teach instantly: do not crash into walls."], ["Offline plan", "The first shelf is a Debian package set for GannanNet/Linux clients. Add Windows/macOS packages later if we want it as a broader LAN-party pick."], ["Proof still needed", "Start a local server, connect two clients, and capture a round where both players create trails."]],
        "steps": [["Drive and turn", "Use left/right turns to create walls while avoiding your own trail."], ["Trap, do not chase", "The core tactic is shaping the arena so opponents run out of exits."], ["Host locally", "A later smoke should start the dedicated server and join from a second client."], ["Promote after play", "Do not mark play-ready until a two-client LAN round succeeds."]],
        "status": [["Downloads", "Debian package set cached"], ["Service", "LAN server pending"], ["Client launch", "Pending"], ["Next gate", "Two-client round"]],
    },
    {
        "id": "megaglest-lan", "download_slug": "megaglest", "title": "MegaGlest LAN Hub", "short_title": "MegaGlest", "icon": "MGL", "meta": "Native RTS - Fantasy Warfare", "description": "Offline MegaGlest hub with Debian package set, RTS overview, faction notes, and LAN/skirmish proof path.", "tags": "Strategy,RTS,Native", "categories": "strategy,action,multiplayer,fantasy,age-10-plus", "eyebrow": "Native RTS intake",
        "lede": "A 3D real-time strategy game with factions, resource gathering, base building, units, tech progression, skirmish play, and LAN multiplayer.",
        "facts": ["3D RTS", "LAN/skirmish", "Fantasy factions", "Linux-first cache"], "source": "https://megaglest.org/", "packages": ["megaglest", "megaglest-data"],
        "docs": {"dest": "megaglest-site", "source_subdir": "megaglest.org", "pages": ["https://megaglest.org/", "https://docs.megaglest.org/Main_Page", "https://docs.megaglest.org/Getting_started"]},
        "cards": [["Why play", "This adds another proper RTS lane, lighter than 0 A.D. but still closer to classic base-building strategy than browser games."], ["Offline plan", "Cache Debian packages first, then prove a skirmish start before trying LAN."], ["Proof still needed", "The real test is not the launcher; it is creating a match, spawning units, and issuing orders without crashes."]],
        "steps": [["Start skirmish", "Use one AI opponent and a small map for first play."], ["Gather resources", "Workers collect core resources and enable buildings, upgrades, and military units."], ["Learn factions", "Different factions change unit rosters and tech priorities."], ["LAN later", "Host/join proof comes after a stable local skirmish screenshot."]],
        "status": [["Downloads", "Debian package set cached"], ["Service", "Client-hosted LAN"], ["Client launch", "Pending"], ["Next gate", "Skirmish start"]],
    },
    {
        "id": "unknown-horizons-lan", "download_slug": "unknown-horizons", "title": "Unknown Horizons LAN Hub", "short_title": "Unknown Horizons", "icon": "UH", "meta": "Native Strategy - Settlement Economy", "description": "Offline Unknown Horizons hub with Debian package set, settlement economy guide, and multiplayer/service research notes.", "tags": "Strategy,Simulation,Native", "categories": "strategy,simulation,management,city-builder,multiplayer,age-10-plus", "eyebrow": "Settlement strategy intake",
        "lede": "A 2D realtime strategy and settlement economy game about islands, production chains, trade, buildings, and careful expansion.",
        "facts": ["Settlement economy", "2D RTS/sim", "Production chains", "Linux-first cache"], "source": "https://unknown-horizons.org/", "packages": ["unknown-horizons"],
        "docs": {"dest": "unknown-horizons-site", "source_subdir": "unknown-horizons.org", "pages": ["https://unknown-horizons.org/", "https://unknown-horizons.org/download/", "https://unknown-horizons.org/wiki/"]},
        "cards": [["Why play", "This is close to the long-form settlement/strategy feeling Dylan keeps circling: slower, more managerial, and more about a growing colony than twitch play."], ["Offline plan", "Cache the Debian package set and make the hub explain the loop clearly before calling it playable."], ["Proof still needed", "Create a new game, place early buildings, and confirm production starts. Multiplayer status needs later verification."]],
        "steps": [["Scout the island", "Look for useful coastline and resources before placing too much."], ["Build chains", "Housing, food, raw materials, processing buildings, and storage must connect sensibly."], ["Watch balance", "A settlement can stall if one missing input blocks an entire chain."], ["Promote after proof", "Need new-game and early-production smoke screenshots."]],
        "status": [["Downloads", "Debian package set cached"], ["Service", "Client/multiplayer research"], ["Client launch", "Pending"], ["Next gate", "Early settlement smoke"]],
    },
    {
        "id": "pioneers-lan", "download_slug": "pioneers", "title": "Pioneers LAN Hub", "short_title": "Pioneers", "icon": "CATAN", "meta": "Native Board Game - Settlers-like", "description": "Offline Pioneers hub with Debian package set, Settlers-of-Catan-style rules, server notes, and LAN table proof path.", "tags": "Strategy,Board Game,Native", "categories": "strategy,multiplayer,family,casual,age-10-plus", "eyebrow": "Native board-game intake",
        "lede": "A Settlers of Catan-style board game for local play: gather resources, build roads and settlements, trade, and race for victory points.",
        "facts": ["Catan-like", "LAN/server", "Family strategy", "Small package set"], "source": "https://pio.sourceforge.net/", "packages": ["pioneers", "pioneers-console", "pioneers-data"],
        "docs": {"dest": "pioneers-site", "source_subdir": "pio.sourceforge.net", "pages": ["https://pio.sourceforge.net/", "https://pio.sourceforge.net/download.php", "https://pio.sourceforge.net/manual/"]},
        "cards": [["Why play", "This gives the LAN Arcade a slower social strategy game that does not require 3D hardware or twitch skill."], ["Offline plan", "Cache GUI, console/server, and data packages together so a local table can be hosted without internet."], ["Proof still needed", "Start a local game/server and confirm at least one client can join the table."]],
        "steps": [["Build settlements", "Use resource rolls to build roads, settlements, cities, and development cards."], ["Trade smart", "Trades can be better than waiting for perfect dice."], ["Block rivals", "Road placement and settlement positions shape the whole board."], ["LAN proof", "A two-client table smoke is required before promotion."]],
        "status": [["Downloads", "Debian package set cached"], ["Service", "Server/client pending"], ["Client launch", "Pending"], ["Next gate", "Join local table"]],
    },
    {
        "id": "flare-lan", "download_slug": "flare", "title": "Flare LAN Hub", "short_title": "Flare", "icon": "FLARE", "meta": "Native RPG - Action Adventure", "description": "Offline Flare hub with Debian package set, fantasy action-RPG guide, and first-character smoke target.", "tags": "RPG,Fantasy,Native", "categories": "rpg,action,adventure,fantasy,age-10-plus", "eyebrow": "Native RPG intake",
        "lede": "A fantasy single-player 2D action RPG with quests, loot, combat, skills, enemies, and a lightweight engine/data split.",
        "facts": ["2D action RPG", "Single-player", "Loot and quests", "Linux-first cache"], "source": "https://flarerpg.org/", "packages": ["flare-game", "flare-engine"],
        "docs": {"dest": "flare-site", "source_subdir": "flarerpg.org", "pages": ["https://flarerpg.org/", "https://flarerpg.org/index.php/download/", "https://flarerpg.org/index.php/guide/"]},
        "cards": [["Why play", "This fills a lightweight fantasy RPG slot without needing an MMO server."], ["Offline plan", "Cache the engine and game packages, then prove character creation and first combat."], ["Proof still needed", "Launch, enter a save, move around, and show a first area screenshot."]],
        "steps": [["Create hero", "Start with a simple build and learn movement/attacks."], ["Read quests", "NPCs and quest logs guide early progression."], ["Loot carefully", "Gear upgrades and skill choices define survivability."], ["Promote after play", "Need first-area gameplay proof, not just launcher proof."]],
        "status": [["Downloads", "Debian package set cached"], ["Service", "Not needed"], ["Client launch", "Pending"], ["Next gate", "First area smoke"]],
    },
    {
        "id": "openclonk-lan", "download_slug": "openclonk", "title": "OpenClonk LAN Hub", "short_title": "OpenClonk", "icon": "CLONK", "meta": "Native Action - Strategy Sandbox", "description": "Offline OpenClonk hub with Debian package set, action/strategy sandbox notes, and multiplayer proof path.", "tags": "Action,Strategy,Native", "categories": "action,strategy,multiplayer,simulation,age-10-plus", "eyebrow": "Native action-strategy intake",
        "lede": "A multiplayer game of strategy, action, and skill: dig, build, fight, use objects, and solve scenarios in a destructible side-view world.",
        "facts": ["Action strategy", "Destructible worlds", "Multiplayer", "Linux-first cache"], "source": "https://www.openclonk.org/", "packages": ["openclonk", "openclonk-data"],
        "docs": {"dest": "openclonk-site", "source_subdir": "www.openclonk.org", "pages": ["https://www.openclonk.org/", "https://www.openclonk.org/download/", "https://www.openclonk.org/docs/"]},
        "cards": [["Why play", "It is unusual in a good way: part platformer, part strategy, part physics sandbox, and potentially excellent for LAN chaos."], ["Offline plan", "Cache the Debian package set and test scenarios locally first."], ["Proof still needed", "Launch a scenario, move a clonk, interact with terrain/items, then test LAN hosting."]],
        "steps": [["Pick tutorial", "Start with tutorial/scenario content before multiplayer."], ["Use tools", "Digging, building, throwing, climbing, and object use are the core vocabulary."], ["Play scenarios", "The goal changes by scenario, so read the mission prompt."], ["LAN later", "Multiplayer proof needs two clients in the same scenario."]],
        "status": [["Downloads", "Debian package set cached"], ["Service", "Client-hosted LAN"], ["Client launch", "Pending"], ["Next gate", "Scenario smoke"]],
    },
    {
        "id": "supertux-lan", "download_slug": "supertux", "title": "SuperTux LAN Hub", "short_title": "SuperTux", "icon": "TUX", "meta": "Native Platformer - Family Arcade", "description": "Offline SuperTux hub with Debian package set, platformer guide, and first-level smoke target.", "tags": "Platformer,Family,Native", "categories": "arcade,platformer,family,casual,age-5-plus", "eyebrow": "Native platformer intake",
        "lede": "A classic 2D jump-and-run platformer with Tux, levels, enemies, collectibles, and family-friendly arcade pacing.",
        "facts": ["2D platformer", "Family friendly", "Single-player", "Linux-first cache"], "source": "https://www.supertux.org/", "packages": ["supertux", "supertux-data"],
        "docs": {"dest": "supertux-site", "source_subdir": "www.supertux.org", "pages": ["https://www.supertux.org/", "https://www.supertux.org/download.html", "https://github.com/SuperTux/supertux/wiki"]},
        "cards": [["Why play", "A safe, recognisable platformer is useful for kids, casual sessions, and weak hardware."], ["Offline plan", "Cache game and data packages now, then prove first-level movement."], ["Proof still needed", "Launch, enter a level, move/jump, and screenshot real gameplay."]],
        "steps": [["Run and jump", "Movement, timing, and enemy avoidance are the core controls."], ["Collect and explore", "Coins, powerups, and hidden routes reward patient play."], ["Use easier levels", "Start with early world levels for kids or first-time players."], ["Promote after proof", "Needs a first-level gameplay smoke."]],
        "status": [["Downloads", "Debian package set cached"], ["Service", "Not needed"], ["Client launch", "Pending"], ["Next gate", "First level smoke"]],
    },
    {
        "id": "pingus-lan", "download_slug": "pingus", "title": "Pingus LAN Hub", "short_title": "Pingus", "icon": "PING", "meta": "Native Puzzle - Lemmings-like", "description": "Offline Pingus hub with Debian package set, Lemmings-like puzzle guide, and first-puzzle smoke target.", "tags": "Puzzle,Strategy,Native", "categories": "puzzle,strategy,family,casual,age-10-plus", "eyebrow": "Native puzzle intake",
        "lede": "A free Lemmings-like puzzle game where you assign jobs to marching penguins and try to rescue enough of them before disaster wins.",
        "facts": ["Lemmings-like", "Puzzle strategy", "Family-friendly", "Linux-first cache"], "source": "https://pingus.seul.org/", "packages": ["pingus", "pingus-data"],
        "docs": {"dest": "pingus-site", "source_subdir": "pingus.seul.org", "pages": ["https://pingus.seul.org/", "https://pingus.seul.org/download.html"]},
        "cards": [["Why play", "It adds a thoughtful puzzle lane with a classic formula: limited tools, silly disasters, and lots of retrying."], ["Offline plan", "Cache game/data packages and explain the basic worker roles."], ["Proof still needed", "Launch a level, assign a role, and confirm the puzzle advances."]],
        "steps": [["Watch first", "Penguins walk automatically; observe before spending limited abilities."], ["Assign roles", "Diggers, blockers, builders, and other roles change the route."], ["Save enough", "You usually do not need to save everyone, just enough to pass."], ["Promote after proof", "Needs first-puzzle interaction smoke."]],
        "status": [["Downloads", "Debian package set cached"], ["Service", "Not needed"], ["Client launch", "Pending"], ["Next gate", "First puzzle smoke"]],
    },
    {
        "id": "lincity-ng-lan", "download_slug": "lincity-ng", "title": "LinCity-NG LAN Hub", "short_title": "LinCity-NG", "icon": "CITY", "meta": "Native Simulation - City Builder", "description": "Offline LinCity-NG hub with Debian package set, city-builder guide, and first-city smoke target.", "tags": "City Builder,Simulation,Native", "categories": "simulation,management,city-builder,strategy,age-10-plus", "eyebrow": "Native city-builder intake",
        "lede": "A city simulator where you build housing, industry, services, transport, power, and economy while trying to keep the city viable.",
        "facts": ["City builder", "Single-player", "Simulation", "Linux-first cache"], "source": "https://github.com/lincity-ng/lincity-ng/", "packages": ["lincity-ng", "lincity-ng-data"],
        "docs": {"dest": "lincity-ng-site", "source_subdir": "github.com/lincity-ng/lincity-ng", "pages": ["https://github.com/lincity-ng/lincity-ng", "https://github.com/lincity-ng/lincity-ng/wiki"]},
        "cards": [["Why play", "This gives us a lightweight city-building simulation without running a server."], ["Offline plan", "Cache game/data packages and write enough manual notes for a first city."], ["Proof still needed", "Launch, create a map, place early buildings, and show the city ticking."]],
        "steps": [["Start small", "Build a compact city rather than sprawling immediately."], ["Balance services", "Housing, jobs, food, power, roads, and pollution all matter."], ["Watch money", "A city can fail quietly through bad economics."], ["Promote after proof", "Needs first-city gameplay smoke."]],
        "status": [["Downloads", "Debian package set cached"], ["Service", "Not needed"], ["Client launch", "Pending"], ["Next gate", "First city smoke"]],
    },
    {
        "id": "crawl-tiles-lan", "download_slug": "crawl-tiles", "title": "Dungeon Crawl Stone Soup LAN Hub", "short_title": "Dungeon Crawl Stone Soup", "icon": "DCSS", "meta": "Native Roguelike - Dungeon Crawl", "description": "Offline Dungeon Crawl Stone Soup hub with Debian tiles package set, beginner guide, and first-dungeon smoke target.", "tags": "Roguelike,RPG,Native", "categories": "roguelite,rpg,fantasy,strategy,age-13-plus", "eyebrow": "Native roguelike intake",
        "lede": "A deep roguelike dungeon crawler with species, backgrounds, tactical combat, spells, gods, loot, and very educational deaths.",
        "facts": ["Roguelike", "Tiles UI", "Single-player", "Low server burden"], "source": "https://crawl.develz.org/", "packages": ["crawl-tiles", "crawl-common", "crawl-tiles-data"],
        "docs": {"dest": "crawl-site", "source_subdir": "crawl.develz.org", "pages": ["https://crawl.develz.org/", "https://crawl.develz.org/download.htm"]},
        "cards": [["Why play", "This is one of the best deep offline games for people who like systems, risk, and tactical problem-solving."], ["Offline plan", "Cache the tiles UI and shared data packages; terminal Crawl can be added later if desired."], ["Proof still needed", "Create a character, enter Dungeon:1, move, fight or explore, and screenshot the tiles UI."]],
        "steps": [["Pick simple start", "Minotaur Fighter or Gargoyle Fighter-style starts are kinder than fragile casters."], ["Fight one at a time", "Positioning and retreat matter more than bravado."], ["Use consumables", "Scrolls, potions, and wands are there to prevent deaths."], ["Promote after proof", "Needs first-dungeon gameplay smoke."]],
        "status": [["Downloads", "Debian package set cached"], ["Service", "Not needed"], ["Client launch", "Pending"], ["Next gate", "Dungeon:1 smoke"]],
    },
]

BY_ID = {game["id"]: game for game in BATCH_THREE}
BY_DOWNLOAD_SLUG = {game["download_slug"]: game for game in BATCH_THREE}
