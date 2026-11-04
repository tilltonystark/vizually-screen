GOAL: Turn the native recorder into Vizually Screen with cursor-led editing, polished backgrounds and a persistent home library.
CONTEXT: User approved this milestone order on 2026-11-03 after the source-fit bug report. Earlier requirements remain: native macOS, light UI, Geist, high-quality SDR output, Shotbase reference, push every major checkpoint.
MILESTONES:
1. Source fit and simple controls → metadata crop encode/decode passes, no default framing, plain quality options and info cards; push.
2. Cursor-led motion → smooth fast pointer moves, propose editable focus/zoom regions from dwell/movement, shared preview/export path, deterministic motion checks; push.
3. Identity and backgrounds → visible name Vizually Screen, corrected header spacing, None/color/gradient/image choices including available local macOS wallpaper selection; inspect and verify export; push.
4. Home and recordings → browse previous captures, thumbnail/title/duration, open original with adjacent saved edit; preserve changes on return home; verify library load/reopen; push.
CONSTRAINTS: Preserve originals and existing project compatibility; do not claim competitor algorithm equivalence. No private captures or licensed skills in Git. Use current native design system. macOS stock wallpaper assets stay local; do not redistribute them. Keep code identity/source module names where changing would break existing permissions or projects.
CURRENT MILESTONE 2 STEPS:
1. Inspect existing cursor samples and Shotbase motion controls → evidence and bounded motion rules.
2. Add motion settings and dwell-based editable zoom suggestions → reusable deterministic model.
3. Render smooth cursor/camera transitions in preview/export → real motion sample.
4. Verify math, decode cadence and UI behavior → documented checkpoint and pushed commit.
CHECKS: Each milestone has evidence before a completion claim. Preserve existing manual zooms when applying suggestions unless explicitly replaced. No invented click data. Old baked cursors cannot be removed.
ASSUMPTIONS: Automatic focus follows pointer dwell and deliberate movement, not inferred eye gaze or clicks. Background import is local. Existing Vizually Screen recordings remain discoverable after rename.

ADDITIONAL USER REQUEST (2026-11-04): After the home/library checkpoint, add native in-app feedback mode. Hover highlights instrumented SwiftUI controls; clicking pins a local comment with stable element ID, source-file/line, viewport and playback context. Include a local feedback list and copy/export context. No DOM exists in a native SwiftUI app. No third-party transmission is requested; comments stay in Application Support and out of Git. Push this checkpoint too.
