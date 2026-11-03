# Framecraft · native video studio

A native macOS foundation for a Screen Studio alternative. SwiftUI, ScreenCaptureKit, AVFoundation, and Core Image; no third-party dependencies. Requires macOS 15+ and the Swift 6 toolchain.

## Run

```sh
bash scripts/build-app.sh
open dist/Framecraft.app
```

Click **Find displays**, grant macOS Screen & System Audio Recording access, and reopen if macOS requests it. Select a display and start recording. Stop in the app or its menu-bar item. Recordings are kept under `~/Movies/Framecraft`. Framecraft excludes its own windows from captures.

You can also import a video without granting screen access. Use the playhead and **Add zoom** to place a smooth zoom. Adjust focus, scale, duration, padding, background, and trim in the inspector. **Export MP4** renders these edits. Audio already present in the source is retained by AVFoundation. **Save project** writes editable JSON referencing the original video; keep that video at its original path.

## Light studio (v0.2)

The editor uses bundled Geist Regular/Medium/Semibold, a light palette authored in OKLCH and rendered as sRGB, a dominant preview, a thumbnail timeline, selectable zoom regions, and a source-image focus pad. Native SwiftUI/Core Text text is antialiased; no global font preference is changed.

Use **File → Open Demo Project** to generate an actual eight-second local video and explore the populated editor. Use **Studio → Appearance Lab** (⌘⇧L) to tune accent, canvas lightness, radius and spacing live. Import/export settings as JSON. To bundle a chosen appearance as the default, replace `Sources/Framecraft/Resources/appearance.json` and rebuild.

See [HANDOFF.md](HANDOFF.md) before continuing development in another AI tool.

## Current scope

- Display capture, visible native cursor, optional system audio; H.264 MP4, up to 4K/60 requested (actual delivery depends on hardware).
- Local video import, playback, trim, gradient frame, rounded corners, manual eased zoom regions.
- Shared preview/export compositor, source-preserving edits, JSON save/open.
- Export keeps the source aspect ratio and resolution.

This is an initial implementation, not Screen Studio feature parity. Automatic click-based zooms, separate cursor rendering/smoothing, webcam and microphone tracks, window/region capture, captions, motion blur, undo/history, relocatable project bundles, export progress/cancel, and signing/notarization remain future work. Do not close or quit during recording or export; interrupted recordings are not yet recovered automatically. Unsaved edits are not restored after quitting. The app is ad-hoc signed for local development, not distribution.

## Verification

```sh
CLANG_MODULE_CACHE_PATH=/tmp/framecraft-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/framecraft-module-cache swift run --disable-sandbox --cache-path /tmp/framecraft-swift-cache --scratch-path .build FramecraftChecks
```

Tests cover zoom envelopes, overlapping zoom selection, project validation/serialization, and a real generated-video → trimmed/styled MP4 → decoded-frame roundtrip. Live capture, audio sync, rotated/HDR imports, and long recordings need manual validation on the target Mac.

See [investigation](docs/investigation.md) for evidence and implementation choices.
