# Cursor-led motion checkpoint

Completed code/media verification on 2026-11-04. This is an independent implementation, not a recovered Shotbase algorithm.

- New recordings retain raw pointer samples. Rendering offers Recorded, Smooth (55ms Gaussian sigma), and Extra smooth (100ms). Filtering uses timestamp-bounded neighborhoods and stops at visibility/sample gaps. A monotone cubic interpolator avoids sharp segment-velocity changes and coordinate overshoot.
- Camera entrances/exits use 0.85s maximum quintic ramps. Overlapping transforms remain continuous.
- Automatic focus analyzes pointer motion at 10Hz, finding settled moments after deliberate travel. Tiny jitter alone does not trigger zooms. Suggestions use 1.65× scale and remain editable. Refreshing preserves manual zooms and excludes overlapping suggestions; editing a suggestion promotes it to manual.
- New captures can add automatic zooms after finalization. Existing pointer-sidecar recordings can use Auto focus. Baked cursors in older video cannot be removed or smoothed.
- Shared render state prepares smoothing outside the per-frame path. Active playback edits no longer seek. Paused edits invalidate the cached composition identity on a coalesced refresh; the native paused-preview regression still needs visual confirmation.
- Demo v3 has a real pointer-free 1440p60 source, a separate pointer track and generated zooms.

Checks passed: dwell detection for two focus targets, idle/jitter rejection, manual-zoom protection, project roundtrip, sharp-turn peak-acceleration reduction, interpolation bounds, camera continuity, capture-content crop encode/decode, 60fps audio export and cancellation cleanup. QualityBenchmark rendered eight-second recorded/extra-smooth variants with two generated focus regions using the actual export compositor. Run `VizuallyScreenQuality /tmp/framecraft-quality --motion-only` to reproduce.

Native app access resumed and a user recording with two zooms was observed. Its current edit was saved before replacing the app. Subsequent native UI calls timed out after the Save panel; final paused-preview and pointer-control visual checks remain open. No controlled Shotbase side-by-side motion/export comparison has been completed.
