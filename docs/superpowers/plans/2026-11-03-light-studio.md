# Light Studio Implementation Plan

> **For agentic workers:** Apply Superpowers execution and verification guidance; review the final change independently.

**Goal:** Deliver the authorized light-mode native editor redesign with Geist and a live appearance tuning tool.
**Architecture:** Keep the media core. Split theme/components, studio layout, inspector, timeline and Appearance Lab into focused native files. Add editor metadata/thumbnails/demo/selection for a populated inspectable experience.
**Tech Stack:** SwiftUI, AppKit/Core Text, ScreenCaptureKit, AVFoundation/Core Image.
**Spec:** docs/superpowers/specs/2026-11-03-light-studio-design.md

## Global constraints
- Native macOS 15+, light mode, bundled Geist; no system-wide font setting changes.
- Existing import, recording, trim, zoom and export must remain functional.
- Auth token never saved to source or docs; licensed skills remain local and ignored by git.
- No parity claims without observed evidence.

## Tasks
- [x] Theme and fonts: bundle official regular/medium/semibold + license, process registration, OKLCH-derived sRGB colors, validated appearance JSON; check registration, bounds and contrast.
- [x] Editor staging: real generated demo asset, metadata, thumbnails, selection, reliable play state and seek. Preserve source/export contract; verify actual media export.
- [x] Studio: light toolbar, dominant canvas, recording sheet, Canvas/Zoom inspector, interactive thumbnail/zoom timeline; compile and exercise UI.
- [x] Appearance Lab: separate native window, bounded live controls, import/export config with visible saved path; inspect and verify serialization.
- [x] Review findings fixed, final build passed, native empty/populated/lab checks performed; independent reviewer stopped at account usage limit and remaining review was done by author.

Validation: checks executable passed real demo+export/decode and model/theme bounds/roundtrips/contrast. Release app built and ad-hoc signed. After the user unlocked the Mac, the final build was relaunched and the source-thumbnail focus pad, playback/pause, zoom selection, background/padding updates were visually checked.

## Review focus
- Cancelled dialogs and media loading failure preserve the previous project.
- Very short media and zoom at the end do not create invalid slider ranges.
- Seeking while paused and trimming do not race or leave stale preview.
- Appearance JSON rejects NaN/out-of-bounds values; all text remains readable over permitted palettes.
- Busy/recording states disable destructive edits; no fake controls suggest unsupported features.

## Decisions and progress
The user explicitly authorized the UI revamp; proceed on reversible implementation without adding an approval checkpoint. UI-only polish is verified visually; behavioral additions receive meaningful automated checks. The current repo has no baseline commits; preserve all existing files rather than manufacture an unrelated worktree.
