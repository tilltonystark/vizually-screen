#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH=/tmp/vizually-screen-module-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/tmp/vizually-screen-module-cache
swift build --product VizuallyScreen -c release --disable-sandbox --cache-path /tmp/vizually-screen-swift-cache --scratch-path .build
APP="$(pwd)/dist/Vizually Screen.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/VizuallyScreen "$APP/Contents/MacOS/VizuallyScreen"
cp -R .build/release/VizuallyScreen_VizuallyScreen.bundle "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>VizuallyScreen</string>
<key>CFBundleIdentifier</key><string>design.vizually.screen</string>
<key>CFBundleName</key><string>Vizually Screen</string>
<key>CFBundleDisplayName</key><string>Vizually Screen</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.7.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Record the display you select to create a video demo.</string>
</dict></plist>
PLIST
# A stable developer identity avoids invalidating broad TCC grants on each build.
# Native source picking remains available for ad-hoc local builds.
codesign --force --sign "${VIZUALLY_SCREEN_SIGNING_IDENTITY:--}" "$APP"
printf 'Built %s\n' "$APP"
