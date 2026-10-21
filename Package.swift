// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TBPK",
    platforms: [
        .macOS(.v13),
    ],
    targets: [
        .executableTarget(
            name: "TBPK",
            path: "Sources/TBPK"
        ),
        .testTarget(
            name: "TBPKTests",
            dependencies: ["TBPK"],
            path: "Tests/TBPKTests"
        ),
    ]
)
