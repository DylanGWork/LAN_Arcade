# Native Batch Three Intake - 2026-06-19

This intake adds ten more larger/native games to the LAN Arcade catalog. These are offline hub entries with local Debian package shelves on the native-downloads NFS mount. They are not yet promoted to full gameplay-proof status; the next gate is native client launch and real play/join smoke per title.

## Games Added

- `armagetronad-lan` - Armagetron Advanced light-cycle arena
- `megaglest-lan` - MegaGlest fantasy RTS
- `unknown-horizons-lan` - Unknown Horizons settlement economy strategy
- `pioneers-lan` - Pioneers Catan-like board game
- `flare-lan` - Flare single-player action RPG
- `openclonk-lan` - OpenClonk action/strategy sandbox
- `supertux-lan` - SuperTux family platformer
- `pingus-lan` - Pingus Lemmings-like puzzle game
- `lincity-ng-lan` - LinCity-NG city builder
- `crawl-tiles-lan` - Dungeon Crawl Stone Soup tiles roguelike

## Offline Download Shelves

Package closures are cached outside Git on the NFS shelf:

```text
/srv/lan-arcade/native-downloads/<slug>/
/var/www/html/mirrors/games/downloads/native/<slug>/
```

Current batch shelf sizes:

| Shelf | Packages | Size |
| --- | ---: | ---: |
| `armagetronad` | 85 | 61M |
| `megaglest` | 216 | 372M |
| `unknown-horizons` | 161 | 334M |
| `pioneers` | 151 | 86M |
| `flare` | 98 | 152M |
| `openclonk` | 167 | 223M |
| `supertux` | 141 | 243M |
| `pingus` | 126 | 87M |
| `lincity-ng` | 134 | 122M |
| `crawl-tiles` | 105 | 78M |

Resource check after the batch:

```text
/dev/vda2 root: 295G total, 152G used, 131G free, 54% used
native-downloads NFS: 11T total, 29G used, 11T free, 1% used
```

The batch added roughly 1.8 GB to NFS and did not materially move the VM root disk.

## Source Site And Manual Mirrors

Each hub has curated player-facing notes, install/offline status, and next QA gates. Recursive upstream docs mirroring is still uneven. The following official-site mirror endpoints currently exist, but most are blocker pages created deliberately when wget returned an upstream error or timed out:

```text
/mirrors/armagetronad-site/
/mirrors/megaglest-site/
/mirrors/unknown-horizons-site/
/mirrors/pioneers-site/
/mirrors/flare-site/
/mirrors/openclonk-site/
/mirrors/supertux-site/
/mirrors/pingus-site/
/mirrors/lincity-ng-site/
/mirrors/crawl-site/
```

Do not treat a blocker page as a complete manual mirror. Replace blockers with narrower official manual/wiki captures or packaged docs as follow-up work.

## QA Evidence

Safe regeneration command used:

```bash
ARCADE_NAME="GannanNet" LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 LAN_ARCADE_SKIP_ADMIN_AUTH=1 LAN_ARCADE_SKIP_MIRROR=1 LAN_ARCADE_CATALOG_SOURCE=metadata-existing bash ./setup_lan_arcade.sh
```

Static audit after deployment:

```text
Games scanned: 110
OK: 110
Needs attention: 0
Games with external dependency refs in entry HTML: 0
```

Per-game desktop and mobile hub smoke passed for all 10 using:

```bash
bash scripts/qa_game_regression.sh <game-id>
```

Reports were written under:

```text
qa/reports/game-regression/<game-id>-20260618T15*.Z-desktop/
qa/reports/game-regression/<game-id>-20260618T15*.Z-mobile/
```

The VM clock/report timestamps are UTC; the local work date was 2026-06-19 Australia/Brisbane.

## Known Limits

- These tests prove hub quality, local page/assets, external-request blocking, and the presence of package manifests.
- They do not prove each native client launches, creates a game/world, joins LAN, or survives real offline play.
- Debian package closures are Linux-first. Windows/macOS installers are not yet cached for this batch.
- Heavy service tests should still run one at a time and stop after smoke.
- `supertasball` still emits an existing catalog warning during regeneration because no HTML entrypoint is present.

## Next Gates

1. Add these 10 IDs to a native client launch smoke script where practical.
2. Start with lightweight client proof: SuperTux, Pingus, Armagetron Advanced, Pioneers.
3. Then test heavier client/gameplay proof: MegaGlest skirmish, Unknown Horizons first settlement, OpenClonk tutorial/scenario, LinCity-NG first city, Flare first area, DCSS first dungeon.
4. For multiplayer-capable titles, only promote after a local host/join or two-client proof.
