#!/bin/sh
set -eu

DATA_DIR=${1:-/var/www/html/mirrors/emulatorjs-runtime/4.2.3/data}

if [ ! -d "$DATA_DIR" ]; then
  echo "EmulatorJS data directory not found: $DATA_DIR" >&2
  exit 1
fi

python3 - "$DATA_DIR" <<'PYINNER'
from pathlib import Path
import sys

data = Path(sys.argv[1])
replacements = [
    (
        'if (this.debug || (window.location && ["localhost", "127.0.0.1"].includes(location.hostname))) this.checkForUpdates();',
        'if (this.debug && window.EJS_allowUpdateCheck === true) this.checkForUpdates();',
    ),
    (
        '(this.debug||window.location&&["localhost","127.0.0.1"].includes(location.hostname))&&this.checkForUpdates()',
        'this.debug&&window.EJS_allowUpdateCheck===true&&this.checkForUpdates()',
    ),
]
for rel in ['src/emulator.js', 'emulator.min.js']:
    target = data / rel
    if not target.exists():
        continue
    text = target.read_text(errors='replace')
    patched = text
    for old, new in replacements:
        patched = patched.replace(old, new)
    if patched != text:
        target.write_text(patched)
        print(f'patched {target}')

localization = data / 'localization'
en_us = localization / 'en-US.json'
en_gb = localization / 'en-GB.json'
if en_us.exists() and not en_gb.exists():
    en_gb.write_bytes(en_us.read_bytes())
    print(f'created {en_gb}')
PYINNER
