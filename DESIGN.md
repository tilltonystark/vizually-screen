# Native studio system

Light macOS surfaces, Geist, restrained violet actions, and a dominant recording preview. Use `Theme.swift` as the existing base; extend shared components before adding local variants. The system is native SwiftUI, not a web component library.

## Layers and source of truth

Primitives live in `Appearance.swift` (OKLCH values), `Theme.swift` (font registration and sizing), and the validated appearance JSON. Semantic roles: `Ink.primary/secondary/muted/line/soft`, `StudioTheme.accent/tint/canvas/radius`, `StudioLayout.help*`, `StudioType.sectionTitle/controlLabel/caption/helpIcon`. Shared help components consume these roles, not new raw values.

- Primary text: `Ink.primary`; supporting text/help: `Ink.secondary`; rules: `Ink.line`; quiet panels: `Ink.soft`.
- One primary action per sheet: Start recording or Choose location. Studio export is primary; Record remains secondary.
- Native text is antialiased; bundled Geist regular/medium/semibold only. Keep numeric time/size values monospaced.
- New recordings start at zero padding. None means no decorative background; choosing a background enables framing. Source size is automatic, never an arbitrary canvas preset.
- Long explanations belong in `InfoHint`, because settings should scan without paragraphs. Errors and essential warnings stay visible.

## Shared components

`StudioButtonStyle(primary:quiet:)`: default secondary; primary for the single next action; quiet for low-emphasis actions. No other variants exist. Correct: Start recording uses primary. Incorrect: Cancel uses primary. Hover and press feedback respect reduced motion; native keyboard focus remains available. Existing disabled opacity is inherited debt, not a pattern to copy into new components.

`IconButton(symbol:title:action:)`: toolbar actions with explicit accessible action labels. Use a text button for the primary action. Native help gives the action name, not a paragraph.

`InfoHint(title:text:)`: text-only progressive explanation. Fixed 280-point outer width, 16-point inset, 6-point stack gap, 28-point info target, 250ms hover delay; values come from StudioLayout. Hover opens; leaving closes unless clicked/pinned. Click or keyboard activation toggles the popover, Escape/outside click dismisses. No links or controls in hover content. Correct: explanation beside Quality. Incorrect: hide an error or a required instruction here. Uses sectionTitle/caption/helpIcon semantic font roles. Hover tasks cancel when the view disappears.

`QualityPicker(selection:)`: the same three options in capture and export. High quality (recommended HEVC), Most compatible (H.264), Maximum detail (ProRes4444). These are format/detail/storage tradeoffs, not invented low/medium/high bitrate tiers. Help reflects the current selection. No other profile variants exist.

`Rule(vertical:)`: one physical-pixel separator, using Ink.line and display scale.

## Blocks and states

Recording sheet: source summary/change action → quality → pointer/audio → destination → footer. No selected source: Start disabled. Preparing/starting: disabled primary. Actual stream errors remain visible. One already-authorized screen defaults automatically; macOS source authorization still appears when required.

Export sheet: quality → original dimensions/time → footer. Rendering: progress and cancellation replace settings. Maximum detail retains a visible “Very large file” warning; codec detail lives in help.

Inspector: Canvas/Zoom tabs → grouped source-preserving controls. No source disables editing. None and backgrounds are mutually exclusive visual selections. Manual zooms remain independently editable.

## Scope of this check

The existing studio predates strict layout/type token layers and still has raw spacing/font calls. This checkpoint adds semantic tokens for shared help, not a claim that the whole app is token-clean. New header/home/background work must reuse these components and document additional roles here. Do not silently invent variants.

Pointer motion controls use Recorded, Smooth, Extra smooth; these change the separately rendered arrow only. Auto focus refreshes generated suggestions, never manual regions. Editing a generated region promotes it to manual. No click or gaze inference is implied by “focus.”

BackgroundPicker: Gradient/Color/Image categories (native segmented picker with hidden external label), 4-column swatches; None is the zero-padding action. Eight gradients come from BackgroundPreset; legacy palettes remain readable only. Images use aspect fill and clamp edge pixels. WallpaperPicker displays installed local image assets; no remote downloads or bundled Apple assets. Header uses StudioLayout.headerHeight/headerLeading, native unified traffic lights, consistent 40pt actions and no dropdown chevron on the ellipsis menu.

## Home and feedback

Home uses the shared 56pt header, 190pt library rail, 32pt content inset, adaptive recording cards and native source thumbnails. No destructive library actions. Missing originals stay visible as unavailable.

Feedback is a test-environment layer: a small comment icon toggles selection; hovering outlines the smallest instrumented SwiftUI target; a click opens a 320pt draft beside the pin. Content actions are intercepted while selecting. Escape exits. Saved pins are target-relative, local comments survive a disconnected agent, and delivery state distinguishes saved versus sent. No past-feedback list or old pins are shown. The bottom-right 48pt floating comment button carries a lifecycle status dot. C toggles outside text input; Enter submits; Shift+Enter adds a line. App-owned dialogs reserve room for the button.

Inspector density after in-app feedback: horizontal inset16pt, vertical20pt, tab height36pt with10pt group inset.
