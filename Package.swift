// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NextDNSStats",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NextDNSToolbarCore", targets: ["NextDNSToolbarCore"]),
        .executable(name: "NextDNSStats", targets: ["NextDNSStats"]),
    ],
    targets: [
        .target(name: "NextDNSToolbarCore"),
        .executableTarget(name: "NextDNSStats", dependencies: ["NextDNSToolbarCore"], path: "Sources/NextDNSToolbar"),
        .testTarget(name: "NextDNSToolbarCoreTests", dependencies: ["NextDNSToolbarCore"]),
    ],
    swiftLanguageModes: [.v5]
)
