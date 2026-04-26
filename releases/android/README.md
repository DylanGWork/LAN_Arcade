# Android Release Artifacts

This directory holds the current debug APK for easy GitHub download.

```text
lan-arcade-companion-debug.apk
```

For a fresh APK:

```sh
scripts/setup_android_sdk.sh
scripts/build_companion_apk.sh
```

For LAN-local download on the Raspberry Pi:

```sh
scripts/publish_companion_apk.sh
```

The setup script also copies this APK automatically into
`/var/www/html/mirrors/games/downloads/` when `sudo ./setup_lan_arcade.sh` is run
and the APK exists in this directory.
