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
        // 桌面小组件扩展；由 Scripts/build-app.sh 打包成 OrderlyWidget.appex 放进 Orderly.app
        .executableTarget(
            name: "OrderlyWidget",
            path: "Sources/OrderlyWidget",
            swiftSettings: [.unsafeFlags(["-application-extension"])],
            // 与 Xcode 的扩展 target 一致：入口必须是 NSExtensionMain，由它建立扩展环境后再调用 @main。
            // 直接从 main 进入时 WidgetKit 找不到扩展上下文，进程会立即退出，小组件不会出现
            linkerSettings: [.unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain", "-Xlinker", "-application_extension"])]
        ),
        .testTarget(
            name: "OrderlyTests",
            dependencies: ["Orderly"],
            path: "Tests/OrderlyTests"
        ),
        .testTarget(
            name: "OrderlyWidgetTests",
            dependencies: ["OrderlyWidget"],
            path: "Tests/OrderlyWidgetTests"
        ),
    ]
)
