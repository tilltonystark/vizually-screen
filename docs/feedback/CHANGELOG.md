# VizuallyFeedback changes

## Unreleased

- Keep comment text constrained to the writing area at every modal size, including when the vertical scrollbar appears.
- Open a compact history from the comment bubble. See each saved comment, its current status, and any question from the agent. Use New comment or C to select a target.
- Give the comment field a light border and put the labeled send arrow inside it. Return still sends and Shift+Return still adds a line.

## 0.7.0 — 2026-11-04

First extracted Swift Package library, used directly by Vizually Screen and an independent sample.

- Native accessibility actions and public target-selection requests for precise commenting without a pointer.
- Public project configuration, context and appearance; host-independent SwiftUI targets/surface and configurable transport.
- Floating button, C toggle outside text fields, precise nested targets, pinned draft, Return submission and Shift+Return newline.
- Outside-click/Escape/route-change/app-deactivation dismissal; measured draft hit region.
- Local versioned archive with project isolation and legacy Vizually Screen comment/session import.
- Local-only operation, optional Agentation HTTP integration, receipt reconciliation and latest-comment lifecycle status.
- Failed GET preserves session; confirmed404 recovers it. Uncertain POST retries deduplicate; sync preserves newly added comments.
- Regression executable and a separately built public-API sample consumer.

Native pointer/drag and full popup matrix must be recorded in the release checklist; compilation is not a claim of exhaustive UI verification.
