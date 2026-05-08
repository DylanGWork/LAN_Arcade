# LAN Arcade Companion

The companion app is a shared web/PWA and Android APK shell for the LAN Arcade.
It connects to a local API server, launches existing LAN-hosted browser games,
and includes bundled app-only games.

## What Exists Now

- `apps/companion`: Vite + React + Capacitor app.
- `services/arcade-api`: Node HTTP + SQLite API.
- `packages/shared`: shared catalog/profile/score contracts.
- `Camp Colony`: bundled turn-based base-builder with seeded challenge scores.
- `Trailguard TD`: bundled Phaser tower defense game with seeded challenges and score submission.
- `Number Splash`: bundled kid-friendly counting score game.
- `Mindustry LAN Server`: Pi-hosted native multiplayer server support, exposed as a companion service card.
- `Unciv LAN Server`: Pi-hosted turn-file server for Android/desktop Unciv clients.

## APK Download Flow

The APK handoff follows the same practical idea as the PestSense WiFi provisioning
app: keep the latest debug APK in a predictable place, and publish it to the LAN
server downloads page for phones.

Repo artifact:

```text
releases/android/lan-arcade-companion-debug.apk
```

Offline LAN URL after setup:

```text
http://<server-ip>/mirrors/games/downloads/lan-arcade-companion-debug.apk
```

Downloads landing page:

```text
http://<server-ip>/mirrors/games/downloads/
```

Android app server URL:

```text
http://<server-ip>/arcade-api/
```

Screenshots committed for GitHub README and the offline wiki:

```text
docs/assets/companion-catalog.png
docs/assets/companion-trailguard.png
docs/assets/companion-unciv-service.png
docs/assets/companion-mindustry-service.png
```

![Companion catalog](assets/companion-catalog.png)

![Trailguard TD](assets/companion-trailguard.png)

![Unciv LAN Server](assets/companion-unciv-service.png)

## Local Development

Install dependencies:

```sh
npm install
```

Run API:

```sh
ARCADE_API_HOST=127.0.0.1 \
ARCADE_API_PORT=3100 \
LAN_ARCADE_DB_PATH=/tmp/lan-arcade.sqlite \
LAN_ARCADE_CATALOG_PATH=/var/www/html/mirrors/games/catalog.json \
LAN_ARCADE_FILTERS_PATH=/var/www/html/mirrors/games/admin.filters.json \
npm run dev:api
```

Run companion app:

```sh
npm run dev:companion
```

Open:

```text
http://127.0.0.1:5173/
```

For Vite dev, set the app server field to:

```text
http://127.0.0.1:3100/
```

For Android emulator, use:

```text
http://10.0.2.2:3100/
```

When deployed behind nginx at `/arcade-api/`, use:

```text
http://<server-ip>/arcade-api/
```

## API Behind Nginx

Run the API container on the same Docker network as `webserver`, mount the arcade files and database path, then proxy it:

Example files:

```text
deploy/lan-arcade-api.compose.yml
deploy/nginx-arcade-api-location.conf
```

```nginx
location ^~ /arcade-api/ {
    allow 127.0.0.1;
    allow 10.0.0.0/8;
    allow 172.16.0.0/12;
    allow 192.168.0.0/16;
    deny all;

    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_pass http://lan-arcade-api:3100/;
}
```

The API reads:

```text
/var/www/html/mirrors/games/catalog.json
/var/www/html/mirrors/games/admin.filters.json
```

It writes:

```text
/var/lib/lan-arcade/lan-arcade.sqlite
/var/www/html/mirrors/games/admin.filters.json
```

## QA

Unit and build checks:

```sh
npm test
npm run build
```

Companion PWA smoke:

```sh
npm run qa:companion
```

This smoke test starts a temporary API and Vite app, creates a profile, verifies the app catalog, opens `Camp Colony`, submits a score, opens the `Mindustry LAN Server` and `Unciv LAN Server` service cards, then opens `Trailguard TD`, plays a shortened smoke wave, submits a score, and writes screenshots:

```text
qa/reports/companion/summary.json
qa/reports/companion/companion-catalog.png
qa/reports/companion/companion-camp-colony.png
qa/reports/companion/companion-mindustry-service.png
qa/reports/companion/companion-unciv-service.png
qa/reports/companion/companion-trailguard.png
```

API container load smoke:

```text
Image size:                  about 214 MB
Idle container memory:       about 35-43 MiB
After 1000 mixed requests:   about 45 MiB
Request result:              1000/1000 OK
Raw report:                  qa/reports/strategy-spike/arcade-api-load.json
```

## Pi-Hosted Bigger Games

The companion now has two native LAN service entries:

- `Mindustry LAN Server` - a Raspberry Pi hosts the dedicated server on port `6567`; Android and desktop clients connect directly.
- `Unciv LAN Server` - a Raspberry Pi hosts the turn-file server on port `8090`; Android and desktop Unciv clients connect directly.

The setup script now prints a device-memory suitability check. It does not block
the browser arcade install, but it warns when the box is too small for the
larger service experiments:

- under 2 GB RAM: keep to the browser arcade
- 2-4 GB RAM: try only conservative Unciv/Mindustry settings
- 4-8 GB RAM: run one bigger LAN service at a time
- 8 GB+ RAM: suitable for broader service trials, while Freeciv-web remains experimental

Setup notes live in:

```text
docs/MINDUSTRY_SERVER.md
docs/UNCIV_SERVER.md
deploy/mindustry.compose.yml
deploy/unciv.compose.yml
```

## Android

The Capacitor Android project exists at:

```text
apps/companion/android/
```

Current VM status:

- A user-local Android SDK is installed at `/home/dylan/android-sdk`.
- A user-local JDK is installed at `/home/dylan/jdks/temurin-17`.
- `adb` and `emulator` are installed under `/home/dylan/android-sdk`.
- KVM is available.
- The `dylan` user is not currently in the `kvm` group, so Android emulator acceleration is blocked.
- Debug APK build succeeds.

Latest debug APK path:

```text
apps/companion/android/app/build/outputs/apk/debug/app-debug.apk
releases/android/lan-arcade-companion-debug.apk
```

Fresh VM SDK/JDK setup:

```sh
scripts/setup_android_sdk.sh
```

APK build and copy into `releases/android/`:

```sh
scripts/build_companion_apk.sh
```

Copy the APK into the LAN Arcade downloads folder:

```sh
scripts/publish_companion_apk.sh
```

Manual build command:

```sh
export JAVA_HOME=/home/dylan/jdks/temurin-17
export ANDROID_HOME=/home/dylan/android-sdk
export ANDROID_SDK_ROOT=/home/dylan/android-sdk
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

npm run cap:sync -w @lan-arcade/companion
cd apps/companion/android
./gradlew assembleDebug
```

The app allows cleartext HTTP so phones can talk to a local camping server without HTTPS.

To enable emulator runs on this VM, add the user to the `kvm` group and start a
new login session:

```sh
sudo gpasswd -a dylan kvm
```

After that, install an Android system image, create an AVD, and run the APK with
`adb install`. This step was not completed because the current shell cannot use
`sudo` and cannot access `/dev/kvm`.

## Current Limits

- Real-time multiplayer is not implemented yet.
- V1 multiplayer is asynchronous score competition through shared challenge seeds.
- Existing mirrored games can launch from the companion, but only games with adapters submit scores.
- Native LAN service cards can guide players to an external client, but they are not browser games and are not launched inside the companion.
- npm audit still flags dev-tool issues in Capacitor 6 CLI and Vite 5 on Node 18. The available clean upgrades move toward Node 20+ tooling, so this VM keeps Node 18-compatible versions for now.
