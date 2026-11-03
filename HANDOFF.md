# Framecraft handoff

Updated 2026-11-03. Repository: https://github.com/tilltonystark/vizually-screen . Native macOS 15+ SwiftUI app, currently v0.2. User wants a Screen Studio-quality alternative; the current implementation is a foundation, with a substantially revised light editor. Full parity is not established.

## User requirements

- Native macOS, light UI, bundled Geist and antialiased text.
- Use installed Shotbase as the live reference. User authorized inspecting its UI; request user action only if a permission/login prompt blocks access. Do not modify existing captures as an incidental test.
- Keep major milestones pushed here; maintain this handoff for other AI tools.
- The user invoked REA, Maggie Appleton's planning-agents article, Superpowers, and Emil's build-a-tool, color and ui-polish skills. References and adaptations are in docs. Locally licensed skills are ignored; use your own authorized installation. Do not commit tokens.
- If Figma is used later, use account satyam@vizually.design (previous verified connection link_6abd03794c848191980d937198c2b501; verify identity before writing).

## Run and verify

```sh
bash scripts/build-app.sh
open dist/Framecraft.app
CLANG_MODULE_CACHE_PATH=/tmp/framecraft-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/framecraft-module-cache swift run --disable-sandbox --cache-path /tmp/framecraft-swift-cache --scratch-path .build FramecraftChecks
```

The command-line tools on this Mac have Swift 6.1.2 but no XCTest. Checks are a standalone Swift executable using preconditions. The execution sandbox cannot access H.264 encoder services: build inside the sandbox, then run `.build/debug/FramecraftChecks` with approved host access if it reports AVFoundation -11834. Do not weaken sandbox configuration globally.

`dist` and `.build` are ignored. Build script creates an ad-hoc signed `.app` and copies its SwiftPM resource bundle inside Contents/Resources. Fonts register at process scope through Core Text; bundled regular/medium/semibold are checked at startup. Geist license is included. Native text uses default macOS antialiasing; the Appearance Lab Core Text sample also explicitly enables it.

## Architecture

- `Sources/Framecraft/App.swift`: scenes, menus, light-mode root.
- `StudioView.swift`: toolbar, preview, transport, empty state, recording sheet.
- `StudioInspector.swift`: Canvas/Zoom tabs, source-thumbnail focus pad and bounded controls.
- `StudioTimeline.swift`: source-time ruler, real video thumbnails, trim overlay and selectable zoom lanes.
- `Theme.swift` and `AppearanceLab.swift`: Geist/resources, semantic colors/components, live theme controls and JSON persistence.
- `Editor.swift`: AVPlayer, successful-load state commit, thumbnail generation, seeking/play state, selection, save/open/export.
- `Capture.swift`: ScreenCaptureKit display + optional system-audio capture via SCRecordingOutput. Originals under ~/Movies/Framecraft.
- `FramecraftCore/Project.swift`: Codable source-path project, trim/zoom interval math and validation.
- `Renderer.swift`: shared preview/export Core Image compositor. Gradient framing and smooth manual zooms. Latest active zoom wins.
- `Appearance.swift`: validated configuration and gamut-mapped OKLCH→sRGB/contrast utility.
- `DemoClip.swift`: deterministic actual 8s 1280×720 H.264 demo; independent content drawn with CoreGraphics/CoreText.
- `FramecraftChecks/Checks.swift`: core validation, supported-palette contrast, real demo generation/decode and styled/trimmed export/decode.

## Current evidence

Release app builds; earlier UI was observed in empty and populated states. Demo load, zoom selection and Appearance Lab opening were exercised natively. Appearance Lab exported `docs/appearance-review.json`, an example with hue 272; shipped default remains hue 265. Core/media checks pass, including short clips, trim bounds, project/appearance roundtrip, all allowed accent hues at tested canvas lightness endpoints/default, real demo decode, and a real trimmed MP4 export/decode. Rerun after changes. Final build was relaunched after unlock; source-thumbnail focus pad, playback/pause, zoom selection, background change and padding adjustment were visually exercised.

Shotbase dashboard, static editor and Motion workspace were observed live. Useful patterns: dominant canvas, grouped inspector, source thumbnail/focal control and separate motion timeline. No Shotbase output export or recording/cursor quality was measured. See docs/investigation.md. REA server/tools are not connected and no native binary was decompiled.

## Known gaps and next work

1. Finish manual capture permission, display stop/start/disconnect and audio synchronization checks. Avoid quitting during a recording/export: recovery and quit guards are not implemented.
2. Build a controlled comparison: record the same scripted interactions in Framecraft and the reference, compare sharpness, zoom/pan timing and exported media. Do not claim parity from UI screenshots.
3. Record a timestamped cursor/click sidecar; implement suggested zooms and separately rendered smooth cursor/click effects. Current cursor is baked into capture and zooms are manual.
4. Webcam/mic tracks, motion blur, captions and camera layout transitions are absent.
5. Add undo/autosave, relocatable projects, export progress/cancel, source relinking and signed/notarized distribution. Project JSON references an absolute source path. Demo source is temporary, so don't rely on saved demo projects after OS cleanup.
6. Migrate the deprecated synchronous AVVideoComposition filter initializer to its async replacement. Live drag updates currently reconstruct composition/reseek; profile latency before adding more effects.
7. Appearance Lab tunes the actual app in memory; exported JSON must be imported next launch or bundled via rebuild. It does not autosave theme settings.

Do not broaden testing solely to add snapshots or mirror SwiftUI implementation. Use behavioral media/interval tests and actual native visual checks. Never use shell input synthesis for app UI; use available computer-use tools.
