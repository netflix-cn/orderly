import Foundation

/// ~/Library/Logs 下的日志，以及 DiagnosticReports 中的崩溃报告
struct LogsRule: ScanRule {
    let id = "logs"
    let title = "日志与崩溃报告"
    let category = ScanCategory.junk
    let requiresFullDiskAccess = false

    func scan(in context: ScanContext) async throws -> [ScanItem] {
        var items: [ScanItem] = []
        for url in FileScanner.children(of: context.url("Library/Logs")) {
            try Task.checkCancellation()
            let name = url.lastPathComponent
            if name == "DiagnosticReports" {
                items += try crashReports(in: url, context: context)
                continue
            }

            let item: ScanItem?
            if FileScanner.isDirectory(url) {
                item = context.makeItem(
                    url: url, category: category, kind: "日志",
                    owner: context.catalog.owner(forIdentifier: name),
                    action: .deleteContents
                )
            } else {
                // 直接放在 Logs 下的文件多为系统工具日志（fsck_apfs.log 等）
                let stem = url.deletingPathExtension().lastPathComponent
                item = context.makeItem(
                    url: url, category: category, kind: "日志",
                    owner: context.catalog.owner(forProcessName: stem) ?? .system,
                    action: .delete
                )
            }
            if let item { items.append(item) }
        }
        return items
    }

    private func crashReports(in directory: URL, context: ScanContext) throws -> [ScanItem] {
        var items: [ScanItem] = []
        for url in FileScanner.children(of: directory) where !FileScanner.isDirectory(url) {
            try Task.checkCancellation()
            let owner = Self.processName(fromCrashReport: url.lastPathComponent)
                .flatMap(context.catalog.owner(forProcessName:)) ?? .system
            // 崩溃报告体积小但数量多，不受最小体积限制
            let item = context.makeItem(
                url: url, category: category, kind: "崩溃报告",
                owner: owner, action: .delete, minimumSize: 1
            )
            if let item { items.append(item) }
        }
        return items
    }

    /// 「Google Chrome-2026-10-21-101010.ips」→「Google Chrome」
    static func processName(fromCrashReport fileName: String) -> String? {
        guard let match = fileName.firstMatch(of: #/^(.+?)[-_]\d{4}-\d{2}-\d{2}/#) else { return nil }
        return String(match.1)
    }
}

/// ~/Library/Saved Application State：App 的窗口恢复数据
struct SavedApplicationStateRule: ScanRule {
    let id = "saved-state"
    let title = "窗口恢复数据"
    let category = ScanCategory.junk
    let requiresFullDiskAccess = false

    func scan(in context: ScanContext) async throws -> [ScanItem] {
        var items: [ScanItem] = []
        for url in FileScanner.children(of: context.url("Library/Saved Application State"))
        where url.pathExtension == "savedState" {
            try Task.checkCancellation()
            let identifier = url.deletingPathExtension().lastPathComponent
            let item = context.makeItem(
                url: url, category: category, kind: "窗口恢复数据",
                owner: context.catalog.owner(forIdentifier: identifier),
                action: .delete
            )
            if let item { items.append(item) }
        }
        return items
    }
}

/// Xcode 与模拟器产生的可重建数据
struct DeveloperJunkRule: ScanRule {
    let id = "developer"
    let title = "开发工具残留"
    let category = ScanCategory.junk
    let requiresFullDiskAccess = false

    private struct Target {
        let path: String
        let kind: String
        let recommended: Bool
    }

    private static let targets = [
        Target(path: "Library/Developer/Xcode/DerivedData", kind: "Xcode 派生数据", recommended: true),
        Target(path: "Library/Developer/CoreSimulator/Caches", kind: "模拟器缓存", recommended: true),
        // 设备支持文件可以重建，但需要重新连接设备下载，默认不勾选
        Target(path: "Library/Developer/Xcode/iOS DeviceSupport", kind: "iOS 设备支持文件", recommended: false),
        Target(path: "Library/Developer/Xcode/watchOS DeviceSupport", kind: "watchOS 设备支持文件", recommended: false),
    ]

    func scan(in context: ScanContext) async throws -> [ScanItem] {
        let owner = context.catalog.owner(bundleID: "com.apple.dt.Xcode", fallbackName: "Xcode")
        var items: [ScanItem] = []
        for target in Self.targets {
            try Task.checkCancellation()
            let url = context.url(target.path)
            guard FileScanner.isDirectory(url) else { continue }
            let item = context.makeItem(
                url: url, category: category, kind: target.kind,
                owner: owner, action: .deleteContents, recommended: target.recommended
            )
            if let item { items.append(item) }
        }
        return items
    }
}

/// 废纸篓（~/.Trash 受 TCC 保护，需要完全磁盘访问权限）
struct TrashRule: ScanRule {
    let id = "trash"
    let title = "废纸篓"
    let category = ScanCategory.junk
    let requiresFullDiskAccess = true

    func scan(in context: ScanContext) async throws -> [ScanItem] {
        let item = context.makeItem(
            url: context.url(".Trash"), category: category, kind: "清空废纸篓",
            owner: .trash, action: .deleteContents, recommended: false, minimumSize: 1
        )
        return item.map { [$0] } ?? []
    }
}

/// 「下载」中的安装包。属于用户文件，默认不勾选，清理时移到废纸篓。
struct InstallerPackagesRule: ScanRule {
    let id = "installers"
    let title = "安装包"
    let category = ScanCategory.junk
    let requiresFullDiskAccess = true

    static let extensions: Set<String> = ["dmg", "pkg", "mpkg", "xip"]

    func scan(in context: ScanContext) async throws -> [ScanItem] {
        var items: [ScanItem] = []
        for url in FileScanner.children(of: context.url("Downloads"))
        where Self.extensions.contains(url.pathExtension.lowercased()) {
            try Task.checkCancellation()
            let item = context.makeItem(
                url: url, category: category, kind: "安装包",
                owner: context.catalog.owner(forDocument: url),
                action: .moveToTrash, recommended: false
            )
            if let item { items.append(item) }
        }
        return items
    }
}
