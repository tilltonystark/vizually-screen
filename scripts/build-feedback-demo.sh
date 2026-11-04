#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH=/tmp/vizually-screen-module-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/tmp/vizually-screen-module-cache
swift build --package-path Examples/FeedbackDemo --disable-sandbox --cache-path /tmp/vizually-screen-swift-cache --scratch-path /tmp/vizually-feedback-consumer-build
DEMO_APP="$(pwd)/dist/Feedback Demo.app"
mkdir -p "$DEMO_APP/Contents/MacOS"
cp /tmp/vizually-feedback-consumer-build/debug/FeedbackDemo "$DEMO_APP/Contents/MacOS/FeedbackDemo"
cat > "$DEMO_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FeedbackDemo</string>
<key>CFBundleIdentifier</key><string>design.vizually.feedback-demo</string>
<key>CFBundleName</key><string>Feedback Demo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.7.0</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$DEMO_APP"
printf 'Built %s\n' "$DEMO_APP"
