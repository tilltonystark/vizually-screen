#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH=/tmp/framecraft-module-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/tmp/framecraft-module-cache
swift build --product Framecraft -c release --disable-sandbox --cache-path /tmp/framecraft-swift-cache --scratch-path .build
APP="$(pwd)/dist/Framecraft.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Framecraft "$APP/Contents/MacOS/Framecraft"
cp -R .build/release/Framecraft_Framecraft.bundle "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Framecraft</string>
<key>CFBundleIdentifier</key><string>design.vizually.framecraft</string>
<key>CFBundleName</key><string>Framecraft</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Record the display you select to create a video demo.</string>
</dict></plist>
PLIST
# A stable developer identity avoids invalidating broad TCC grants on each build.
# Native source picking remains available for ad-hoc local builds.
codesign --force --sign "${FRAMECRAFT_SIGNING_IDENTITY:--}" "$APP"
printf 'Built %s\n' "$APP"
