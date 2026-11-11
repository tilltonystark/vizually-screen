GOAL: Make trim discoverable and let people crop a recording after capture.

CONTEXT: Two new Vizually Screen notes target the video track and preview. Satyam approved freeform crop without aspect-ratio presets.

MILESTONES:
1. Put trim handles on both edges of the video track. Dragging and arrow-key adjustments set the existing start/end bounds; clicking the track still scrubs.
2. Add a Crop sheet with the original frame, drag selection, keyboard-adjustable margins, Reset, Cancel/Escape and Apply. Save the crop with the project and use the same source-pixel bounds in preview and export.
3. Verify an off-center crop against decoded source pixels, check output dimensions and audio, and verify cursor placement with zoom. The original file must remain unchanged.

CONSTRAINTS: Keep trim and crop non-destructive. Store one crop for the whole clip. Keep zoom and pointer data in source coordinates. Preserve older project files.
