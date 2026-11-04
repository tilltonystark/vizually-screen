import VizuallyFeedback
import SwiftUI
import AVKit

@main
struct VizuallyScreenApp: App {
    @StateObject private var editor = Editor()
    @StateObject private var capture = Capture()
    @StateObject private var theme = StudioTheme()
    @StateObject private var feedback = ScreenFeedback.makeStore()
    @State private var showRecording = false
    @Environment(\.openWindow) private var openWindow
    init() { Geist.register() }
    private var locked: Bool { editor.busy || capture.recording || capture.busy }
    var body: some Scene {
        Window("Vizually Screen", id: "workspace") {
            WorkspaceView(editor: editor, capture: capture, showRecording: $showRecording)
                .environmentObject(theme).environmentObject(feedback)
                .font(Geist.font()).foregroundStyle(Ink.primary)
                .frame(minWidth: 1080, minHeight: 740)
                .preferredColorScheme(.light)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    capture.onFinish = { result in Task { await editor.loadRecording(result,automaticZoom:capture.automaticZoom) } }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.disabled)
        .defaultSize(width: 1320, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Recording…", action: beginRecording).keyboardShortcut("n").disabled(locked)
                Button("Import Video…", action: editor.importVideo).keyboardShortcut("i").disabled(locked)
                Button("Open Recording or Project…", action: editor.openProject).keyboardShortcut("o").disabled(locked)
                Button("Save Project…", action: editor.saveProject).keyboardShortcut("s").disabled(editor.project == nil || locked)
                Button("Open Demo Project") { Task { await editor.loadDemo() } }.disabled(locked)
            }
            CommandMenu("Studio") {
                Button("All recordings",action:editor.returnHome).keyboardShortcut("h",modifiers:[.command,.shift]).disabled(locked)
                Button("Play / Pause", action: editor.togglePlayback).keyboardShortcut(.space, modifiers: []).disabled(editor.project == nil || locked || editor.showsHome)
                Button("Add Zoom", action: editor.addZoom).keyboardShortcut("z", modifiers: [.command, .shift]).disabled(editor.project == nil || locked)
                LabCommand()
            }
        }
        Window("Appearance Lab", id: "appearance-lab") {
            AppearanceLab().feedbackSurface(store:feedback,editor:editor,route:"appearance").environmentObject(theme).font(Geist.font()).foregroundStyle(Ink.primary).preferredColorScheme(.light)
        }.defaultSize(width: 660, height: 690).windowResizability(.contentSize)
        MenuBarExtra("Vizually Screen", systemImage: capture.recording ? "record.circle.fill" : "viewfinder") {
            Button("Open Vizually Screen") { openWindow(id: "workspace");NSApp.activate(ignoringOtherApps: true) }
            Divider()
            if capture.recording { Button("Stop Recording") { Task { await capture.stop() } }.disabled(capture.busy) }
            else { Button("New Recording…", action: beginRecording).disabled(locked) }
        }
    }
    private func beginRecording() {
        guard !locked else { return }
        openWindow(id: "workspace")
        NSApp.activate(ignoringOtherApps: true)
        showRecording = true
    }
}
struct LabCommand: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View { Button("Appearance Lab…") { openWindow(id: "appearance-lab") }.keyboardShortcut("l", modifiers: [.command, .shift]) }
}
