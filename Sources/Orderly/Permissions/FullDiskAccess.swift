import AppKit
import Darwin

/// 「完全磁盘访问权限」（Full Disk Access）的检测与引导。
///
/// macOS 没有提供申请该权限的 API，也不会弹出系统授权框，
/// 只能引导用户到「系统设置 › 隐私与安全性 › 完全磁盘访问权限」中手动打开开关。
/// 检测方式是尝试读取只有拥有该权限才能读取的文件。
enum FullDiskAccess {
    /// 受 TCC 保护、拥有完全磁盘访问权限才能读取的文件
    private static var probePaths: [String] {
        let home = URL.homeDirectory.path
        return [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "\(home)/Library/Application Support/com.apple.TCC/TCC.db",
            "\(home)/Library/Safari/Bookmarks.plist",
        ]
    }

    static var isGranted: Bool {
        probePaths.contains { path in
            let fd = open(path, O_RDONLY)
            guard fd != -1 else { return false }
            close(fd)
            return true
        }
    }

    /// 打开「系统设置 › 隐私与安全性 › 完全磁盘访问权限」
    @MainActor
    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    /// 在 Finder 中选中当前 App，方便用户拖入权限列表
    @MainActor
    static func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    /// 部分系统版本授权后需要重启 App 才能生效
    @MainActor
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
