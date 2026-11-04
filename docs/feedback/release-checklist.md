# Feedback package release verification

Updated 2026-11-04. Record actual results; unverified is not passed.

| Check | Result |
|---|---|
| Library has no recorder/editor/font-resource dependency | Source boundary checked; standalone consumer built |
| Public API consumed from another package | PASS: separate FeedbackDemo built through only the public library product |
| Store/transport regression suite | PASS: final package check script, including storage/transport regressions and sample build |
| Existing app comments/session survive extraction | PASS fixture; real host loaded all13 existing comments and original lifecycle state; its legacy file upgrades on first write |
| Title, recording count and sidebar target individually | Registered; app-name text opened precisely through native action; sample title highlighted precisely; pointer/count/sidebar recheck pending |
| C toggles twice outside text; typing C remains input | PASS in independent native consumer: C toggled on/off; C inside draft remained text |
| Return sends; Shift+Return inserts line | PASS in independent native consumer; persisted two-line text matched exactly |
| Outside click dismisses; Escape exits from focused draft | PASS Escape from focused draft; outside-pointer click blocked by CUA noWindowsAvailable; user check pending |
| Header reaches full surface; app-owned sheets have overlay | PASS app-name draft on full header in real host; exhaustive sheet/popup matrix pending |
| Home mark removed; count centered; refresh in header; icon surfaces | Observed in seven-fix native build |
| Window stays still on body drag and moves on header drag | Background drag disabled; header-only WindowDragGesture; native drag check pending |
| Modal/edge placement, resize, inactive window, two windows | Unverified |
| Remote ack/resolution reflected in indicator | PASS transport regression; real host showed prior acknowledged state; final live lifecycle roundtrip pending |
| Repository/consumer tag and install instructions | Prepare after final checks |
