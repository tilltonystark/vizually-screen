// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VizuallyScreen",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "VizuallyFeedback", targets: ["VizuallyFeedback"]),
        .executable(name: "VizuallyScreen", targets: ["VizuallyScreen"])
    ],
    targets: [
        .target(name: "VizuallyFeedback"),
        .executableTarget(name: "VizuallyFeedbackChecks", dependencies: ["VizuallyFeedback"]),
        .target(name: "VizuallyScreenCore"),
        .executableTarget(name: "VizuallyScreen", dependencies: ["VizuallyScreenCore", "VizuallyFeedback"], resources: [.copy("Resources")]),
        .executableTarget(name: "VizuallyScreenChecks", dependencies: ["VizuallyScreenCore"]),
        .executableTarget(name: "VizuallyScreenQuality", dependencies: ["VizuallyScreenCore"])
    ],
    swiftLanguageModes: [.v5]
)
