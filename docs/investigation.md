# Screen Studio alternative — initial investigation

Date: 2026-11-03. Target supplied: https://screen.studio/ . Workspace initially empty.

## Method and boundary

Applied the user-specified [reverse-engineer-anything skill](https://github.com/morluto/rea/blob/main/.agents/skills/reverse-engineer-anything/SKILL.md), version 59 as read on this date: route the target, separate observations/inferences/unknowns, retain a findings ledger, and use ordinary coding tools for the reconstruction.

No REA MCP operations are advertised in this session, and `rea` is absent from the shell PATH. Screen Studio was not found in the top-level `/Applications` inventory. This is a bounded check, not proof it is absent everywhere. No binary was supplied, downloaded, executed, or decompiled. No REA Evidence IDs exist. Website findings below are public product claims, not independently tested runtime behavior. Internal algorithms and architecture remain unknown.

## Finding ledger

| Question | Evidence | Status | Consequence for our app |
| --- | --- | --- | --- |
| What is the central workflow? | Official product page describes recording and polished zoom/framing/editing. | Answered at advertised-feature level | Capture → edit → export. |
| How does automatic zoom choose moments? | Official page says it uses interactions such as clicks. Exact rules are unpublished. | Partially answered | A future event sidecar should store timestamps and normalized cursor/click positions. Current version exposes manual regions. |
| Does it smooth cursor motion? | Official page advertises cursor smoothing and click effects. | Advertised only | Future capture should hide the baked cursor and render a separate cursor track. |
| What camera capabilities exist? | Official page describes overlays, split view, cutout and face tracking. | Advertised only | Separate camera track and compositor layouts are future scope. |
| What stack/algorithms does Screen Studio use internally? | No shipped artifact/runtime evidence. | Unresolved | We make no attribution; our stack is an independent design choice. |

Product source: https://screen.studio/ (accessed 2026-11-03).

## Independent implementation choices

Native macOS is the working default pending user preference. SwiftUI for UI, ScreenCaptureKit SCRecordingOutput for capture, AVFoundation for playback/trim/export, Core Image for framing and zooms. Apple documentation: https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos and https://developer.apple.com/documentation/avfoundation/avvideocomposition . SCRecordingOutput declarations were also checked in the locally installed macOS SDK headers.

The renderer uses cubic smoothstep easing with 0.6-second maximum entrance/exit ramps. Latest active zoom wins on overlap. Zoom panning clamps to image bounds. These are our rules, not recovered Screen Studio algorithms. Preview and export consume the same immutable project snapshot and compositor.

## Next implementation stages

1. Validate display capture and system-audio synchronization under macOS permission flows; handle stop/quit/disconnect recovery.
2. Add a timestamped cursor/click sidecar, cluster nearby click events into suggested zoom regions, expose editable suggestions. Build fixture-driven tests for cluster spacing and screen-coordinate transforms.
3. Hide capture cursor and render the cursor from a separately sampled/smoothed track; add click indicators.
4. Add webcam/microphone capture with a shared clock, then layout controls and audio mix.
5. Add undo, autosave, relocatable project bundles, export cancellation/progress, signing and notarization.

This closes the public-feature baseline and first implementation only. Binary/runtime reverse engineering and full product parity are not complete.

## Validation results

The app compiled with Swift 6.1.2. Standalone checks passed for smooth zoom boundaries, project validation/JSON roundtrip, and a generated two-second H.264 source exported to a 1.5-second styled/zoomed MP4 and decoded to a 320×180 frame. The media check initially failed inside the execution sandbox because the H.264 encoder service was unavailable; the same executable passed with approved access outside that sandbox. This does not establish live screen capture or audio synchronization. The Core Image AVVideoComposition initializer currently emits a macOS 15 deprecation warning; migration to its asynchronous replacement remains cleanup work.

## Live Shotbase reference — 2026-11-03

User supplied Shotbase as a comparable installed app. Inspected through native UI automation; these are ordinary live UI observations, not REA Evidence. Dashboard shows search, capture library, folders and a Capture action. Its editor provides a dominant canvas, compact header actions, a vertical tool rail and grouped inspector. Static and Motion tabs switch editing contexts. Motion mode exposes playback/time, a ruler, a motion-effects lane and a source strip; screenshot motion defaults to five seconds in the inspected item. Inspector exposes source-image focal controls, background/padding, radius, shadows and browser framing. Opened an existing screenshot and switched UI modes; no source settings were intentionally changed and nothing was exported/shared/deleted. Export format/result and recording/cursor quality were not verified. No extra app access was needed for this UI inspection. A screen lock interrupted checks and the user unlocked the Mac.

Applied lessons: dominant preview, compact recording sheet, selected timeline regions, grouped canvas/zoom inspector, and a source thumbnail behind the zoom focal point. Vizually Screen remains light-mode per user preference. Shotbase UI observations do not establish full Screen Studio output parity.

## v0.3 evidence update

The initial methods/implementation sections above describe v0.1. REA CLI inspection of installed Shotbase was subsequently completed, with actual Evidence IDs retained under `docs/evidence`. Capture now uses the native sharing picker and an explicit writer; motion uses quintic continuous camera blending and an optional separate pointer track; output profiles/progress/cancel are implemented. See [current quality report](quality-report.md) and [handoff](../HANDOFF.md) for measurements and remaining limits. No Shotbase native function was decompiled and no matched competitor export has been measured.
