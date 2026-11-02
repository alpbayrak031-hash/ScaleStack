// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScaleStackKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ScaleStackKit", targets: ["ScaleStackKit"]),
        .executable(name: "scalestack", targets: ["scalestack"]),
    ],
    targets: [
        .target(
            name: "ScaleStackKit",
            // The codec is numeric inner loops end to end; an unoptimised build is ~50x slower,
            // which makes the app unusable in Debug. Always optimise this target.
            swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .debug))]
        ),
        .executableTarget(name: "scalestack", dependencies: ["ScaleStackKit"]),
        .testTarget(name: "ScaleStackKitTests", dependencies: ["ScaleStackKit"]),
    ],
    swiftLanguageModes: [.v6]
)
