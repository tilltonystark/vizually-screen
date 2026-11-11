# VizuallyFeedback

Reusable native feedback overlay for **SwiftUI on macOS 15+**. A floating comment button, C toggle, precise instrumented targets, pinned draft, Enter send, Shift+Enter newline, local persistence and optional Agentation delivery. Web/React support is not included in this release.

Vizually Screen imports this exact library. Its app-side adapter contains only host identity, legacy migration, appearance and playback hooks. Fix behavior in `Sources/VizuallyFeedback`; there is no second implementation to update.

## Install

Add this repository in Xcode's Package Dependencies and select the **VizuallyFeedback** library product, or use SwiftPM:

```swift
// Package.swift
 dependencies: [
     .package(url: "https://github.com/tilltonystark/vizually-screen.git", from: "0.7.0")
 ],
 targets: [
     .target(name: "YourApp", dependencies: [
         .product(name: "VizuallyFeedback", package: "vizually-screen")
     ])
 ]
```

The repository also contains the recorder. Selecting the library product builds only the feedback library and Apple's frameworks, not the recorder or its resources. For local development use a path dependency; [the independent sample](../../Examples/FeedbackDemo) demonstrates that integration.

## Integrate

```swift
import SwiftUI
import VizuallyFeedback

@main @MainActor struct YourApp: App {
    @StateObject private var feedback = FeedbackStore(
        configuration: FeedbackConfiguration(
            projectID: "com.example.your-app", // Stable and unique per project
            appName: "Your App",
            build: "1.0.0"
        )
    )
    var body: some Scene {
        WindowGroup {
            ContentView()
                .feedbackSurface(
                    store: feedback,
                    context: FeedbackContext(route: "home")
                )
        }
    }
}
```

Register the controls and text you want to select precisely:

```swift
Text("Projects")
    .font(.title)
    .feedbackTarget("projects.heading", "Projects heading")

Button("Create project", action: createProject)
    .feedbackTarget("projects.create", "Create project")
```

Use stable, unique semantic IDs. `#fileID` and `#line` capture the **consumer's** source location by default. Nested targets accumulate; the smallest containing target wins. Every registered target also exposes a native “Comment on …” accessibility action; hosts can call `store.requestComment(on: "projects.heading")` for their own keyboard/accessibility integration. If SwiftUI merges adjacent text into one accessibility element, place `.accessibilityElement(children: .contain)` on their parent to preserve separate entries. Unregistered areas fall back to their containing registered section or surface. This is native SwiftUI instrumentation, not automatic DOM traversal. Register granular text and controls explicitly.

Place the surface outside the entire content you wish to annotate. If your app extends into the titlebar, apply `.ignoresSafeArea(.container, edges: .top)` to the combined content **and** surface, not just to a child. Each app-owned sheet/window needs a surface using the same store and its own route. OS-owned pickers, native menu popups and another app's UI are outside this overlay.

## Customize without forking

- `FeedbackConfiguration`: project ID, display name, build, storage directory, session identity, endpoint and optional legacy migration.
- `FeedbackContext`: route, optional playback time and additional string metadata. Values are captured when a pin is created.
- `FeedbackAppearance`: host fonts and colors. No bundled fonts or recorder theme dependency. Vizually Screen supplies Geist; another host can use its own design system.
- `.feedbackSurface(..., bottomInset: 76, onActivate: pausePlayback)`: reserve space in a small modal and pause host motion when selection begins. Normal windows default to no inset.
- `FeedbackTransport`: implement another delivery service. `AgentationTransport` is provided, with an injectable `FeedbackHTTPClient` for integration/testing.

Use one shared store per project. Give different projects unique IDs and storage folders. The default folder is `~/Library/Application Support/<projectID>/Feedback`. A mismatched project archive is rejected instead of overwritten. Do not put secrets in context metadata or IDs.

## Interaction

Click the bottom-right comment bubble to open the feedback log. It lists submitted comments newest first with the target, date, status and any question awaiting an answer. Choose **New comment** from the log, or press **C** outside editable text to toggle selection directly. Hover outlines the smallest registered target. Click opens a draft beside the pin. **Enter** sends; **Shift+Enter** inserts a line. Clicking outside a draft dismisses it; Escape clears selection and exits feedback mode. Leaving the app or changing route clears the current selection. Normal input remains intact outside feedback mode.

The button tracks the latest comment: amber queued or waiting, blue in progress, green resolved. Local-only and dismissed feedback use a neutral dot. In progress means the agent acknowledged the feedback; it does not indicate a running process.

## Agent connection

Default endpoint: `http://127.0.0.1:4747`, using the [Agentation REST API](https://www.agentation.com/api). The server/MCP connection must already be available to the agent. The overlay does not install a server, launch an agent, or wake an idle chat. An active agent reads/watches the app-specific session and acknowledges/replies/resolves through Agentation. `FeedbackStore.sessionID` exposes that session; never enumerate unrelated projects' sessions.

Pass `endpoint: nil` for local-only use. Comments survive disconnects and delivery retries. Receipt reconciliation uses a local UUID to prevent duplicates after uncertain delivery. A failed session GET does not create a new session; only a confirmed 404 does. Sync merges receipts without replacing comments added in flight.

For agents: acknowledge a comment when work starts. Use an Agentation thread reply beginning with `Waiting for input:` followed by the actual question when an answer is needed. The app shows the question in the log. The user can answer in the agent chat. After receiving an answer, reply with `In progress:` to clear the question and acknowledge the annotation if it was still queued. Resolution or dismissal takes precedence over these replies. Resolve feedback only once the user accepts the fix.

The payload contains comment text, target ID/label, source file ID/line, bounds/pin, build, route and explicit host context. It does **not** capture screenshots, video, environment variables or a DOM dump. All configured endpoints receive that payload; keep the default local endpoint unless you intentionally configure another destination.

## Persistence and migration

`feedback.json` is an atomic, versioned archive with project identity, session identity and records. A corrupt or wrong-project archive is preserved and new writes are blocked with an error. Do not fix it by silently discarding the original file.

Vizually Screen opts into importing its original JSON array and legacy UserDefaults session key. Its existing session and comments are retained; the first write upgrades the file. Other hosts default to no legacy import. Integrate the package on macOS MainActor, as in the sample.

## Verify

```sh
bash scripts/check-feedback-package.sh
bash scripts/build-app.sh
# Optional disposable native sample:
bash scripts/build-feedback-demo.sh
```

Checks cover public model roundtrip and coordinate validation, archive isolation, legacy migration, corrupt-file preservation, failed-session identity, uncertain POST deduplication, server session recovery, remote resolution and in-flight comment preservation. The script separately builds the sample consumer using only the public library product. CLI-only checks do not establish hover, focus, window drag, popup and native keyboard behavior: perform the [native release checklist](release-checklist.md) before calling those verified.

## Maintain and update

1. Change the canonical library source, not copied app code.
2. Add a regression for persistence/transport/API behavior when warranted; run checks and sample build.
3. Test the same interaction in Vizually Screen and the sample host.
4. Update [CHANGELOG](CHANGELOG.md) and the public API documentation.
5. Tag a tested semantic release. Patch versions fix behavior; minor versions add compatible API; major versions change API or persistence incompatibly (pre-1.0 changes are documented explicitly).
6. Consumers update their SwiftPM dependency resolution. A published version cannot silently update another app's already-built binary. Local/path consumers see source changes when rebuilt; this app always builds from the canonical source.

Current first library release: **0.7.0**, aligned with this repository's app release/tag. No additional third-party runtime dependency.
