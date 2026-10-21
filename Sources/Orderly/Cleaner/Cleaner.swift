import Foundation

struct CleanProgress: Sendable {
    var completed = 0
    var total: Int
    var currentPath = ""

    var fraction: Double { total == 0 ? 1 : Double(completed) / Double(total) }
}

struct CleanReport: Sendable {
    struct Failure: Identifiable, Sendable {
        let id = UUID()
        let path: String
        let reason: String
    }

    var cleanedItemIDs: Set<UUID> = []
    /// 永久删除释放的空间
    var freedBytes: Int64 = 0
    /// 移到废纸篓的大小（清空废纸篓后才会真正释放）
    var trashedBytes: Int64 = 0
    var failures: [Failure] = []
}

/// 执行清理。每一项在删除前都要经过 SafetyGuard 检查。
struct Cleaner: Sendable {
    let safety: SafetyGuard

    init(home: URL = .homeDirectory) {
        safety = SafetyGuard(home: home)
    }

    func clean(
        _ items: [ScanItem],
        onProgress: @escaping @MainActor @Sendable (CleanProgress) -> Void
    ) async -> CleanReport {
        var report = CleanReport()
        var progress = CleanProgress(total: items.count)

        for item in items {
            progress.currentPath = item.displayPath
            await onProgress(progress)

            do {
                try safety.validate(item)
                switch item.action {
                case .delete:
                    try FileManager.default.removeItem(at: item.url)
                    report.freedBytes += item.size
                case .deleteContents:
                    // 部分文件删除失败时，仍按实际减少的体积计入
                    defer { report.freedBytes += max(0, item.size - FileScanner.allocatedSize(of: item.url)) }
                    try removeContents(of: item.url)
                case .moveToTrash:
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                    report.trashedBytes += item.size
                }
                report.cleanedItemIDs.insert(item.id)
            } catch {
                report.failures.append(.init(path: item.displayPath, reason: error.localizedDescription))
            }
            progress.completed += 1
        }

        await onProgress(progress)
        return report
    }

    /// 删除目录中的每一项；某项失败时继续删除其余项，最后抛出第一个错误
    private func removeContents(of directory: URL) throws {
        let children = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var firstError: (any Error)?
        for child in children {
            do {
                try FileManager.default.removeItem(at: child)
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError { throw firstError }
    }
}
