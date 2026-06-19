# Source Notes

Created: 2026-06-19

Use this file to track discovery sources, useful search terms, and source-level
rules for future game intake batches.

## Initial Sources

### My Abandonware

- URL: `https://www.myabandonware.com/`
- Use: discovery, historical metadata, platform filtering, candidate names.
- Rule: do not treat abandonware availability as redistribution permission.
- Good candidate buckets to investigate: tycoon/management games, city builders,
  4X/strategy games, DOS/Windows classics, demos/shareware/freeware releases,
  and titles where rights-holder redistribution is explicit.
- Default status for unclear commercial full games: `legal-review`.

## Search Terms To Try

- `freeware tycoon game`
- `open source tycoon game`
- `shareware strategy game dos`
- `public domain dos game`
- `source port sim game open source`
- `classic strategy game freeware release`
- `LAN multiplayer old game open source`

## Notes For Future Agents

- Keep candidate notes small and commit-friendly.
- Put cached large files on `/srv/lan-arcade/native-downloads/intake/`.
- Put private Dylan-provided files on a private VM-local shelf and label them
  private; do not push those files to GitHub.
- A game is not playable until a no-internet smoke test reaches a real gameplay
  or setup state with screenshots/log evidence.

## 2026-06-19 Ranked Candidate Pass

Updated `candidates.csv` with a first ranked queue. This pass prioritized:

- ScummVM freeware games with Debian bookworm packages or official ScummVM
  checksummed downloads.
- Debian bookworm `main` packages where the offline cache path is practical and
  redistributable through normal package metadata.
- Official open-source project pages for promising games that are not already
  in the LAN Arcade catalog.
- A small legal-review lane from My Abandonware as discovery only.

Useful source links checked:

- ScummVM freeware games: `https://www.scummvm.org/games/`
- Debian package metadata from the GannanNet VM: `apt-cache policy/show`
- Naev: `https://naev.org/`
- Colobot: `https://colobot.info/`
- OpenRA download/legal notes: `https://www.openra.net/download/`
- Tuxemon: `https://tuxemon.org/`
- Pioneer Space Sim: `https://pioneerspacesim.net/page/download/`
- Aleph One: `https://alephone.lhowon.org/`
- OpenTyrian: `https://github.com/opentyrian/opentyrian`
- My Abandonware discovery pages for Theme Hospital, SimTower, The Incredible
  Machine, and SimCity 2000.

Important findings:

- The current public catalog already includes many obvious native/open-source
  games such as OpenTTD, Freeciv, Wesnoth, FreeCol, Stendhal, SuperTuxKart,
  Xonotic, Red Eclipse, OpenArena, Freedoom, BZFlag, FreeOrion, Endless Sky,
  Cataclysm DDA, ManaPlus, Armagetron Advanced, MegaGlest, Unknown Horizons,
  Pioneers, Flare, OpenClonk, SuperTux, Pingus, LinCity-NG, and Crawl Tiles.
- ScummVM is a strong next pipeline because several games are freeware and also
  packaged in Debian (`beneath-a-steel-sky`, `flight-of-the-amazon-queen`,
  `lure-of-the-temptress`, `drascula`).
- OpenRA is high-interest but should stay `legal-review`: the engine is GPL, but
  the official download page states the mods need original game files under
  separate C&C franchise modding guidelines.
- Aleph One and OpenTyrian are high-interest but also stay `legal-review` until
  game-data redistribution terms are accepted.
- My Abandonware rows are discovery-only. Do not download/cache public binaries
  unless rights are clear or Dylan supplies private files for a private shelf.

## 2026-06-19 Tycoon And City Builder Sweep

Focused search for tycoon, transport, theme-park, and SimCity-style games.

Already covered in the public catalog:

- `openttd-lan`
- `lincity-ng-lan`
- `unknown-horizons-lan`
- `widelands-lan`
- `freecol-lan`
- `zero-ad-lan`
- `pioneers-lan`

Best new public-cache candidates:

- Simutrans: open-source transport/logistics sim; Debian bookworm has
  `simutrans`, `simutrans-data`, and `simutrans-pak64`.
- Micropolis: Debian packages describe it as the GPL-licensed version of
  SimCity; strong legal answer for classic SimCity-style play.
- OpenCity: small GPL 3D city builder in Debian; probably dated, but easy to
  smoke.
- FreeRCT: open-source RollerCoaster Tycoon-like game; Flathub lists 0.1 as
  playable but early alpha.
- Cytopia: open-source retro city builder on itch/GitHub; promising but needs
  a real gameplay smoke and offline/mod-download check.

Private/legal-review candidates:

- OpenRCT2: engine is open source, but official docs say RCT2/RCT Classic object
  files are required.
- OpenLoco: engine is open source, but the project says original Locomotion
  asset files are required.
- Julius/Augustus for Caesar III: open-source engines, but both require original
  Caesar III assets.
- Transport Tycoon Deluxe, Railroad Tycoon II, Pharaoh, SimTower, Theme
  Hospital, and SimCity 2000: use My Abandonware as discovery only unless Dylan
  supplies owned/private files.

Useful links checked:

- Simutrans: `https://simutrans.net/index.html.en`
- Micropolis Debian: `https://packages.debian.org/bookworm/micropolis`
- OpenCity Debian: `https://packages.debian.org/bookworm/opencity`
- FreeRCT: `https://freerct.net/` and
  `https://flathub.org/en/apps/net.freerct.FreeRCT`
- Cytopia: `https://cytopia.itch.io/cytopia` and
  `https://github.com/CytopiaTeam/Cytopia`
- OpenRCT2 data requirement:
  `https://docs.openrct2.io/en/latest/installing/getting-rct2.html`
- CorsixTH data requirement: `https://corsixth.com/`
- OpenLoco data requirement: `https://github.com/OpenLoco/OpenLoco`
- Julius/Augustus data requirement:
  `https://github.com/bvschaik/julius` and
  `https://github.com/Keriew/augustus`

Follow-up handoff:

- `game-intake/private-tycoon-acquisition-2026-06-19.md` records the private
  acquisition queue, storage rules, manifest expectations, and pass/fail gates
  for SimCity 2000, Railroad Tycoon II, Pharaoh, Theme Hospital, SimTower,
  Caesar III, OpenRCT2, OpenLoco, and Transport Tycoon Deluxe.

Stricter acquisition follow-up:

- `game-intake/tycoon-downloadability-sweep-2026-06-19.md` and
  `game-intake/tycoon-downloadability-sweep-2026-06-19.csv` separate pages with
  visible free full-game downloads from pages that only point to GOG/Steam or
  offer extras/demo/manual files. Use this newer sweep before asking another
  agent to download or test classic tycoon games.

Popular classics follow-up:

- `game-intake/classic-downloadability-sweep-2026-06-19.md` and
  `game-intake/classic-downloadability-sweep-2026-06-19.csv` record 100
  actionable classic/open-alternative candidates across racing, Tony Hawk-style
  sports, GTA-era driving/action, management/tycoon, puzzle, RTS, and open
  clone/source-port lanes. Most commercial rows remain private-only and must be
  rechecked one at a time before acquisition.

Yearly popularity follow-up:

- `game-intake/yearly-top-games-2000-2016-acquisition-sweep.md` and
  `game-intake/yearly-top-games-2000-2016-acquisition-sweep.csv` record a
  170-row top-10-per-year seed list from Wikipedia year-in-video-games review
  score tables, then annotate each row with a conservative acquisition lane.
  This is useful for research direction, but most top-rated rows are console
  private-media-only or modern commercial/store-only, not immediate download
  tasks.

## 2026-06-19 Private DOS Source Cache Audit

The NFS-backed private source shelf at `/srv/lan-arcade/native-downloads` is
currently mounted but empty. The generated `/mirrors/private-dos-vault` shelf was
left with metadata/screenshots only, and `npm run dos:vault:build` now fails
closed instead of wiping or publishing a no-package rebuild when source files are
missing.

Restore or reacquire `/srv/lan-arcade/native-downloads/intake/private-tycoon/*`
before claiming browser-playable DOS packages. Historical smoke notes remain
useful, but current live status is restore-needed.
