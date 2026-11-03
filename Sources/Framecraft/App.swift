import SwiftUI
import AVKit

@main
struct FramecraftApp: App {
    @StateObject private var editor = Editor()
    @StateObject private var capture = Capture()
    @StateObject private var theme = StudioTheme()
    init() { Geist.register() }
    private var locked: Bool { editor.busy || capture.recording || capture.busy }
    var body: some Scene {
        WindowGroup {
            StudioView(editor: editor, capture: capture)
                .environmentObject(theme)
                .font(Geist.font()).foregroundStyle(Ink.primary)
                .frame(minWidth: 1080, minHeight: 740)
                .preferredColorScheme(.light)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    capture.onFinish = { url in Task { await editor.load(url) } }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Video…", action: editor.importVideo).keyboardShortcut("i").disabled(locked)
                Button("Open Project…", action: editor.openProject).keyboardShortcut("o").disabled(locked)
                Button("Save Project…", action: editor.saveProject).keyboardShortcut("s").disabled(editor.project == nil || locked)
                Button("Open Demo Project") { Task { await editor.loadDemo() } }.disabled(locked)
            }
            CommandMenu("Studio") {
                Button("Play / Pause", action: editor.togglePlayback).keyboardShortcut(.space, modifiers: []).disabled(editor.project == nil || locked)
                Button("Add Zoom", action: editor.addZoom).keyboardShortcut("z", modifiers: [.command, .shift]).disabled(editor.project == nil || locked)
                LabCommand()
            }
        }
        Window("Appearance Lab", id: "appearance-lab") {
            AppearanceLab().environmentObject(theme).font(Geist.font()).foregroundStyle(Ink.primary).preferredColorScheme(.light)
        }.defaultSize(width: 660, height: 690).windowResizability(.contentSize)
        MenuBarExtra("Framecraft", systemImage: capture.recording ? "record.circle.fill" : "viewfinder") {
            if capture.recording { Button("Stop Recording") { Task { await capture.stop() } }.disabled(capture.busy) }
            else { Text("Open Framecraft to start recording") }
        }
    }
}
struct LabCommand: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View { Button("Appearance Lab…") { openWindow(id: "appearance-lab") }.keyboardShortcut("l", modifiers: [.command, .shift]) }
}
