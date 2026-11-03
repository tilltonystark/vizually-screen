# Framecraft project instructions

Read HANDOFF.md first. Preserve the native macOS SwiftUI/ScreenCaptureKit architecture unless the user requests a platform change. Use bundled Geist for app-owned text; keep light mode and semantic appearance tokens. Keep meaningful checks runnable with command-line Swift (no XCTest dependency on this Mac).

Push major authorized milestones to https://github.com/tilltonystark/vizually-screen and update HANDOFF.md with verified behavior and remaining gaps. Never commit secrets, licensed skill content, generated .app bundles, .build artifacts or local captures. Do not assert Screen Studio/Shotbase quality parity without a controlled output comparison.

If Figma is used, always use satyam@vizually.design unless the user explicitly switches. Previously verified connection: link_6abd03794c848191980d937198c2b501; verify with whoami if identity is unclear.
