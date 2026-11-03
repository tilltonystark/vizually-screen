// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Framecraft", platforms: [.macOS(.v15)], products: [.executable(name: "Framecraft", targets: ["Framecraft"])], targets: [.target(name: "FramecraftCore"), .executableTarget(name: "Framecraft", dependencies: ["FramecraftCore"], resources: [.copy("Resources")]), .executableTarget(name: "FramecraftChecks", dependencies: ["FramecraftCore"]), .executableTarget(name: "FramecraftQuality", dependencies: ["FramecraftCore"])], swiftLanguageModes: [.v5])
