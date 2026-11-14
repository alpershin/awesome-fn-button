// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AwesomeFnButton",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AwesomeFnButton", targets: ["AwesomeFnButton"]),
        .executable(name: "fn-diagnose", targets: ["FnDiagnose"])
    ],
    targets: [
        .target(name: "FnCore"),
        .executableTarget(name: "AwesomeFnButton", dependencies: ["FnCore"]),
        .executableTarget(name: "FnDiagnose", dependencies: ["FnCore"]),
        .testTarget(name: "FnCoreTests", dependencies: ["FnCore"])
    ]
)
