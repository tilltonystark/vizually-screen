# Light studio UI revamp

The user authorized light mode, Geist, antialiasing and a substantial polish pass. Applied local Emil build-a-tool/color/ui-polish/typography/surfaces skills and Superpowers planning/verification guidance. Maggie Appleton's [planning-agents article](https://maggieappleton.com/planning-agents) informed the repeatable demo and live Appearance Lab: use running, visible objects for design decisions and test assumptions against behavior. These tools are native and use the real editor's components.

## Color and typography changes

Original `App.swift` scattered a dark base `rgb(0.075,0.08,0.10)`, white-opacity surfaces, `.secondary` text, lavender `rgb(0.73,0.65,1)`, black-opacity preview/timeline and red recording status. The replacement centralizes roles in `Theme.swift`/`Appearance.swift`:

| Original declaration/role | Replacement | Reason |
| --- | --- | --- |
| Dark root RGB | White shell, canvas OKLCH(0.955,0.003,265) | Requested light mode and clear surface separation |
| White primary text / implicit dark-scheme text | OKLCH(0.25,0.008,265) | Readable dark text on light surfaces |
| `.secondary` text | OKLCH(0.46,0.008,265); muted 0.51 | Fixed roles with measured contrast |
| Lavender primary RGB | OKLCH(0.48,0.18,265), bounded hue 230…300 | White primary-button labels retain ≥4.5:1 over supported hue range |
| Accent-opacity track/surfaces | OKLCH(0.95,0.025,hue) | Stable light tint, selected state uses solid accent |
| White-opacity sidebar surface | Removed sidebar; white grouped inspector | More preview space and task-based controls |
| Black-opacity preview/timeline | Canvas role, soft OKLCH(0.975,0.002,265) | Distinct light work areas |
| Implicit Divider | OKLCH(0.89,0.004,265), one physical pixel | Retina hairline layout separation |
| Image edge treatments | Pure black at 10% | Neutral image outline |
| Red capture status | Native semantic red retained | Recording status semantics unchanged |
| System/rounded app fonts | Bundled Geist Regular/Medium/Semibold | Consistent requested family, real weights |

Colors are authored in OKLCH and gamut-mapped into sRGB for native SwiftUI. Native font rendering stays antialiased; CSS smoothing flags are not used in a native app. The Appearance Lab's explicit Core Text sample sets antialiasing and font-smoothing flags. Timers and live numeric values use tabular digits. Hover does not change weight, primary buttons have 40pt height, press scale is 0.96 with reduced-motion support, and native keyboard focus remains available.

## Review and verification

Builder review identified thumbnail-state consistency, minimum interval math and palette contrast as priorities; all were addressed. A fresh code reviewer identified menu lock bypass and stale loading text; both were fixed. The review worker then stopped at an account usage limit, so the remaining review was completed locally by the author. This is not a complete independent sign-off.

Automated checks passed for project/appearance serialization and validation, short clips and trim bounds, allowed palette contrast, real demo generation/decode and actual styled/trimmed MP4 export/decode. Native empty/populated editor, zoom selection, Appearance Lab opening and JSON save were exercised. Live capture/audio and reference export quality remain unverified.
