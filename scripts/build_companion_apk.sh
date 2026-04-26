#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
JAVA_HOME="${JAVA_HOME:-$HOME/jdks/temurin-17}"
APK_SOURCE="$ROOT_DIR/apps/companion/android/app/build/outputs/apk/debug/app-debug.apk"
APK_DEST="$ROOT_DIR/releases/android/lan-arcade-companion-debug.apk"

if [ ! -x "$JAVA_HOME/bin/jlink" ] || [ ! -x "$ANDROID_HOME/platform-tools/adb" ]; then
  echo "Android SDK/JDK not found. Run scripts/setup_android_sdk.sh first." >&2
  exit 1
fi

export JAVA_HOME
export ANDROID_HOME
export ANDROID_SDK_ROOT
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

cd "$ROOT_DIR"
npm run cap:sync -w @lan-arcade/companion
(cd apps/companion/android && ./gradlew assembleDebug)

mkdir -p "$(dirname "$APK_DEST")"
cp "$APK_SOURCE" "$APK_DEST"
chmod 644 "$APK_DEST"

echo "APK copied to $APK_DEST"
