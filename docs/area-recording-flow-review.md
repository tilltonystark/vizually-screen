# Area-recording flow and persistent boundary — November 5, 2026

## Brief

GOAL: Keep the selected recording boundary understandable throughout area capture, and distinguish recording from macOS display authorization.
DONE WHEN: area-only boundary persists during recording, passes clicks, sits outside the crop, clears on stop/failure/cancel, and final app CTA says Record this area. Build, coordinate and encode/decode checks pass; remaining live limits are explicit.
CONSTRAINTS: No new permission bypass, no full-screen dimming during recording, no moving/pulsing border, no feedback-package changes, no private media in Git.

## Research

Apple documents separate actions for selecting a portion and starting it with Record, followed by menu-bar Stop. We use that distinction between selection and recording. [Apple recording guide](https://support.apple.com/en-in/102618), [Screenshot guide](https://support.apple.com/en-au/guide/mac-help/mh26782/27/mac/27).

SCContentSharingPicker is a macOS-owned authorization/source-selection interface. The installed SDK's SCContentSharingPicker.h exposes allowed modes, excluded windows/bundles and changing selected content; it has no area mode or configurable confirmation-button label. Therefore we cannot rename its Share Screen/Share Entire Screen CTA. We must explain that permission step, retain the crop, and give the actual recording action an area-specific label. [Picker documentation](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker).

Attempted live Screenshot app inspection through native UI control; that tool timed out. Native recording behavior beyond the documented flow and the user's observation was not independently exercised. This is not a claim of exact Apple/Shotbase visual parity.

## Resulting flow

1. Select area… opens the crosshair selector; drag/release chooses the region, Escape cancels.
2. Confirmation shows relative area and native pixel dimensions. A thin white outline also remains around that region on the desktop.
3. If needed, Allow area recording… opens system permission selection. Preparation copy explains macOS asks to share the display but only the outlined area is recorded. Cancellation preserves the area for retry. Choosing another display is rejected.
4. Record this area starts the cropped stream. The outline turns orange on the first received video frame and remains visible across app focus/Spaces; it does not dim recorded content or intercept clicks.
5. Stop hides it immediately. Failure, source termination and cleanup also remove it. Dismissing idle recording controls hides the preview outline; reopening restores it. Full display/window capture has no custom area outline.

## Geometry and lifecycle

RecordingAreaIndicator uses four borderless, nonactivating, mouse-ignoring NSPanel strips. Every strip is outside the capture rectangle with a one-point gap. It does not place a translucent window over the interior, add shadows, or rely on NSWindow sharing exclusion behavior. A dark contrast edge and white/recording-orange center keep the border static and subtle. Selection remains locked while recording. At a display edge an external strip may be offscreen; that physical edge is the boundary.

CaptureArea.appKitBounds converts display-local top-left selection points to AppKit bottom-left global coordinates. Screen-parameter notifications reposition the strips; a missing display closes them. Stop and error paths remove the panels, independent of writer finalization.

## Verification

- Release app build passes.
- Geometry checks pass for offset/negative display positions, whole-display edges and four strips not intersecting the recording rectangle.
- Existing real crop encode/decode regression now paints the excluded region orange and checks all RGB channels at decoded corners/edges remain neutral; passes. This tests the crop path, not an actual WindowServer indicator capture.
- Full media regressions pass: source crop, trim, audio-bearing60fps export, cancellation and motion/model checks.
- Existing area-to-saved-video dimensions1402×1214 were verified before this boundary change; not a new live outline verification.
- User began another recording during native verification. Did not quit/relaunch it. New bundle is ready, but live border alignment, click-through, focus/Spaces behavior, stop removal and absence from a real exported capture remain to be confirmed after relaunch. Native coordinate automation still fails noWindowsAvailable.

## Revision: outside-area dimming (November5)

User reports thin indicator does not remain visible while recording and prefers a black overlay on excluded pixels. Replaced strips with nonoverlapping black38%-opacity mask windows covering only the selected display outside the crop. The captured rectangle has no overlay window, tint, border or colored recording state. Full-display/full-window capture gets no custom masks. Area covering the entire display has no excluded region to dim.

Found a possible lifecycle cause: native picker callbacks could call applySource after stream creation, clearing selectedArea and hiding the indicator. Picker update/cancel/error and applySource now reject mutations while stream/recording/busy is active. Capture also freezes activeArea at start, uses it to restore the mask, and prevents idle UI dismissal from hiding it during a stream. First-frame callback ignores a session already stopping. This closes a real reset path; it does not prove that path caused every user-observed disappearance.

Release build and full media checks pass. New tests verify masks are disjoint, inside the display, exclude the recording area and cover exactly the excluded display area, including negative/offset displays and edge/full-display cases. Previous white/orange description above is historical and superseded. App was returned Home to preserve current edit, relaunched safely, and opened on New Recording for user test. Live dimming persistence and output exclusion remain pending user test.
