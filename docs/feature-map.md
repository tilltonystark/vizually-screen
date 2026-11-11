# Vizually Screen: feature universe and release gates

Updated 2026-11-05. This is a working inventory, not a claim of complete competitor coverage or parity. No percentage complete is meaningful until the quality gates below have been measured. The recording pipeline is implemented; matched Shotbase output quality is **unverified**.

## Evidence and interpretation

- **U:** User's November 4 menu-bar screenshot. It establishes the listed entry points, not their behavior or quality.
- **L:** Earlier live inspection recorded in [investigation](investigation.md) and local Shotbase evidence. Limited editor/workflow observation; not an exhaustive hands-on audit.
- **A:** [Shotbase's official product page](https://shotbase.com/), checked November 4. Advertised capability, not independently tested.
- **V:** Vizually Screen source/build/checks; see [handoff](../HANDOFF.md), [quality report](quality-report.md), [motion review](motion-focus-review.md), [source-fit review](source-fit-review.md).

P0 means release-blocking core quality. P1 means a valuable next workflow after core gates. P2 means validate demand first. P3 means deliberately defer. These priorities express our users' needs, not Shotbase's development order. “Built” never means “competitor benchmark passed.”

## Capability map

| Capability | Why it matters here | Priority | Vizually Screen status | Shotbase evidence | Acceptance / quality gate |
|---|---|---|---|---|---|
| Native-resolution display recording | Legible small UI and text | P0 | Built; synthetic media checks; live endurance pending | U: Recording / Display | Matched native source; inspect decoded text and fine lines, no accidental scaling |
| Window recording | Clean app walkthroughs | P0 | Built; first-frame geometry crop | U: Window | Small window has exact content bounds; minimize/resize behavior tested |
| Permission / source selection | Recording must actually start | P0 | Native picker implemented; live regression pending | U: recording entry; access behavior unverified | Fresh grant, existing grant, denial, relaunch and picker cancellation work |
| Single-display default | Fewer unnecessary decisions | P0 | Built when broad access already granted | Unverified | One display needs no redundant chooser; multiple displays remain explicit |
| Source-fit canvas | No unexplained black margins | P0 | Built, crop encode/decode checks pass | L: editor only; exact comparison pending | All four corners correct in raw capture, preview and export |
| No-background output | Exact screen/window dimensions | P0 | Built, zero padding default | Unverified | Full source dimensions retained, including portrait and odd aspect ratios |
| Capture timing / dropped frames | Smooth scrolling and movement | P0 | Writer counters exist; sustained test pending | Unverified | Compare timestamps and drops under same workload; static screen need not emit unique frames |
| System audio | Useful narrated demos with playback | P0 | Built; exported track checked | Unverified | Live system audio and synchronization measured, not merely track presence |
| Microphone / camera | Narrated or presenter-led demos | P1 | Not built | Unverified | Device switching, drift, echo and placement validated before shipping |
| Pointer smoothing | Fast direction changes stay readable | P0 | Built; recorded/smooth/extra-smooth; math tests | L: motion controls; output comparison pending | Same raw gesture replay; no overshoot, late clicks or hidden-gap interpolation |
| Automatic focus / zoom | Direct viewer attention | P0 | Built, editable suggestions; synthetic tests | A: automatic zoom | Dwell/move/click sequence compared; no distracting zoom pumping or incorrect target |
| Manual zoom editing | Recover from bad suggestions | P0 | Built; edits preserve manual intent | L: editor | Add, move, edit, remove and scrub; preview/export agree |
| Camera easing | Zooms feel intentional | P0 | Built; continuous ramps | L: motion controls | Inspect entry/exit, interrupted moves and frame-by-frame continuity |
| Trim and playback | Remove dead time confidently | P0 | Built; timeline trim handles plus inspector sliders | L: timeline | First/last frame, short clips and audio match selected range |
| Post-recording crop | Remove unwanted edges without rerecording | P1 (user requested) | Freeform crop sheet; project, preview and export use the same crop | Unverified | Off-center crop preserves source pixel placement, dimensions, cursor/zoom alignment, and original file |
| Export choices | Understand size versus fidelity | P0 | High quality / Most compatible / Maximum detail | Unverified | Decoded detail, actual size, compatibility and export speed measured per option |
| Export cancellation / failure | No corrupt result or lost work | P0 | Cancellation cleanup test passes | Unverified | Disk full, cancel and encoder error recover without losing project |
| Saved projects / reopen | Keep edits between sessions | P0 | Built; legacy format supported | L: library | Save/reopen preserves source, trims, focus, pointer and background |
| Home / local recording history | Find earlier work | P1 | Built; home thumbnails/open/return observed | U: Open Base; A: library | Old and new sources discoverable; missing file is clear; latest edit reopens |
| Library rename / Trash | Manage past recordings | P1 (user requested) | Built: titles preserve paths, confirmed Trash/removal; storage/rollback tests pass; native UI check blocked by locked Mac | Unverified | Rename survives reload/search/editor; Trash recoverable, no stale reappearance or lost edit associations |
| Public playback links / guest feedback | Share a demo for timestamped feedback | P1, separate hosted milestone | Feasibility assessed; no backend or public uploads; not built | User Loom reference (not Shotbase evidence) | Explicit publish, browser-compatible export, revoke/delete, persistent timestamped comments/reactions and guest abuse controls |
| Menu-bar quick recording | One click from any app | P1 | Start controls, open and stop implemented; release build passed, live cross-app check pending | U: Recording / New Capture | Open source selection from menu, stop reliably, no duplicate windows |
| Global capture shortcuts | Fast repeat capture | P1 | Not built; in-app shortcuts only | U: several shortcuts | Works while another app focused; collisions and accessibility handled |
| Capture tray | Retrieve recent captures quickly | P2 | Not built | U: Capture Tray | Validate whether home + menu recents already meet need |
| Screenshot capture | Quick visual communication | P1, after recording gates | Not built | U: Screenshot | Native pixels, correct source and fast save/copy; separate from video pipeline |
| Screenshot annotation | Highlight a point quickly | P1, after screenshot capture | Not built | A: arrows, text, highlights, shapes | Crisp text, undo, editable placement and exported alignment |
| Area capture | Restrict capture to a region | P0 (user requested) | Area diagram and native1402×1214 crop verified; outside-area dimming masks replace failed thin border; user confirmed dimming persists throughout capture and clears on Stop; cursor/mixed-DPI edge checks remain | U: Area | Accurate Retina/cursor coordinates, cancel preserves source. One display per selection; macOS15.2+; spanning displays deferred |
| Scrolling screenshot | Long documentation | P2 | Not built | A | Stitching has no repeated or missing rows; establish demand first |
| Web-page capture | Long page or viewport | P2 | Not built | U; A: full-page/viewport | Font/layout fidelity, lazy-loading and private page handling |
| Text extraction | Copy otherwise inaccessible text | P2 | Not built | U: Text | OCR accuracy across scales/languages; never claim recording improvement |
| Gradient / solid backgrounds | Present recordings cleanly | P1 | Built; renderer corner tests | L; A: backgrounds | Preview/export match; no edge artifacts; source fit remains explicit |
| Image / local wallpaper backgrounds | More useful visual choices | P1 | Built; imported image copied locally | A: backgrounds; wallpaper source unverified | Aspect-fill and missing image behavior; no bundled third-party wallpaper |
| Frames / shadows / borders | Optional visual presentation | P2 | Partial: radius/shadow | A | No clipping at zoom boundaries; never compromise captured detail |
| Watermark / brand presets | Repeat branded exports | P2 | Not built | A | Export placement and saved preset roundtrip |
| Social output presets | Deliver alternate aspect ratios | P2 | Not built | A | Explicit crop/fit choice; never silently widen a native source |
| 3D transforms / text effects | More stylized storytelling | P3 | Not built | A | Defer until core camera motion and readability meet benchmark |
| Animated screenshots | Small motion snippets | P3 | Not built | A | Demand and quality/file-size tradeoff established |
| Share links / viewer comments | Async external review | P2 | Not built; local app feedback is different | A | Explicit upload, privacy, revocation and receiver experience validated |
| AI filenames / tags / search | Organize large libraries | P3 | Not built | A | Start with reliable local library/search; measure whether AI helps |
| Capture reminders | Follow-up utility | P3 | Not built | A | User demand before additional notifications |
| Settings / updates | Predictable maintenance | P1 | Partial app controls; no updater | U | Stable identity, permission continuity, migration and signed distribution |
| Native pinned app feedback | Report precise defects to this build | P1 | Shared VizuallyFeedback library; independent host and native keyboard checks pass; pointer audit pending | U: Send Feedback is not evidence of equivalent annotation | Hover targets accurate, comments persist with source context, no accidental capture activation |

The A rows summarize advertised features from the [official Shotbase page](https://shotbase.com/). Their existence alone is not a reason to implement them. Unverified rows require observation, not inference.

## Release intervals and stopping rules

1. **Source-fit checkpoint — pushed:** native bounds, zero-padding default, simple export names. Gate: rerun the user's exact small-window case; current synthetic crop test is not that live proof.
2. **Motion checkpoint — pushed:** smoothing, automatic editable focus, continuous camera ramps. Gate: identical source gestures and matched Shotbase output review. Mathematical continuity alone does not establish pleasant motion.
3. **Workspace checkpoint — pushed (342bf61); follow-up polish in progress:** rename, aligned header, backgrounds, home/reopen, pinned app feedback. Gate: normal capture → edit → home → reopen → export plus feedback save/reopen. Commit and push with evidence and explicit remaining gaps.
4. **Core quality release — next:** fix defects found by the matched comparison before new capture types. Gate: native detail, timing, audio, permission and endurance matrix below.
5. **Quick access — partial:** menu-bar start/open actions now implemented; global shortcuts remain deferred. Gate still pending: complete capture from another foreground app without project loss. Cmd+N opens recording controls only while the app is focused.
6. **Screenshot workflow — candidate:** capture plus focused annotation, followed only by capabilities supported by actual demand. Do not start scrolling/web/OCR/AI as one broad parity project.

Intervals are shippable checkpoints, not dates or feature-count targets. A failed P0 gate stops breadth work. Record any reprioritization here with its reason.

## Matched quality protocol

Record hardware, macOS, Shotbase version, app build, display scale, selected source, codec, output dimensions and frame rate. Use a disposable calibration window, never private work. Capture the same static fine text, colored one-pixel lines, scroll, fast turns, precise clicks, dwell and source resize/minimize sequence in both tools. Keep raw sources and exported results separately so capture defects are not confused with editing defects.

| Gate | Evidence required | Current result |
|---|---|---|
| Detail | Decoded crops at native size; text/line fidelity and scaling comparison; bitrate/file size alongside fidelity | Synthetic codec comparisons available; matched Shotbase pending |
| Source fit | Actual selected display/window bounds and decoded four-corner images, portrait/small window included | Synthetic crop encode/decode passed; exact reported live case pending |
| Timing | Frame timestamps/durations, writer drops, 60 fps moving workload and repeat under load | Synthetic export 60 fps checked; long live run pending |
| Motion | Identical raw pointer sequence; frame inspection plus side-by-side viewing of dwell, turns and interrupted zooms | Continuity/idle/jitter tests passed; competitor viewing pending |
| Audio | Actual loopback/mic impulse or clap and drift at beginning/end; target sync within 40 ms, explicitly a target | Track/trim checks only; sync unverified |
| Reliability | Permission states, missing source, disk-full/cancel, 5-minute then 30-minute capture/export | Cancellation checked; full matrix pending |
| Editor parity | Same paused and playing frame in preview/export after background/zoom edits | Cache fix built; final live regression pending |
| Library | Save edit, home, reopen, restart, missing source, legacy recording; no mutation of originals | Catalog regression passed; native thumbnail/open/home observed; restart-edit matrix pending |

PSNR or a high bitrate is supporting evidence, not a substitute for readable output. No claim of “same quality” until these records exist. Update each row with artifact links and measured results, not just a checkbox.

## Remaining competitor audit

Next bounded observation: menu-bar → new capture → source selection → stop → edit → export; then screenshot → annotation → save/copy → tray/library. Record actual defaults, click counts, failure paths and output artifacts. Inspect scrolling/web/text only if those workflows rise in priority. Mark every untouched control untested. Stop at observable behavior; do not invent proprietary capture or smoothing algorithms from interface labels or linked frameworks.
