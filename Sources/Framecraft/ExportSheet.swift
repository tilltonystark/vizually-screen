import SwiftUI
import FramecraftCore

struct ExportSheet: View {
    @ObservedObject var editor: Editor
    @EnvironmentObject var theme: StudioTheme
    @Environment(\.dismiss) private var dismiss
    @State private var quality: VideoQuality = .high
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack { Text("Export video").font(Geist.font(21,.semibold));Spacer();IconButton(symbol:"xmark",title:"Close") { dismiss() }.disabled(editor.isExporting) }
            if editor.isExporting {
                Text("Rendering at source resolution").font(Geist.font(14,.medium))
                ProgressView(value:editor.exportProgress).tint(theme.accent)
                HStack { Text("\(Int(editor.exportProgress*100))%").monospacedDigit();Spacer();Button("Cancel export",action:editor.cancelExport).buttonStyle(StudioButtonStyle()) }
            } else {
                Picker("Quality profile",selection:$quality) { ForEach(VideoQuality.allCases) { q in Text(q.name).tag(q) } }
                Text(quality.detail).font(Geist.font(12)).foregroundStyle(Ink.secondary)
                VStack(alignment:.leading,spacing:10) {
                    Text("\(Int(editor.videoSize.width)) × \(Int(editor.videoSize.height)) · 60 fps composition").font(Geist.font(13,.medium)).monospacedDigit()
                    if let p=editor.project { Text("\(clockText(p.trimEnd-p.trimStart)) · source resolution preserved").font(Geist.font(12)).foregroundStyle(Ink.secondary) }
                    Text("Smooth zooms render at a steady 60 fps. Extra frames do not recover detail missing from the source.").font(Geist.font(11)).foregroundStyle(Ink.secondary)
                }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(Ink.soft,in:RoundedRectangle(cornerRadius:10))
                if quality == .master { Label("Editing masters need substantially more disk space.",systemImage:"internaldrive").font(Geist.font(12)).foregroundStyle(Ink.secondary) }
                HStack { Spacer();Button("Cancel") { dismiss() }.buttonStyle(StudioButtonStyle());Button("Choose location…") { editor.export(quality:quality) }.buttonStyle(StudioButtonStyle(primary:true)) }
            }
        }.padding(28).frame(width:450).foregroundStyle(Ink.primary).background(.white)
            .onChange(of:editor.isExporting) { was,now in if was && !now { dismiss() } }
            .interactiveDismissDisabled(editor.isExporting)
    }
}
