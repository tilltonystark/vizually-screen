import SwiftUI
import VizuallyFeedback

/// Only host configuration and playback hooks live here. All feedback behavior
/// and rendering are maintained in the shared VizuallyFeedback library.
@MainActor enum ScreenFeedback {
    static func makeStore() -> FeedbackStore {
        FeedbackStore(configuration:FeedbackConfiguration(
            projectID:"design.vizually.screen",appName:"Vizually Screen",
            build:Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development",
            storageDirectory:RecordingLibrary.support.appendingPathComponent("Feedback"),
            sessionURL:URL(string:"vizually-screen://native/workspace")!,
            legacySessionKey:"feedback.agentation.session",importLegacyRecords:true
        ))
    }
}
extension View {
    func feedbackSurface(store:FeedbackStore,editor:Editor,route:String) -> some View {
        feedbackSurface(store:store,context:FeedbackContext(route:route,playbackTime:route == "editor" ? editor.playhead:nil),appearance:FeedbackAppearance(regularFontName:"Geist-Regular",mediumFontName:"Geist-Medium",surface:.white,field:Ink.soft,text:Ink.primary,secondaryText:Ink.secondary),bottomInset:["recording","export","appearance"].contains(route) ? 76:0,onActivate:{ editor.player.pause() })
    }
}
