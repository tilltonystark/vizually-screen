# Vizually Screen

A native macOS screen recorder and editor with smooth pointer motion, editable automatic zooms, and source-resolution video export. Light SwiftUI interface with bundled Geist. Requires macOS 15+ and Swift 6; separate pointer capture requires macOS 15.2+.

## Run

```sh
bash scripts/build-app.sh
open 'dist/Vizually Screen.app'
```

Record a screen or a single app window using the macOS source picker. An already-authorized sole display is selected automatically. Source dimensions come from the actual captured content; new recordings default to no additional background. Originals and pointer sidecars are stored in `~/Movies/Vizually Screen`.

The old `.framecraft.json` project format remains readable. New projects use `.vizually.json`; originals are never overwritten by export.

## Library and app feedback

The home screen discovers prior recordings and saved edits, including legacy recordings. Returning home saves a working copy without changing the original video. Use the comment icon at the bottom left (⌘⇧F), hover a control, click to pin a comment, then **Send to agent**. Comments include the SwiftUI target, source location, UI bounds and playback time. They are saved locally and sent only to the local Agentation server at `127.0.0.1:4747`; disconnected comments remain available for retry. No screenshots or recorded source paths are uploaded by the feedback bridge. The agent must be connected and reading that session to act; the button does not start an agent on its own.

## Edit and export

- **Auto focus** suggests zooms where the pointer settles after moving. Suggestions are editable; manually adjusted zooms are protected when refreshing suggestions.
- **Pointer motion:** Recorded, Smooth, Extra smooth. Requires a separate pointer track; a cursor baked into older footage cannot be removed.
- **Background:** None, eight subdued gradients, solid/custom colors, imported images, or installed macOS wallpapers. Images fill the canvas without stretching. Wallpaper files stay local and are not redistributed in this repository.
- **High quality:** recommended HEVC video, with smaller files.
- **Most compatible:** H.264 for wider playback support, generally larger files.
- **Maximum detail:** ProRes 4444 for further editing and colored-text detail, with very large files. It is not lossless.

All profiles preserve source dimensions. Camera/pointer composition runs at 60fps; extra frames cannot recreate missing source detail. Export retains source audio, reports progress and supports cancellation. Info icons contain fixed-width explanations. Save/open projects as JSON referencing the original source.

Use **File → Open Demo Project** for a safe 1440p60 sample with a separate pointer track and generated focus regions. **Studio → Appearance Lab** adjusts the light theme and exports settings as JSON.

## Checks and evidence

```sh
CLANG_MODULE_CACHE_PATH=/tmp/vizually-screen-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/vizually-screen-module-cache swift build --disable-sandbox --cache-path /tmp/vizually-screen-swift-cache --scratch-path .build
.build/debug/VizuallyScreenChecks
.build/debug/VizuallyScreenQuality /tmp/vizually-screen-quality
```

Media checks require access to macOS encoder services; restricted sandboxes can return AVFoundation -11834. Tests cover source-content cropping through real encode/decode, native sizing, camera/pointer motion, automatic-focus/manual-edit protection, project compatibility, background rendering, trimmed 60fps audio export and cancellation cleanup.

[Feature map and release gates](docs/feature-map.md), [Quality evidence](docs/quality-report.md), [source-fit review](docs/source-fit-review.md), [motion review](docs/motion-focus-review.md), [design system](DESIGN.md), [handoff](HANDOFF.md).

This is not demonstrated Shotbase/Screen Studio parity. Matched competitor exports, audio synchronization, long high-motion capture, HDR/P3 and all cursor shapes remain unverified. The current pipeline is SDR. Builds are locally ad-hoc signed; set `VIZUALLY_SCREEN_SIGNING_IDENTITY` for an available stable developer identity. Distribution signing/notarization is not configured. Do not quit during capture/export.
