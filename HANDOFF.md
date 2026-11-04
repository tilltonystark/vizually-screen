# Framecraft handoff

Updated 2026-11-03. Repository: https://github.com/tilltonystark/vizually-screen . Native macOS 15+ SwiftUI app, **v0.3**. User prioritizes capture/output detail and extremely smooth motion, with Shotbase as the installed reference. Full parity is unverified.

## User requirements

- Native macOS, light UI, bundled Geist and antialiased text.
- Inspect installed Shotbase without modifying personal captures. Use actual evidence, not feature claims, to assess output quality.
- Push major milestones here and keep this handoff current.
- Invoked REA, Maggie Appleton planning-agents, Superpowers, Emil build-a-tool/color/ui-polish/animations/ui-review. Locally licensed skills are ignored; use an authorized installation. Never commit credentials or private recordings.
- Follow AGENTS.md prompt-optimiser for new work; current authorized milestone brief is `docs/briefs/2026-11-03-quality-access-motion.md`.
- Figma: satyam@vizually.design; verify identity before writes if connection changes.

## Run and verify

```sh
bash scripts/build-app.sh
open dist/Framecraft.app
CLANG_MODULE_CACHE_PATH=/tmp/framecraft-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/framecraft-module-cache swift build --disable-sandbox --cache-path /tmp/framecraft-swift-cache --scratch-path .build
.build/debug/FramecraftChecks
.build/debug/FramecraftQuality /tmp/framecraft-quality
```

Swift 6.1.2 command-line tools, no XCTest. Checks are a standalone executable with behavioral preconditions. Restricted sandbox cannot access media encoder services; run checks with authorized host access if AVFoundation -11834 occurs. Never weaken security globally. `FramecraftQuality --inspect /absolute/movie` audits codecs/timestamps; `--measure-only` remeasures previously generated candidates.

Build script packages resources inside `.app/Contents/Resources`, version 0.3.0, uses `FRAMECRAFT_SIGNING_IDENTITY` or local ad-hoc signing. No valid signing identity is installed on this Mac. Ad-hoc cdhash changes on rebuild can invalidate old TCC entries. Native source picker grants per-session access instead of requiring full desktop enumeration. Geist registers at process scope, bundled OFL included. `.build`, `dist`, local skills, movies and project JSON are ignored.

## Architecture

- `App.swift`: scenes, menus, recording completion to editor, light root.
- `StudioView.swift`, `StudioInspector.swift`, `StudioTimeline.swift`: dominant preview, native recording sheet, canvas/zoom controls, source focus pad, thumbnails/trim/zoom lanes.
- `Theme.swift`, `AppearanceLab.swift`: Geist/resources, semantic colors, validated OKLCH appearance and live JSON controls.
- `Capture.swift`: SCContentSharingPicker, native pointPixelScale sizing, 60fps request, session state/timer, source bounds and 120Hz host-clock pointer sampling. Compact capture uses 420 full-range surfaces; master BGRA. Original cursor can be retained instead.
- `RecordingWriter.swift`: serial SCStreamOutput/AVAssetWriter, explicit profiles, first-frame clock, system audio, backpressure counts, held final frame, normalized smoothed pointer sidecar. Source-disconnect path finalizes received media.
- `Editor.swift`: staged loads, automatic adjacent sidecar read, coalesced seeking, 60Hz observer, shared render state, source-preserving export and cancellation.
- `ExportSheet.swift`: profiles, dimensions/cadence, master storage warning, progress/cancel.
- Core `Project.swift`: validated JSON project, trim math, optional cursor track, continuous overlapping camera transforms with quintic envelopes.
- `Motion.swift`: bounded symmetric 24ms Gaussian smoothing and timestamp interpolation. Arrow only; no click/shape events yet.
- `Renderer.swift`: shared Core Image preview/export, independent 60fps composition clock, one Lanczos camera/framing resample, cursor overlay and rounded gradient frame. RenderState locks a project snapshot.
- `VideoQuality.swift`: H.264 High/CABAC, HEVC Main, ProRes 4444; explicit bitrate/color/profile settings and native size math. SDR 8-bit pipeline; ProRes is not lossless/HDR.
- `MediaExporter.swift`: reader/compositor/writer export, concurrent audio/video drain, trim, progress and cleanup. Compact outputs use explicit YCbCr, masters RGB. No silent resolution reduction.
- `DemoClip.swift`: deterministic 8s 2560×1440/60fps sample. Demo cache v2.
- `FramecraftChecks`: meaningful motion/model/theme/media/cancel checks. `FramecraftQuality`: synthetic screen-detail benchmark, presentation timestamp audit, comparison crops and overlapping-zoom/pointer demo.

## Evidence and honest status

See `docs/quality-report.md` for full results and boundaries. One 66.363s HEVC native window capture finalized at 3024×1654, with an audio track, 7,943 pointer samples and zero writer-backpressure drops. The source was largely static; this is not proof of 60 distinct screen updates, audio sync or long high-motion capture. Private media stays outside Git; the user's edited project was saved locally before relaunch.

Synthetic 1080p60 encode/decode test: prior preset text ROI PSNR 32.05dB, H.264 32.17, HEVC 32.21, ProRes4444 42.46. Compact gains are modest; master uses ~330Mb/s on this content. Actual decoded frames and sorted PTS are measured, not estimated from settings. An initial RGB→compact conversion regression was caught and corrected with explicit YCbCr surfaces. All candidates present 120 frames at ~16.67ms gaps. Safe synthetic report/crops are in `docs/quality-assets`.

Actual REA CLI 6.8.0 outputs are under `docs/evidence` (desktop inventory, plist, Mach-O). Shotbase 1.7.1 imports native capture/encoding/composition frameworks and AVAssetWriter controls. These do not reveal actual encoder settings or cursor algorithms. No functions decompiled/dynamically traced; Node25 used successfully but outside REA declared supported engines. Earlier investigation's “no REA evidence” statement describes the initial stage only.

Shotbase dashboard, static editor, Motion workspace and capture menu were observed live. Native capture overlay/import could not be controlled reliably. **No matched competitor export or controlled side-by-side motion test exists.** Do not claim parity from UI similarity, framework imports or our synthetic scores. Independent agent review was unavailable; author self-review only. Final release empty-state UI was observed; UI-control calls timed out after opening the preserved project, so final populated-preview/export-sheet visual verification remains incomplete. A local process sample showed the main thread idle in the normal event loop, not a demonstrated deadlock. See quality report.

## Next work, in order

1. Controlled same-content capture/export comparison in Shotbase and Framecraft: pixel sharpness, colored text, camera path, cursor timing, audio sync. Use non-sensitive calibration content and user assistance only for inaccessible system overlays.
2. Long/high-motion capture, final compact-surface capture path, window movement/resizing, mixed-DPI/rotated sources and pointer edge checks. Current live capture predates the final 420-surface refinement; synthetic compact exports are tested.
3. Subjective motion tuning from real side-by-side playback. Current camera curves are continuous and mathematically checked, not proven equivalent to Shotbase. New recordings can smooth pointer; old baked cursor cannot be removed.
4. Click events and editable automatic zoom suggestions, cursor shapes and motion blur, then webcam/mic/captions if requested.
5. Undo/autosave, relocatable project bundles/relinking, quit guards, stable signing and notarization.
6. Replace deprecated synchronous AVVideoComposition initializer with async API; profile paused preview invalidation and slider latency. Current render parameters share state; avoid reconstructing the whole composition on every active playback drag.

Appearance Lab does not autosave settings; import JSON or bundle via rebuild. Demo source is temporary. Projects reference absolute paths. Preserve current work before switching projects/relaunching. Use CUA for UI, never shell input synthesis. Do not repeat broad test passes without a change or unresolved concern.

## Source-fit checkpoint (after v0.3)

RecordingWriter now defers encoder setup until the first complete frame. Core CaptureFrameGeometry converts metadata contentRect points to surface pixels and uses contentScale to determine native dimensions. CaptureFrameProcessor crops before encoding (direct buffer path when full-frame) with explicit SDR color attachments. Initial window/display bounds are selected by filter style. One already-authorized sole screen defaults automatically; stale ad-hoc grants still require native per-session picker selection. New Project padding defaults to zero; None is explicit; choosing a palette enables framing. Quality names are High quality (HEVC default), Most compatible (H.264), Maximum detail (ProRes). InfoHint/QualityPicker share semantic metrics and fixed-width hover/click help; see DESIGN.md.

Checks passed for nonzero-offset padded-frame crop, actual H.264 encode/decode corner coverage, existing audio/trim/cancel/motion tests; release build passed. Native recording sheet, zero-padding empty inspector, and info popover presence were observed. A saved copy of the user's latest edit was made before relaunch. The exact browser screenshot was not reproduced from sampled local frames, so do not claim a proven diagnosis of that specific frame. Live resized-window capture remains unverified; standard movie tracks retain the first frame's fixed dimensions. See docs/source-fit-review.md.

User approved the next milestone order: cursor-led smoothing/automatic editable focus → Vizually Screen rename/header/backgrounds/image import → home/library. See docs/briefs/2026-11-03-vizually-screen-milestones.md. Push each checkpoint. No stock Apple wallpapers should be redistributed; access installed local assets or let the user import images.

## Cursor-led motion checkpoint (v0.4)

See docs/motion-focus-review.md. AutoFocus.swift adds dwell-based editable suggestions and manual-zoom protection. Motion.swift adds timestamp-bounded smoothing strengths and monotone cubic interpolation. Project adds optional pointerSmoothing and Zoom.automatic, preserving old JSON compatibility. New capture sidecars retain raw positions; legacy sidecars may already have earlier filtering applied. Editing automatic zoom parameters promotes them to manual. RenderState prepares pointer filtering once per setting change. Editor.update no longer seeks while playing; paused frames get a coalesced composition-copy invalidation. Demo v3 uses a separate track. Behavioral and real media checks pass; eight-second motion examples rendered. Final paused preview visual verification remains open due post-Save native UI-control timeouts. Current user edit was preserved locally. Next: full Vizually Screen rename/backgrounds/header, then home library, all approved.
