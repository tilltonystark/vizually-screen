# Zoom-detail investigation — November 4, 2026

Area selection was prioritized first. Zoom clarity is **not fixed or at demonstrated Shotbase parity**. User's preview-versus-export clarification and live sample check remain pending.

The current renderer uses a single combined Lanczos scale for zoom plus framing, no intentional low-resolution proxy, and native-sized output. Enlarging a source cannot reconstruct detail it did not contain. That observation alone does not explain the user's specific recording.

A new reproducible `VizuallyScreenQuality <directory> --zoom-detail` test isolates generational compression. It generates a 1920×1080/60fps ProRes4444 source containing small monochrome/colored text and moving patterns; encodes an unzoomed recording surrogate; then exports editable zooms peaking at 1.65×. Four exact-time decoded frames are compared to the original source rendered through the same zoom composition directly by AVAssetImageGenerator. Thus the reference includes the same magnification; the comparison measures encoding/conversion loss rather than rewarding an unzoomed reference. Both samples during ramps and near peak magnification are included. This is a synthetic pipeline surrogate, **not ScreenCaptureKit or competitor capture**. The existing text ROI is x35,y75,w840,h600 in output coordinates, not a tracked text mask. PSNR does not prove subjective sharpness. The source itself is ProRes, not mathematically lossless.

| Recording surrogate → export | Text ROI PSNR | Export bitrate |
| --- | ---: | ---: |
| HEVC → HEVC | 27.13 dB | 22.80 Mb/s |
| ProRes4444 → HEVC | 30.43 dB | 22.88 Mb/s |
| HEVC → ProRes4444 | 27.61 dB | 463.44 Mb/s |
| ProRes4444 → ProRes4444 | 31.32 dB | 497.16 Mb/s |

All outputs retain1920×1080,120 frames,60fps and maximum presentation gap16.67ms. [Raw report](quality-assets/zoom-detail-2026-11-04/report.json). The two-second master output is roughly22× the HEVC bitrate in this test, not a general storage promise.

Recording in ProRes then exporting HEVC scores3.30dB above HEVC at both stages. Merely exporting an HEVC source to ProRes adds only0.48dB in this test. Visual author inspection of matching generated crops confirms visibly softer small colored text in the two-generation HEVC result. These results support preserving source chroma/detail before zooming; they do not prove the cause of the user's particular blur, or that bitrate increases alone fix it.

App help now makes the distinction between recording quality and export quality explicit, behind info controls. No silent codec/default/storage change or artificial sharpening was introduced. Maximum detail was already available before this investigation; this checkpoint does not claim a new recording-quality fix.

Next: confirm whether the reported blur appears in preview, export or both; inspect a representative native source and matched zoom frame at100% against the export; then measure a targeted fix. Controlled Shotbase capture/export comparison remains unverified.
