# Official Site And Wiki Mirroring

Use `scripts/mirror_game_docs.py` for game websites, wikis, manuals, and official guide pages that should be browsable without internet.

The script replaces the older one-off wget snippets with a safer standard workflow:

- stage the wget output in `/tmp` first;
- publish only under `/var/www/html/mirrors/<dest>`;
- refuse destinations outside the mirror root;
- keep one `.backup-before-refresh` directory before replacing an existing mirror;
- convert links and fetch page requisites;
- strip common tracker/font/search-widget references from HTML;
- generate a root `index.html` when wget lands pages in nested folders;
- write `LAN_ARCADE_SOURCE.txt` and `LAN_ARCADE_OFFLINE_PATCH.txt`;
- write JSON reports under `qa/reports/...` when `--report` is supplied.

## External Media Repair Rule

After saving an official site or wiki, scan the deployed copy for remote media URLs. Images, CSS assets, and font files that still point to the internet break the off-grid promise even when the page itself loads. Use the repair helper for existing mirrors:

```bash
python3 scripts/repair_mirror_external_media.py \
  --mirror-root /var/www/html/mirrors/0ad/play0ad.com \
  --report qa/reports/docs-mirror/zero-ad-external-media-repair.json
```

Remaining external links to official source pages can be acceptable when they are clearly labelled as internet/original links. Remaining external media loads are not acceptable for a promoted offline website/manual.

## Recipe-Based Usage

Recipes live in `config/site-mirror-recipes.json`.

Validate an existing mirror without network:

```bash
python3 scripts/mirror_game_docs.py \
  --recipe config/site-mirror-recipes.json \
  --slug openttd-wiki \
  --validate-only \
  --report qa/reports/docs-mirror/openttd-validate.json
```

Repair an existing mirror without network:

```bash
python3 scripts/mirror_game_docs.py \
  --recipe config/site-mirror-recipes.json \
  --slug mindustry-docs \
  --repair-existing \
  --report qa/reports/docs-mirror/mindustry-repair.json
```

Refresh a mirror from the internet:

```bash
python3 scripts/mirror_game_docs.py \
  --recipe config/site-mirror-recipes.json \
  --slug openttd-wiki \
  --report qa/reports/docs-mirror/openttd-refresh.json
```

## One-Off Usage

```bash
python3 scripts/mirror_game_docs.py \
  --title "Example Game Manual" \
  --dest example-game-docs \
  --source-subdir example.org \
  --level 2 \
  --page https://example.org/manual/
```

## Promotion Rule

A game hub can link to a mirrored official site/wiki/manual when:

- `/mirrors/<dest>/` returns 200;
- the mirror has at least one HTML page and a root `index.html`;
- visible pages explain what the game is and how to play/connect;
- common external tracker/font references are absent or non-blocking;
- the hub also has a short local quick-start in case the mirrored site is large or awkward.

Do not treat a successful wget as gameplay proof. It only satisfies the offline information/manual part of intake.

## Player-Facing Link Rule

Do not call these pages `mirrors` on public player pages. Use labels such as:

- `Open offline website`
- `Open guides`
- `Manuals and help`
- `Official page and licensing`

The operator/admin docs can still use `mirror` because that is the technical implementation.

## Full-Flow Boundary

A working offline website/wiki proves only that help content is available without internet. It does not prove the game can be installed, launched, joined, or played. Promotion still requires gameplay QA evidence.
