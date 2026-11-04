import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import VizuallyScreenCore

struct BackgroundPicker:View {
    @ObservedObject var editor:Editor
    @EnvironmentObject var theme:StudioTheme
    @State private var category=CanvasBackground.Kind.gradient
    @State private var wallpapers=false
    var body:some View {
        VStack(alignment:.leading,spacing:StudioLayout.panelGap) {
            Picker("Background type",selection:$category) {
                Text("Gradient").tag(CanvasBackground.Kind.gradient)
                Text("Color").tag(CanvasBackground.Kind.solid)
                Text("Image").tag(CanvasBackground.Kind.image)
            }.pickerStyle(.segmented).labelsHidden()
            switch category {
            case .gradient:
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:8),count:4),spacing:12) {
                    ForEach(BackgroundPreset.all) { preset in
                        swatch(preset.name,selected:active(.gradient,preset.id)) {
                            LinearGradient(colors:[Color.canvasHex(preset.top),Color.canvasHex(preset.bottom)],startPoint:.topLeading,endPoint:.bottomTrailing)
                        } action: { choose(.init(kind:.gradient,value:preset.id)) }
                    }
                }
            case .solid:
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:8),count:4),spacing:12) {
                    ForEach(BackgroundPreset.solids,id:\.self) { hex in
                        swatch("#\(hex)",selected:active(.solid,hex),showName:false) { Color.canvasHex(hex) } action: { choose(.init(kind:.solid,value:hex)) }
                    }
                }
                ColorPicker("Custom color",selection:Binding(get:{ Color.canvasHex(editor.project?.canvasBackground?.kind == .solid ? editor.project!.canvasBackground!.value:"FFFFFF") },set:{ color in
                    guard let rgb=NSColor(color).usingColorSpace(.sRGB) else { return }
                    choose(.init(kind:.solid,value:String(format:"%02X%02X%02X",Int((rgb.redComponent*255).rounded()),Int((rgb.greenComponent*255).rounded()),Int((rgb.blueComponent*255).rounded()))))
                }),supportsOpacity:false).font(StudioType.caption)
            case .image:
                if let background=editor.project?.canvasBackground,background.kind == .image {
                    BackgroundThumbnail(url:URL(fileURLWithPath:background.value)).frame(height:100).clipShape(RoundedRectangle(cornerRadius:8))
                    Text(URL(fileURLWithPath:background.value).deletingPathExtension().lastPathComponent).font(StudioType.caption).foregroundStyle(Ink.secondary).lineLimit(1)
                }
                Button("Choose image…",action:editor.chooseBackgroundImage).buttonStyle(StudioButtonStyle()).frame(maxWidth:.infinity,alignment:.leading)
                Button("macOS wallpapers") { wallpapers=true }.buttonStyle(StudioButtonStyle(quiet:true))
                    .popover(isPresented:$wallpapers) { WallpaperPicker { url in editor.setBackgroundImage(url,copy:false);wallpapers=false }.environmentObject(theme) }
            }
        }.disabled(editor.project == nil)
            .onAppear { category=editor.project?.canvasBackground?.kind ?? .gradient }
    }
    private func active(_ kind:CanvasBackground.Kind,_ value:String) -> Bool {
        guard let p=editor.project,p.padding>0 else { return false }
        return p.canvasBackground == CanvasBackground(kind:kind,value:value) || (p.canvasBackground == nil && kind == .gradient && p.background == value)
    }
    private func choose(_ background:CanvasBackground) {
        editor.update { $0.canvasBackground=background;if $0.padding == 0 { $0.padding=0.07 } }
    }
    private func swatch<Fill:View>(_ name:String,selected:Bool,showName:Bool=true,@ViewBuilder fill:()->Fill,action:@escaping()->Void) -> some View {
        Button(action:action) {
            VStack(spacing:5) {
                fill().frame(height:StudioLayout.swatchHeight).clipShape(RoundedRectangle(cornerRadius:8))
                    .overlay { RoundedRectangle(cornerRadius:8).strokeBorder(selected ? theme.accent:Color.black.opacity(0.10),lineWidth:selected ? 2:0.5) }
                    .overlay { if selected { Image(systemName:"checkmark.circle.fill").foregroundStyle(.white,theme.accent) } }
                if showName { Text(name).font(StudioType.swatchLabel).foregroundStyle(Ink.secondary).lineLimit(1) }
            }
        }.buttonStyle(.plain).accessibilityLabel("\(name) background").accessibilityAddTraits(selected ? .isSelected:[])
    }
}
struct BackgroundThumbnail:View {
    let url:URL
    @State private var thumbnail:NSImage?
    var body:some View {
        GeometryReader { geometry in
            if let thumbnail { Image(nsImage:thumbnail).resizable().scaledToFill().frame(width:geometry.size.width,height:geometry.size.height).clipped() }
            else { Ink.soft.overlay { Image(systemName:"photo").foregroundStyle(Ink.muted) } }
        }.task(id:url) {
            if let source=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:640,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) {
                thumbnail=NSImage(cgImage:image,size:.zero)
            }
        }
    }
}
struct WallpaperPicker:View {
    let select:(URL)->Void
    private let urls: [URL] = {
        let roots=["/System/Library/Desktop Pictures","/Library/Desktop Pictures"]
        return roots.flatMap { (try? FileManager.default.contentsOfDirectory(at:URL(fileURLWithPath:$0),includingPropertiesForKeys:nil)) ?? [] }
            .filter { ["heic","jpg","jpeg","png"].contains($0.pathExtension.lowercased()) }.sorted { $0.lastPathComponent<$1.lastPathComponent }
    }()
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("macOS wallpapers").font(StudioType.sectionTitle)
            if urls.isEmpty { Text("No installed images found. Use Choose image to add a wallpaper.").font(StudioType.caption).foregroundStyle(Ink.secondary) }
            else { ScrollView {
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:16) {
                    ForEach(urls,id:\.self) { url in
                        Button { select(url) } label: {
                            VStack(alignment:.leading,spacing:6) {
                                BackgroundThumbnail(url:url).frame(height:90).clipShape(RoundedRectangle(cornerRadius:8))
                                Text(url.deletingPathExtension().lastPathComponent).font(StudioType.caption).foregroundStyle(Ink.primary).lineLimit(1)
                            }
                        }.buttonStyle(.plain).accessibilityLabel(url.deletingPathExtension().lastPathComponent)
                    }
                }
            }.frame(height:340) }
        }.padding(20).frame(width:380).background(.white).preferredColorScheme(.light)
    }
}
extension Color {
    static func canvasHex(_ hex:String) -> Color {
        let color=CanvasBackground.color(hex) ?? .white
        return Color(.sRGB,red:Double(color.red),green:Double(color.green),blue:Double(color.blue),opacity:1)
    }
}
extension Editor {
    func chooseBackgroundImage() {
        let panel=NSOpenPanel();panel.allowedContentTypes=[.image];panel.canChooseDirectories=false
        if panel.runModal() == .OK,let url=panel.url { setBackgroundImage(url,copy:true) }
    }
    func setBackgroundImage(_ url:URL,copy:Bool) {
        do {
            guard CanvasBackground.loadImage(url.path) != nil else { throw MediaExporter.qualityError("This image could not be opened. Choose a PNG, JPEG or HEIC image.") }
            var stored=url
            if copy {
                let folder=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Vizually Screen/Backgrounds")
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                stored=folder.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-\(UUID().uuidString.prefix(6)).\(url.pathExtension)")
                try FileManager.default.copyItem(at:url,to:stored)
            }
            update { $0.canvasBackground=CanvasBackground(kind:.image,value:stored.path);if $0.padding == 0 { $0.padding=0.07 } }
        } catch { self.error=error.localizedDescription }
    }
}
