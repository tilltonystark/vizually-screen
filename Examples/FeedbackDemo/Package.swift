// swift-tools-version: 6.0
import PackageDescription
let package=Package(name:"FeedbackDemo",platforms:[.macOS(.v15)],dependencies:[.package(name:"VizuallyScreen",path:"../..")],targets:[.executableTarget(name:"FeedbackDemo",dependencies:[.product(name:"VizuallyFeedback",package:"VizuallyScreen")],path:"Sources")],swiftLanguageModes:[.v6])
