# Public recording links — feasibility (November5)

User reference: Loom page with browser playback, guest comments, timestamp links and reactions. This is product sharing, separate from the parked in-app agent-feedback package.

The current repository is a local SwiftUI/macOS app with no deployed upload service, hosted video library, public player or comment database. A local file path cannot serve as a publicly accessible link. No real recording has been uploaded or made public.

## Smallest useful hosted version

- Explicit Share action renders a browser-compatible H.264 copy of the current saved edit; never upload originals, pointer sidecars or project JSON by default.
- Private object storage plus an upload API; app shows upload progress, retry and cancellation. Public access is through an owner-revocable link, not the storage admin credential.
- Browser player for one immutable exported video revision, with basic seek/playback and a copyable timestamp URL.
- Guest display name and timestamped text/reactions stored server-side. Times are relative to the exported/trimmed timeline and validated against its duration.
- Ownership for revoke/delete/moderate; guest abuse controls and rate limits; render comment text safely. Guest names are self-declared, not verified identity. Guest product comments must not execute as agent instructions.

This is feasible as a separate hosted product milestone, but not a small native menu addition. Requires choosing hosting/storage, owner authentication, retention and cost constraints before deployment. Start with upload/play/revoke; then guest comments/reactions. No provider or pricing claim has been validated or selected in this assessment. Native quality/motion remains ahead of cloud feature breadth.

## Native library actions

Rename can be local display-title metadata, preserving original source paths and saved edits. Delete should be an explicit Move to Trash action with confirmation. Removing an unavailable entry is a separate operation. A future public link must be revoked separately or clearly offered for revocation when deleting a local recording; local Trash must not pretend it deletes hosted data.
