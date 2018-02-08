// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Tweegee",
    products: [
        .executable(name: "Tweegee", targets: ["Tweegee"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Tweegee",
            dependencies: [],
            path: "Sources"),
//        .testTarget(
//            name: "TweegeeTests",
//            dependencies: [],
//            path: "Tests"),
    ]
)

