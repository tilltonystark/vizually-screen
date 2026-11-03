GOAL: Remove unused capture area and simplify recording/export controls.
DONE WHEN:
- New screen/window recordings use actual selected-source pixels; a smaller window does not inherit display dimensions or encoded padding.
- New projects default to zero decorative padding, with optional framing retained.
- A single authorized screen is the default without a redundant display-choice question; macOS permission selection remains when required.
- Quality labels explain the real format/file-size tradeoffs in plain language.
- Supporting paragraphs move into shared fixed-width info cards, available on hover and keyboard/click.
- Geometry/media checks and build pass; UI is checked where accessible; handoff and repository are updated.
CONSTRAINTS: Light native SwiftUI, Geist, current semantic colors; preserve existing projects/originals. Do not guess-crop black pixels. Use frame metadata. Do not bypass macOS permissions.
SOURCES: User screenshot; current Capture/RecordingWriter/Renderer; Apple ScreenCaptureKit SDK/docs; emil-design-foundations and pasted design-system guidance (system-check mode).
STEPS:
1. Trace source/filter/frame dimensions and implement metadata-based content fitting.
2. Default capture and framing to the selected source.
3. Replace jargon and persistent explanations with shared info cards.
4. Verify geometry with synthetic padded frames and actual encode/decode, inspect native UI, update handoff and push.
ASSUMPTIONS: “Minimized window” means a smaller, non-maximized app window. Canvas dimensions follow the source at recording start; a standard video track has fixed dimensions. Actual Dock-minimized sources depend on macOS availability. Existing videos are not automatically cropped by guessing black areas.

OUTCOME: Metadata crop and real encode/decode regression checks pass, default padding is zero, None is explicit, quality/help controls are simplified. Authorized single-screen fallback is implemented; on this ad-hoc build a native permission selection may still be necessary. Recording sheet and info popover were observed. Exact reported browser frame and live resizing remain unverified; see source-fit-review.md. Subsequent scope/order was approved and is saved in 2026-11-03-vizually-screen-milestones.md.
