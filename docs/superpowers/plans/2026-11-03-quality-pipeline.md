# Quality pipeline implementation plan

Objective: preserve screen detail end-to-end and replace unmeasured quality claims with reproducible evidence. User explicitly authorized continuing implementation and major milestone pushes.

1. Inspect installed Shotbase with available REA CLI. Retain bounded evidence and distinguish imported frameworks/symbols from observed behavior. Do not infer encoder settings from strings alone.
2. Add native pixel sizing from SCContentFilter contentRect/pointPixelScale. Remove silent 4K cap. Use an explicit capture writer for HEVC high-quality and ProRes 4444 editing masters, with bounded queues/drop reporting and faithful timestamps/audio.
3. Add explicit export profiles (high-quality H.264/HEVC and ProRes master), preserving dimensions and source cadence. Use the same composition as preview. Expose progress/cancel and pre-export summary including quality/storage tradeoffs.
4. Add deterministic screen-detail benchmark: small text, colored text, fine lines, movement and flat colors. Encode/decode reference and candidate clips; measure actual codec, dimensions, timestamps, RGB PSNR and text/line ROI error. Save results and comparison crops. These are synthetic pipeline measurements, not live capture or competitor parity proof.
5. Inspect Shotbase export settings and produce a controlled output from our own calibration content if its UI permits. Do not alter existing personal captures. Seek user action only for required permission/login prompts.
6. Run meaningful checks, render native UI states, update HANDOFF and status report, push milestone. List remaining live capture/audio/competitor comparisons honestly.

## Milestone outcome

- Implemented: bounded REA evidence, native picker/pixel sizing/writer, explicit profiles, separate smoothed arrow, continuous camera, independent 60fps composition, export progress/cancel and deterministic benchmark.
- Verified: native finalized capture, synthetic decode/measurements, trimmed 60fps output with audio and cancellation cleanup. See `docs/quality-report.md`.
- Not verified: matched Shotbase export, subjective side-by-side motion, long moving capture, audio sync and HDR. The inaccessible native overlay prevented a controlled competitor export; no parity claim is made.
- Final packaging/UI review and remote commit are recorded in the active brief and handoff.
