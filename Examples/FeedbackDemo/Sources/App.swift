import SwiftUI
import VizuallyFeedback

@main @MainActor struct FeedbackDemoApp: App {
  @StateObject private var feedback = FeedbackStore(
    configuration: FeedbackConfiguration(
      projectID: "design.vizually.feedback-demo", appName: "Independent Feedback Demo",
      endpoint: nil))
  var body: some Scene {
    WindowGroup("Independent Feedback Demo") {
      DemoView().feedbackSurface(
        store: feedback,
        context: FeedbackContext(route: "sample", metadata: ["sample": "independent-consumer"])
      )
      .frame(minWidth: 640, minHeight: 480)
    }
  }
}
struct DemoView: View {
  @State private var name = ""
  @State private var count = 0
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("A separate project").font(.largeTitle).feedbackTarget("demo.title", "Demo title")
      TextField("Type here; C stays a normal letter", text: $name).textFieldStyle(.roundedBorder)
        .feedbackTarget("demo.name", "Name field")
      Button("Count: \(count)") { count += 1 }.feedbackTarget("demo.counter", "Counter button")
      Text(
        "Click the comment button or press C outside a text field. Hover, click, write, then Enter. This sample saves locally; set an endpoint to connect an agent."
      ).foregroundStyle(.secondary)
      Spacer()
    }.padding(40)
  }
}
