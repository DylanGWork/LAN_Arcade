# Native Next Ten Queue - 2026-06-17

This queue prepares the next diverse native/offline intake after the first five-game batch (`teeworlds-ddnet-lan`, `hedgewars-lan`, `widelands-lan`, `warzone2100-lan`, `luanti-lan`). Do not treat these as playable until the normal gates pass: offline artifacts, hub QA, service/client smoke, join/play where relevant, and real-device smoke.

## Current Storage Snapshot

- VM root/web mirror filesystem: 295 GB total, about 148 GB free at the time of check.
- Current native download shelves: about 17 GB under `/var/www/html/mirrors/games/downloads/native/`.
- Largest current shelves: `zero-ad` 6.5 GB, `warzone2100` 3.4 GB, `widelands` 2.8 GB.
- Existing NFS mount found: `192.168.1.33:/mnt/tank/ZIM` mounted read-only at `/srv/kiwix/zims/content`, 12 TB class storage. This is KiWix-specific and should not be reused for LAN Arcade native clients.

## NFS Recommendation For Native Clients

Use NFS for bulky native release artifacts only:

```text
/var/www/html/mirrors/games/downloads/native/
```

Keep these local/in Git:

- `local-games/*-lan/index.html`
- small screenshots used by hub pages
- attribution/source notes
- QA scripts and smoke reports
- catalog metadata

Recommended future mount shape once a read-write export exists:

```text
NFS export: 192.168.1.33:/mnt/tank/LAN_Arcade/native-downloads
VM mount:   /srv/lan-arcade/native-downloads
Web path:   /var/www/html/mirrors/games/downloads/native
```

Safer migration pattern:

1. Create the read-write NFS export on the storage host.
2. Mount it at `/srv/lan-arcade/native-downloads` with `_netdev,nofail,x-systemd.automount`.
3. `rsync -aH --info=progress2 /var/www/html/mirrors/games/downloads/native/ /srv/lan-arcade/native-downloads/`.
4. Keep `/var/www/html/mirrors/games/downloads/native.local-backup` temporarily.
5. Bind mount or direct mount the NFS shelf at `/var/www/html/mirrors/games/downloads/native`.
6. Run local HTTP checks against existing known files before deleting the local backup.

This is not urgent before the next small intake, but it is the right direction before repeated multi-platform caches turn 17 GB into hundreds of GB.

## Proposed Next 10

| Priority | Game | Genre | Why next | Current upstream/package signal | Expected cache impact | First proof gate |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | SuperTuxKart | Kart racing | Family-friendly racing fills a big genre gap. Good garage-tier crowd game. | GitHub latest checked: 1.5 with Windows/Linux/macOS/Android assets; Debian has 1.4. | Large: common platform cache roughly 2.5-4 GB depending source inclusion. | VM launch screenshot, then local network race or split-screen proof. |
| 2 | Xonotic | Arena FPS | Proper Quake-style FPS and strong LAN shooter candidate. | Official download page exposes `xonotic-0.8.6.zip`, about 1.18 GB, plus small source zip. | Medium: single cross-platform ZIP is about 1.2 GB. | Server start/listen, client launch, then LAN join. |
| 3 | Red Eclipse | Arena FPS / parkour | More movement-heavy FPS option; Debian package exists. | Official download page exposes win/zip/nix/mac routes; Debian has 1.6.0. | Medium/large; verify final redirected asset sizes before caching. | Debian client launch, then server/join research. |
| 4 | OpenArena | Classic arena FPS | Smaller Quake III-style FPS lane, easier than some modern FPS assets. | Debian has `openarena` and `openarena-data`; installed-size data about 43 MB. | Small if Debian-package based; official assets need separate verification. | VM launch screenshot and bot match or local server smoke. |
| 5 | Freedoom + Chocolate Doom/PrBoom+ | Classic FPS / Doom-compatible | Fully free Doom-like content gives a safe retro FPS lane without commercial WADs. | Freedoom GitHub latest checked: 0.13.0, about 24 MB plus FreeDM about 11 MB; Debian packages available. | Small. | Launch with free WAD, start a level, screenshot. |
| 6 | BZFlag | 3D tank combat | Classic lightweight LAN multiplayer, different from normal FPS. | Debian has `bzflag`; upstream GitHub latest checked: 2.4.30. | Small/medium; Debian data is small, upstream packaging needs checking. | Server smoke, client launch, LAN join. |
| 7 | FreeOrion | Space 4X | Deeper strategy and space empire lane. | GitHub latest checked: v0.5.1.2; Windows/macOS/source assets around 150-190 MB each; Debian has older 0.4.10.2. | Medium: around 700 MB for common release files. | Client launch and tutorial/new-game proof. |
| 8 | Endless Sky | Space trading/combat RPG | Excellent offline solo game, low server complexity, broad appeal. | GitHub latest checked: v0.10.16 with Windows/macOS/Linux packages around 350-380 MB each; Debian has older 0.9.8. | Medium/large: 1.5-2.2 GB depending duplicate ZIP/installers. | Client launch, create pilot, enter first flight. |
| 9 | Cataclysm: Dark Days Ahead | Survival roguelike | Huge offline replay value, low server burden, very prepper-library aligned. | GitHub latest checked: stable 0.I Ito with Android/Linux/macOS/Windows assets; Debian has older 0.F. | Medium/large: 1-2 GB depending graphics/sounds variants. | Terminal or SDL launch, create survivor, start world. |
| 10 | The Mana World / ManaPlus | 2D MMORPG client | Keeps the MMO path moving without jumping straight to heavy 3D worlds. | Debian has `manaplus`; ManaPlus download page lists Windows, Android, macOS, Linux and source. | Unknown until HEAD/caching succeeds; likely small/medium. | Client launch first; local/private server path is separate research. |

## Alternates If One Blocks

- Armagetron Advanced: light-cycle multiplayer; official 0.2.9.3.0 downloads visible, Debian has 0.2.9.1.0.
- NetHack or Dungeon Crawl Stone Soup: excellent low-resource solo roguelike lane.
- OpenRA: tempting RTS, but asset/legal/offline packaging needs a separate decision before mirroring.
- Beyond All Reason: attractive RTS, but heavier and should wait until service/admin controls are better.

## Intake Notes

- Prefer a smaller useful cache first. For example, SuperTuxKart can start with Windows x64, Linux x86_64, macOS, Android, and source only if source is practical.
- Record Debian package versions separately from upstream release versions; they often differ.
- If NFS is not ready, this next batch can still fit on local disk, but do not keep expanding heavy multi-platform caches indefinitely on the VM root disk.
- For FPS/action games, do not promote from client launch to playable until a local server or bot/gameplay loop is proven.
