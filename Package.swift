// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SvelteSwiftUI",
    platforms: [.iOS(.v18), .macOS(.v15), .visionOS(.v2)],
    products: [.library(name: "SvelteSwiftUI", targets: ["SvelteSwiftUI"])],
    targets: [
        .target(
            name: "SvelteSwiftUI",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "SvelteSwiftUITests",
            dependencies: ["SvelteSwiftUI"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
