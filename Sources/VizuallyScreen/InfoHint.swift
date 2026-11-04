import SwiftUI
import VizuallyScreenCore

/// Shared progressive help: fixed width, hover discovery, click/keyboard fallback.
struct InfoHint: View {
    let title: String
    let text: String
    @State private var showing=false
    @State private var pinned=false
    @State private var hoverTask:Task<Void,Never>?
    var body: some View {
        Button { pinned.toggle();showing=pinned } label: {
            Image(systemName:"info.circle").font(StudioType.helpIcon).foregroundStyle(Ink.secondary)
                .frame(width:StudioLayout.helpTarget,height:StudioLayout.helpTarget).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("About \(title)").accessibilityHint(text)
            .onHover { inside in
                hoverTask?.cancel()
                if inside { hoverTask=Task { @MainActor in
                    try? await Task.sleep(for:StudioLayout.helpDelay)
                    guard !Task.isCancelled else { return };showing=true
                } } else if !pinned { showing=false }
            }
            .popover(isPresented:$showing,arrowEdge:.trailing) {
                VStack(alignment:.leading,spacing:StudioLayout.helpGap) {
                    Text(title).font(StudioType.sectionTitle).foregroundStyle(Ink.primary)
                    Text(text).font(StudioType.caption).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true)
                }.padding(StudioLayout.helpPadding).frame(width:StudioLayout.helpWidth,alignment:.leading)
                    .background(.white).preferredColorScheme(.light)
                    .onExitCommand { showing=false;pinned=false }
            }
            .onChange(of:showing) { _,value in if !value { pinned=false } }
            .onDisappear { hoverTask?.cancel() }
    }
}
struct QualityPicker: View {
    @Binding var selection: VideoQuality
    var body: some View {
        HStack(spacing:StudioLayout.helpGap) {
            Text("Quality").font(StudioType.controlLabel)
            InfoHint(title:"Quality",text:selection.detail)
            Spacer()
            Picker("Quality",selection:$selection) { ForEach(VideoQuality.allCases) { quality in Text(quality.name).tag(quality) } }
                .labelsHidden().fixedSize()
        }
    }
}
