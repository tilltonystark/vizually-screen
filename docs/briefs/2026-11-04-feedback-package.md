# Feedback fixes and reusable package

GOAL: Make the seven submitted UI corrections and maintain a reusable feedback library used directly by Vizually Screen.
CONTEXT: HANDOFF.md and docs/feature-map.md; seven acknowledged annotations in app-scoped Agentation session mw1sprt2-3y23fq. No unrelated sessions.
DONE WHEN:
- Outside click/Escape clear feedback selection; normal control interaction and text input remain intact.
- Home has text-only brand, subtle icon surfaces, aligned count badge, granular heading/count/sidebar targets and header refresh; refresh runs on app activation/home return.
- Window drags from header, not content.
- Host app imports the canonical package rather than keeping a copied implementation.
- Package has configurable project identity, local storage, transport and host context; no Editor/recording/theme dependencies.
- Independent consumer builds, persistence/transport/interaction checks pass, install/update docs and GitHub checkpoints exist.
CONSTRAINTS: Keep local comments and session identity; do not publish comments/private captures. Native UI through CUA only. Preserve C toggle, pinned draft, Enter send, Shift+Enter newline, bottom-right FAB and latest-comment status. No duplicated app/package source. Do not imply annotation acknowledgement is a process heartbeat.
STEPS:
1. Apply seven authorized app fixes → build and native review.
2. Extract reusable package after platform/checkpoint confirmation → migrate actual host to library.
3. Verify independent consumer and meaningful behavior → versioned docs, build, commit and push.
CHECKS: Build app; test target selection/dismissal and offline receipt merging; verify native pointer/key/window behavior where control allows; mark unavailable checks unverified. Inspect staged files and remote HEAD.
OUTPUT: Package/library, sample consumer, documentation, working app and pushed commits.
ASSUMPTIONS: User approved all three checkpoints and SwiftUI/macOS first. Web/React is deferred. Publish a reusable Swift Package library product from this repository, retaining one canonical implementation used by Vizually Screen.
