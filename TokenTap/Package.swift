// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenTap",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TokenTap",
            path: "TokenTap"
        ),
    ]
)
