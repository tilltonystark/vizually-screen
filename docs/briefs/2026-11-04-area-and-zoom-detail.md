GOAL: Record a chosen display region at native pixel density, then diagnose and improve zoom detail.
CONTEXT: User approved area selection first, zoom-detail investigation second. Feedback-package work remains parked.
DONE WHEN:
- Drag selection captures only the selected rectangle, with matching cursor coordinates and no background padding.
- Escape cancels without losing the previous source; dimensions follow source pixel density.
- Selection geometry checks and release build pass; live capture limits are reported.
- Zoom-detail findings distinguish source pixels, preview scaling and export compression; fixes have measured evidence.
STEPS:
1. Add display-area overlay and region geometry; wire source selection to stream sourceRect.
2. Verify geometry, crop/export regressions and native build; push checkpoint.
3. Audit capture/preview/export sampling and measure zoomed detail before changing quality behavior.
CONSTRAINTS: Preserve originals, native macOS/Geist/light controls; no fabricated Shotbase parity; no private captures in Git.
