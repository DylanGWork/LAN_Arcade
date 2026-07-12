# Pillage First Release Integration

Pillage First source is owned by the standalone repository at
`/home/dylan/Pillage-First-LAN`. LAN Arcade consumes a pinned, verified static
release. It must not regenerate the game by applying an expanding patch script.

The pinned release is declared in `config/pillage-first-release.json`.
`scripts/stage_pillage_first_release.sh` verifies archive hashes, every static
file hash, the source commit, and the configured base path before copying files
to a non-live staging directory.

The staging command refuses `/var/www` outputs. A live deployment is a
separate, deliberate operation. The preferred cutover gate remains that
Dylan's `s-dd7a` world has:

1. been exported from Chrome Profile 2 on `https://192.168.1.106`;
2. been retained in two verified copies; and
3. passed an import and gameplay drill in a disposable browser profile.

On 2026-07-12 Dylan explicitly authorized release `62fa096408d1` to go live
without first exporting the browser-local world. The deployment therefore used
an additive static swap: the previous tree was backed up, every old hashed
asset was carried into the new tree, and only static application files changed.
No OPFS data or live world was opened by the deployment. Both the ordinary
create-world smoke and the Hero-to-Resources route-transition regression passed
after cutover. This is safer for an already-open tab, but it does not replace a
real export/restore drill for `s-dd7a`.

The historical `scripts/build_pillage_first_mirror.sh` remains only as
migration evidence. Do not use it for new builds. Build releases in the
standalone repository, then update the pinned commit and release path here
after review.

Runtime truth:

- launcher type: static browser game;
- account requirement: none;
- save location: browser OPFS, scoped by scheme, host, port, and profile;
- automatic internet dependency: none in the verified create-world flow; and
- central/account-portable saves: not implemented.
