# Source fit and control simplification — 2026-11-03

## Findings and changes

| Before | After | Why |
| --- | --- | --- |
| Writer encoded the full capture surface using picker-time dimensions | Writer waits for the first complete frame; contentRect/scaleFactor/contentScale determine actual source bounds and native output size | A capture surface can contain unused area around a window |
| Native window pixels could inherit a wider output surface | Metadata-driven crop runs before encoding; whole-frame captures use the direct path | Remove capture padding without guessing that black pixels are empty |
| New projects had 7% framing | New projects use zero padding; None is explicit; backgrounds remain opt-in | Default video uses its source edge to edge |
| Sole display still required an app-level choice | An already-authorized sole display is selected automatically | No redundant choice; native permission picker remains when required |
| HEVC/profile jargon and paragraphs | High quality, Most compatible, Maximum detail; shared 280pt info cards | Describe real tradeoffs and keep controls scannable |
| Selected palette stayed marked even with zero padding | None is selected at zero padding; choosing a palette enables framing | Selection reflects the rendered result |

## Evidence

Apple documents that the output surface can exceed the window content and directs consumers to crop contentRect then use contentScale and scaleFactor. [ScreenCaptureKit metadata guidance](https://developer.apple.com/videos/play/wwdc2022/10155/) and the installed SCStream.h explicitly identify contentRect as points in the surface. Screen and window bounds are chosen by filter style, rather than accidentally using an included window for a display capture.

Checks construct a 640×480 buffer with 320×200 content at a nonzero offset and surrounding black. Metadata is supplied in points at 2× density. The processor produces 320×200; all four checked corners contain the content. A real H.264 encode/decode preserves those dimensions and edges. Native 5K sizing, scaled-content recovery math and full-frame metadata fallback are checked. This is a regression test for metadata handling; not a live resize/permission proof.

Two sampled frames of the most recent local recording were full content; the exact browser frame shown in the user's screenshot was not located. Its root cause is not conclusively reproduced. Existing videos have no retained content-rect metadata and are not automatically cropped by a black-pixel heuristic. New captures now avoid encoding the unused surface area represented by frame metadata.

A standard movie track has fixed dimensions. The first source frame determines them. Changing the window's aspect ratio mid-recording still requires fitting into that fixed track; this checkpoint does not promise variable-aspect movie frames. Smaller windows chosen before recording get their own dimensions. Truly Dock-minimized windows may be suspended by macOS.

## Design-system check

The existing native tokens/components were retained. InfoHint and QualityPicker are documented in DESIGN.md; help metrics and font roles are shared. Errors, source status, progress and the large-file warning stay visible. Existing raw layout values outside this scope remain debt. Shotbase's Background inspector was observed with None, Color, Gradient, Wallpapers and Image categories, plus framing controls; its model values were not changed.
