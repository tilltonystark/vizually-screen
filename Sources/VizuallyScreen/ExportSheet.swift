import VizuallyFeedback
import SwiftUI
import VizuallyScreenCore

struct ExportSheet: View {
    @ObservedObject var editor: Editor
    @EnvironmentObject var theme: StudioTheme
    @Environment(\.dismiss) private var dismiss
    @State private var quality: VideoQuality = .efficient
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack { Text("Export video").font(Geist.font(21,.semibold));Spacer();IconButton(symbol:"xmark",title:"Close") { dismiss() }.disabled(editor.isExporting) }
            if editor.isExporting {
                Text("Rendering at source resolution").font(Geist.font(14,.medium))
                ProgressView(value:editor.exportProgress).tint(theme.accent)
                HStack { Text("\(Int(editor.exportProgress*100))%").monospacedDigit();Spacer();Button("Cancel export",action:editor.cancelExport).buttonStyle(StudioButtonStyle()) }
            } else {
                QualityPicker(selection:$quality).feedbackTarget("export.quality","Export quality")
                VStack(alignment:.leading,spacing:10) {
                    HStack {
                        Text("\(Int(editor.videoSize.width)) × \(Int(editor.videoSize.height)) · 60 fps").font(Geist.font(13,.medium)).monospacedDigit()
                        Spacer()
                        InfoHint(title:"Original size",text:"Export matches your source dimensions. Zoom and pointer animations render at 60 frames per second; this does not add detail missing from the original.")
                    }
                    if let p=editor.project { Text(clockText(p.trimEnd-p.trimStart)).font(Geist.font(12)).foregroundStyle(Ink.secondary) }
                }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(Ink.soft,in:RoundedRectangle(cornerRadius:10))
                if quality == .master { Label("Very large file",systemImage:"internaldrive").font(Geist.font(12)).foregroundStyle(Ink.secondary) }
                HStack { Spacer();Button("Cancel") { dismiss() }.buttonStyle(StudioButtonStyle());Button("Choose location…") { editor.export(quality:quality) }.buttonStyle(StudioButtonStyle(primary:true)).feedbackTarget("export.location","Choose export location") }
            }
        }.padding(28).frame(width:450).foregroundStyle(Ink.primary).background(.white)
            .onChange(of:editor.isExporting) { was,now in if was && !now { dismiss() } }
            .interactiveDismissDisabled(editor.isExporting)
    }
}
