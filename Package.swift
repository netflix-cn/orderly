// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Orderly",
    platforms: [
        // 最低支持 macOS 15.0；仅构建 arm64（见 Scripts/build-app.sh）
        .macOS("15.0")
    ],
    targets: [
        .executableTarget(
            name: "Orderly",
            path: "Sources/Orderly"
        ),
        .testTarget(
            name: "OrderlyTests",
            dependencies: ["Orderly"],
            path: "Tests/OrderlyTests"
        ),
    ]
)
