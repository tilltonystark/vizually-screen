GOAL: Make Framecraft usable for capture and improve recorded/output detail and motion for Satyam.
CONTEXT: HANDOFF.md; docs/superpowers/plans/2026-11-03-quality-pipeline.md. Work was already authorized and underway when the prompt-optimiser instructions arrived. This brief pins the current shippable milestone; further broad milestones require discussion under the new instructions.
DONE WHEN:
- Native source picking produces a finalized capture despite the old settings-entry failure.
- Explicit export profiles preserve dimensions and produce 60 fps output; audio retention and cancellation cleanup pass.
- Pointer samples can be separately smoothed/rendered; overlapping zooms remain continuous; old baked cursors are described accurately.
- A reproducible synthetic quality report and REA evidence are retained, with competitor parity marked unverified.
- App builds, current edit is preserved before relaunch, docs/handoff updated and milestone pushed.
CONSTRAINTS: Native macOS, light mode, Geist; no global security/permission weakening; no private captures or licensed skill files in Git. Existing edits preserved. SDR only for this milestone. Use the native stack.
INPUTS & SOURCES: Project source, user permission screenshot, installed Shotbase 1.7.1, REA evidence under docs/evidence, official Apple framework docs recorded in quality report.
STEPS:
1. Diagnose capture access and output pipeline → specific failure causes.
2. Implement native source picker and pixel/encoding/motion fixes → buildable app.
3. Run real capture and synthetic encode/decode checks → report and artifacts.
4. Preserve current edit and inspect final UX → review findings.
5. Update handoff and push milestone → verified remote commit.
CHECKS: Report each DONE WHEN item met/not met with evidence. No matched Shotbase output or HDR claim without measurement. Keep source cursor/codec limitations explicit.
OUTPUT: Native v0.3 build, checked source, concise status, GitHub milestone and handoff.
ASSUMPTIONS: High fidelity is more important than minimum file size; expose ProRes 4444 as an explicit large-file option, while default HEVC remains available. New cursor smoothing uses an arrow overlay; preserve real system cursor shapes by turning smoothing off. Existing baked-in cursor cannot be removed.

OUTCOME (2026-11-03):
- Met: native picker/finalized capture; explicit profiles/native dimensions/60fps audio export/cancellation; separate smoothed arrow and continuous camera; retained synthetic and REA evidence.
- Met: final debug/release build and behavioral media checks; current edit preserved locally before relaunch.
- Incomplete: final populated-preview/export-sheet visual review because native UI control timed out after Open Project; matched Shotbase output and subjective motion remain unverified.
- Repository push status: recorded in the milestone commit and final user update.
