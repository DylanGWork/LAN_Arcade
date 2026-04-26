#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
JDK_HOME="${JDK_HOME:-$HOME/jdks/temurin-17}"
CMDLINE_TOOLS_URL="${CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip}"
TEMURIN_17_URL="${TEMURIN_17_URL:-https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse}"

need_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

need_tool curl
need_tool tar
need_tool unzip

mkdir -p "$ANDROID_HOME/cmdline-tools" "$HOME/jdks"

if [ ! -x "$JDK_HOME/bin/jlink" ]; then
  echo "Installing local Temurin JDK 17 to $JDK_HOME"
  tmp_jdk="$(mktemp -d)"
  tmp_tar="$(mktemp)"
  curl -fL --retry 3 -o "$tmp_tar" "$TEMURIN_17_URL"
  rm -rf "$JDK_HOME"
  mkdir -p "$JDK_HOME"
  tar -xzf "$tmp_tar" -C "$JDK_HOME" --strip-components=1
  rm -rf "$tmp_jdk" "$tmp_tar"
fi

if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "Installing Android command line tools to $ANDROID_HOME"
  tmp_dir="$(mktemp -d)"
  tmp_zip="$(mktemp)"
  curl -fL --retry 3 -o "$tmp_zip" "$CMDLINE_TOOLS_URL"
  unzip -q "$tmp_zip" -d "$tmp_dir"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mv "$tmp_dir/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$tmp_dir" "$tmp_zip"
fi

export JAVA_HOME="$JDK_HOME"
export ANDROID_HOME
export ANDROID_SDK_ROOT
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/tmp/lan-arcade-android-sdk-licenses.log
sdkmanager --sdk_root="$ANDROID_HOME" \
  "platform-tools" \
  "platforms;android-34" \
  "build-tools;34.0.0" \
  "emulator"

cat > "$ROOT_DIR/apps/companion/android/local.properties" <<EOF
sdk.dir=$ANDROID_HOME
EOF

echo
echo "Android SDK ready."
echo "JAVA_HOME=$JAVA_HOME"
echo "ANDROID_HOME=$ANDROID_HOME"
echo "For this shell, run:"
echo "  export JAVA_HOME=\"$JAVA_HOME\""
echo "  export ANDROID_HOME=\"$ANDROID_HOME\""
echo "  export ANDROID_SDK_ROOT=\"$ANDROID_HOME\""
echo "  export PATH=\"\$JAVA_HOME/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$PATH\""
