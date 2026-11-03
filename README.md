# Framecraft · native video studio

A native macOS foundation for a Screen Studio alternative. SwiftUI, ScreenCaptureKit, AVFoundation and Core Image; no third-party runtime dependencies. Requires macOS 15+ and the Swift 6 toolchain. Current milestone: **v0.3 — capture access, output quality and motion**.

## Run

```sh
bash scripts/build-app.sh
open dist/Framecraft.app
```

Click **Record → Choose screen or window…**, select a source in the macOS picker, then **Start recording**. The picker grants access to that source for the session. Stop in the app or its menu-bar item. Originals and pointer sidecars are kept under `~/Movies/Framecraft`; keep both together. The native picker avoids relying on a stale permission entry from an older development build.

Choose **High quality** for everyday use (HEVC), **Most compatible** for broad playback support (H.264), or **Maximum detail** for a large editing file (ProRes 4444). The info icon explains each option. Capture uses the first actual frame's content bounds and native pixel density, without a silent 4K cap or unused capture-surface padding. An already-authorized sole display defaults automatically; source selection remains when macOS needs session authorization. New projects start without decorative framing; choose **None** to return to edge-to-edge video. Existing projects retain their settings. **Smooth pointer** hides the original cursor, records movement separately and renders a smoothed arrow. Turn it off to retain real system cursor shapes. Separate pointer capture requires macOS 15.2+; old videos with baked-in cursors cannot be smoothed retroactively.

Import videos without screen access. Use **Add zoom**, then adjust focus, scale, duration, framing and trim. **Export video** offers explicit profiles, source resolution, 60fps composition, progress and cancellation. Source audio is retained. **Save project** writes JSON referencing the original video; keep the source at its original path. Recordings automatically get an adjacent project sidecar that is read on reimport.

## Light studio

Bundled Geist Regular/Medium/Semibold, light semantic colors, a dominant preview, thumbnail timeline, selectable zoom regions and source-image focus pad. Native SwiftUI/Core Text text is antialiased; no global font preference is changed.

**File → Open Demo Project** generates an eight-second 2560×1440/60fps local sample. **Studio → Appearance Lab** (⌘⇧L) tunes accent, canvas lightness, radius and spacing live, with JSON import/export. To ship an appearance, replace `Sources/Framecraft/Resources/appearance.json` and rebuild.

## Verification and evidence

```sh
CLANG_MODULE_CACHE_PATH=/tmp/framecraft-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/framecraft-module-cache swift build --disable-sandbox --cache-path /tmp/framecraft-swift-cache --scratch-path .build
.build/debug/FramecraftChecks
.build/debug/FramecraftQuality /tmp/framecraft-quality
```

Media checks need access to macOS encoder services; a restricted execution sandbox may report AVFoundation -11834. Do not change global security settings. Checks cover camera continuity, pointer smoothing, native sizing, project/theme validation, demo decode, trimmed 60fps export with audio and cancellation cleanup. The quality executable generates synthetic encode/decode comparisons, detail crops and a motion demo; `--inspect /absolute/movie` audits media metadata.

[Quality report](docs/quality-report.md) contains reproducible measurements, actual REA inspection evidence and explicit limits. A native 3024×1654 capture finalized with zero writer-backpressure frame drops. This is **not demonstrated Shotbase/Screen Studio parity**: matched competitor output, subjective motion comparison, audio sync, long moving captures and HDR remain unverified.

## Current limits

Manual zooms; arrow-only cursor reconstruction; SDR pipeline. Automated click-based zooms, shape-aware cursors, motion blur, webcam/mic, captions, undo/autosave, source relinking and relocatable bundles remain future work. Export cancellation and source-disconnect finalization are implemented; do not quit during recording/export. Unsaved edits are not restored after quitting.

Builds are ad-hoc signed locally. For a stable signing identity, set `FRAMECRAFT_SIGNING_IDENTITY` when running the build script; signing/notarization for distribution is not configured. See [HANDOFF.md](HANDOFF.md) before continuing development.

Source-fit regression evidence and limits: [review](docs/source-fit-review.md). The approved next checkpoints are in [milestones](docs/briefs/2026-11-03-vizually-screen-milestones.md).
