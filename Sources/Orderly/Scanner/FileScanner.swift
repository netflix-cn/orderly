import Foundation

/// 文件系统相关的同步工具函数。
///
/// `FileManager.DirectoryEnumerator` 不能在 async 函数里直接 for-in 遍历，
/// 因此遍历逻辑都放在这里的同步函数中，由规则在后台任务里调用。
enum FileScanner {
    static let sizeKeys: Set<URLResourceKey> = [
        .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// 列出目录的直接子项；目录不存在或无权限时返回空数组
    static func children(of url: URL, includingHidden: Bool = false) -> [URL] {
        let options: FileManager.DirectoryEnumerationOptions = includingHidden ? [] : [.skipsHiddenFiles]
        return (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(sizeKeys),
            options: options
        )) ?? []
    }

    static func isDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        return values?.isDirectory == true && values?.isSymbolicLink != true
    }

    static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// 文件或目录实际占用的磁盘空间（字节）。不跟随符号链接。
    /// 在任务被取消时提前返回（结果不完整，调用方会随后抛出取消错误）。
    static func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: sizeKeys), values.isSymbolicLink != true else {
            return 0
        }
        guard values.isDirectory == true else {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(sizeKeys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        var visited = 0
        for case let fileURL as URL in enumerator {
            visited += 1
            if visited % 1024 == 0, Task.isCancelled { break }
            guard let values = try? fileURL.resourceValues(forKeys: sizeKeys), values.isRegularFile == true else {
                continue
            }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
