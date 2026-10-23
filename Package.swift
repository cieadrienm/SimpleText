// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SimpleText",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SimpleTextCore", targets: ["SimpleTextCore"]),
        .executable(name: "SimpleText", targets: ["SimpleText"]),
    ],
    targets: [
        .target(name: "SimpleTextCore"),
        .executableTarget(name: "SimpleText", dependencies: ["SimpleTextCore"]),
        .testTarget(name: "SimpleTextCoreTests", dependencies: ["SimpleTextCore"]),
        .testTarget(name: "SimpleTextAppTests", dependencies: ["SimpleText", "SimpleTextCore"]),
    ],
    swiftLanguageModes: [.v5]
)
