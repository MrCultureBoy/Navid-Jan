// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuestlyKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "QuestlyKit", targets: ["QuestlyKit"])
    ],
    targets: [
        .target(name: "QuestlyKit"),
        .testTarget(name: "QuestlyKitTests", dependencies: ["QuestlyKit"])
    ]
)
