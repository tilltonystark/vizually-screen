# Vizually Screen handoff

Updated 2026-11-04. Repo: https://github.com/tilltonystark/vizually-screen . Native macOS 15+ SwiftUI, light mode, bundled Geist. User prioritizes source detail, smooth motion, good UX, Shotbase reference and frequent pushed checkpoints. No competitor parity claim.

## Approved work

Milestones in docs/briefs/2026-11-03-vizually-screen-milestones.md. Source-fit checkpoint pushed (27ca624); cursor-led motion pushed (25dfce9). Current identity/background checkpoint renames all modules/build output to VizuallyScreen / Vizually Screen, adds optional backgrounds and fixes header spacing. Home/library and native pinned feedback mode are now implemented in the working tree; final native feedback transport verification is underway. Feedback uses a local Agentation HTTP bridge, not a browser DOM. See docs/feature-map.md before adding scope. User approved the milestone order; do not re-ask.

Use AGENTS.md prompt-optimiser for new scope. Figma only satyam@vizually.design if used. User invoked REA, Superpowers and Emil skills; locally licensed skill files are ignored. No private recordings or credentials in Git. Use CUA for UI, never shell input synthesis.

## Run

```sh
bash scripts/build-app.sh
open 'dist/Vizually Screen.app'
CLANG_MODULE_CACHE_PATH=/tmp/vizually-screen-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/vizually-screen-module-cache swift build --disable-sandbox --cache-path /tmp/vizually-screen-swift-cache --scratch-path .build
.build/debug/VizuallyScreenChecks
.build/debug/VizuallyScreenQuality /tmp/vizually-screen-quality
```

Swift 6.1.2 CLT, no XCTest. Behavioral checks use a standalone executable. Restricted sandbox cannot access media encoders; use approved host execution for checks, never weaken global security. App/resources/fonts are packaged in dist, ignored. Default ad-hoc signing changes identity hashes per build; VIZUALLY_SCREEN_SIGNING_IDENTITY supports an installed identity. New product ID design.vizually.screen uses the native per-session picker where authorization is needed.

## Architecture

- Sources/VizuallyScreen: App scenes/menus, Editor AVPlayer/state/save/export, Capture native picker/state/120Hz pointer sampling, RecordingWriter serial SCStreamOutput/encoder, StudioView/Inspector/Timeline, InfoHint/QualityPicker, BackgroundPicker/WallpaperPicker, Theme/AppearanceLab and WindowChrome.
- Sources/VizuallyScreenCore: Project validated Codable edits; ProjectFiles reads new .vizually.json and legacy .framecraft.json; CaptureFrame metadata bounds/crop; Motion smoothing and monotone interpolation; AutoFocus dwell suggestions/manual protection; Renderer shared 60fps compositor; CanvasBackground optional image/solid/gradient; MediaExporter reader/writer audio/progress/cancel; VideoQuality explicit profiles/native dimensions; DemoClip.
- Sources/VizuallyScreenChecks: motion/model/theme/crop/background/media checks. Sources/VizuallyScreenQuality: synthetic encode/decode detail benchmark and eight-second motion examples; --inspect audits a movie, --motion-only renders motion variants.

New originals: Movies/Vizually Screen. Legacy originals stay in Movies/Framecraft for compatibility; do not blindly move them because saved projects reference absolute paths. Existing edits were saved locally before relaunch; no private media is in Git. New captures retain raw pointer samples; earlier sidecars may already have 24ms filtering. Optional new project fields preserve old JSON decoding. Demo v3 source is temporary and has no baked pointer; separate sample track and auto focus are applied in the renderer.

Capture writer configures dimensions from the first actual complete frame, uses contentRect × scaleFactor / contentScale, and crops unused IOSurface area before encoding. No black-pixel guessing. Compact profiles use YCbCr surfaces, master BGRA; explicit SDR color tags. A standard movie has fixed dimensions: changing window aspect ratio mid-capture can require fitting. Dock-minimized sources may suspend. Real resize/mixed-DPI tests remain open.

RenderState caches smoothed pointer and background image. Camera uses continuous quintic transforms (0.85s ramps), pointer offers Recorded/55ms/100ms smoothing, 60fps composition independent of sparse source frames. Auto focus uses 10Hz dwell analysis after deliberate travel, preserves manual regions, promotes edited suggestions to manual. Active playback edits no longer seek. Paused edits invalidate a copied composition identity on a coalesced refresh; native visual recheck was interrupted by UI-control timeout.

CanvasBackground uses eight subdued presets, custom solid RGB, imported image or installed local wallpaper. Image import copies to Application Support/Vizually Screen/Backgrounds; stock wallpapers remain referenced locally, never committed. Image resampling clamps edges to avoid dark fringes. None is zero padding, preserves original dimensions and bypasses background work. Missing image during export gives a recovery error. Header is a unified AppKit/SwiftUI 56pt row; traffic lights are placed by AppKit, not private frame hacking.

## Evidence / limits

See docs/quality-report.md (synthetic profile scores + actual REA artifacts), docs/source-fit-review.md (padded-frame regression and limits), docs/motion-focus-review.md. Actual REA CLI 6.8.0 inspected Shotbase 1.7.1 bundle/plist/Mach-O; imports show native APIs but no functions were decompiled or runtime encoder settings recovered. Node25 was outside REA declared supported engines. Shotbase dashboard/editor/Motion/background categories were inspected; no matched competitor output exists.

Prior live capture finalized at 3024×1654 with an audio track, 7,943 pointer samples and zero writer-backpressure drops; largely static, not a high-motion endurance proof. Synthetic text ROI scores: legacy 32.05dB, H.264 32.17, HEVC 32.21, ProRes4444 42.46; master uses much more storage. Keep historical report data exact. Current tests pass actual crop encode/decode, sharp-turn smoothing, dwell/idle/jitter cases, manual protection, project compatibility, audio/trim/60fps/cancel and background rendering. Header/new name and populated motion controls were observed natively; final paused-preview checks hit intermittent native UI timeouts. Prefer full app path to stale bundle bindings after Save dialogs.

Remaining: controlled competitor comparison and subjective motion, live final crop/resize/mixed-DPI checks, audio sync, HDR, all cursor shapes, click events, webcam/mic/captions, undo, relinking/project bundles, quit guards and distribution signing. Deprecated synchronous AVVideoComposition initializer still warns; async migration is cleanup. No independent reviewer was available; author self-review only.

## Workspace / feedback checkpoint

HomeView routes home/editor and owns RecordingLibrary. Core RecordingCatalog merges recent entries with both Movies roots and saved sidecars; canonical paths avoid /var versus /private/var missed edits. Catalog regression and real media checks passed November 4. Editor preserves an atomic working copy in Application Support/Vizually Screen/Projects when returning home or changing source. Quit autosave remains open. Home showed five existing recordings and thumbnails; opening a recording and returning home worked natively.

Feedback.swift instruments SwiftUI bounds via anchor preferences and explicit semantic targets. Comment mode intercepts content clicks, highlights the smallest registered target, anchors a draft at the clicked point, stores feedback atomically in Application Support/Vizually Screen/Feedback/feedback.json, and sends to the existing loopback Agentation server (127.0.0.1:4747). User explicitly requested direct feedback to this agent. Session identity is saved under UserDefaults key feedback.agentation.session. Only query this app's session, never all unrelated sessions. The server assigns annotation IDs; localFeedbackID attributes deduplicate retries after uncertain delivery. Unsent comments remain local; returned remote status updates resolved state on refresh. Do not claim automatic agent wakeup: an active agent must call the session-scoped watch/read tools.

Latest product direction: map the universe first, prioritize quality over count. docs/feature-map.md distinguishes user screenshot, live observation, advertised claims and our own evidence. Shotbase's complete feature set has NOT been exercised; matched exported output remains unverified. Current menu-bar start/global shortcut gap is explicitly mapped, not silently claimed complete.

### Feedback transport verified / follow-up

User submitted a real spacing request through the native comment UI on November 4. It reached Agentation session mw1sprt2-3y23fq, annotation mw1sprt6-ecg3n9; agent read it through session-scoped MCP and acknowledged it. First comment incorrectly identified Workspace: parent anchorPreference overwrote descendant preferences. Replaced with transformAnchorPreference to accumulate targets; native screenshot now shows an individual Timeline outline rather than Workspace; tab-specific click/pin confirmation is pending from user. User asked to reduce right inspector padding and tab height: changed horizontal inset20→16pt and tab height40→36pt, tab group inset12→10pt. Do not resolve the annotation until user accepts the rendered change. Comment mode now pauses playback and saves the playback time at pin creation. Home rail reserves room for the small feedback toolbar.

Checkpoint342bf61 pushed successfully. Build/media/catalog checks passed. Release bundle0.6.0. Agentation API reference: https://www.agentation.com/api . This is native SwiftUI instrumentation using the local HTTP API, not the web React component.
