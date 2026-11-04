#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH=/tmp/vizually-screen-module-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/tmp/vizually-screen-module-cache
# Catch accidental host coupling. The public consumer must not import recorder code.
if rg -n 'import VizuallyScreen|\bEditor\b|\bRecordingLibrary\b|\bStudioTheme\b|\bGeist\b' Sources/VizuallyFeedback; then
    printf 'Feedback library must remain independent of the host app.\n' >&2
    exit 1
fi
swift build --product VizuallyFeedbackChecks --disable-sandbox --cache-path /tmp/vizually-screen-swift-cache --scratch-path .build
.build/debug/VizuallyFeedbackChecks
swift build --package-path Examples/FeedbackDemo --disable-sandbox --cache-path /tmp/vizually-screen-swift-cache --scratch-path /tmp/vizually-feedback-consumer-build
