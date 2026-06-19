# Emulator Library Plan

Bulk emulator collections should not flood the main arcade grid. Keep the main
catalog as the curated Steam-like shelf, then use one catalog card to link into
separate emulator libraries.

Current private shelf:

```text
/mirrors/private-rom-vault/
```

Future shelves can follow the same pattern:

```text
/mirrors/emulators/game-boy/
/mirrors/emulators/game-boy-advance/
/mirrors/emulators/playstation/
/mirrors/emulators/nintendo-64/
```

## Build The Private Vault

The private archive stays on the VM and is not committed to Git:

```text
/home/dylan/LAN_Arcade/tmp/private-rom-intake/gbc-smdb-2022-05-12.zip
```

Build the searchable vault page and dynamic EmulatorJS launcher:

```sh
npm run rom:vault:build
```

Useful profiles:

```sh
python3 scripts/build_private_rom_vault.py --profile selected
python3 scripts/build_private_rom_vault.py --profile english
python3 scripts/build_private_rom_vault.py --profile all
python3 scripts/build_private_rom_vault.py --profile selected --limit 50
python3 scripts/build_private_rom_vault.py --profile selected --dry-run
```

- `selected`: English-friendly, deduplicated, skips tools/test carts and obvious
  problem variants. Use this for the normal shelf.
- `english`: English-friendly, less aggressively deduplicated.
- `all`: every `.gb`, `.gbc`, and `.gba` file from the archive.

## No-AI Smoke Testing

Run samples or full unattended passes without spending AI tokens:

```sh
npm run rom:vault:smoke -- --limit 25 --screenshots one
npm run rom:vault:smoke -- --run-id full-20260619 --screenshots one
npm run rom:vault:smoke -- --run-id full-20260619 --resume --screenshots one
```

The runner captures the `#game` element and scores the PNG screenshots for
visual entropy. Do not use WebGL `canvas.getImageData()` as the pass/fail signal
for EmulatorJS, because Chromium can read back a black buffer while the browser
screenshot clearly shows gameplay.
