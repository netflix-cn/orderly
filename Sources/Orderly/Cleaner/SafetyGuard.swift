import Foundation

enum CleanError: LocalizedError {
    case outsideHome
    case protectedLocation
    case symbolicLink

    var errorDescription: String? {
        switch self {
        case .outsideHome: "不在个人目录内，已拒绝删除"
        case .protectedLocation: "受保护的系统目录，已拒绝删除"
        case .symbolicLink: "目标是符号链接，已拒绝清空"
        }
    }
}

/// 删除前的最后一道防线：无论扫描规则产出了什么，都不允许删除个人目录以外的内容或关键目录本身。
struct SafetyGuard: Sendable {
    let home: URL
    private let protectedPaths: Set<String>
    private let trashPath: String

    init(home: URL) {
        let home = home.standardizedFileURL.resolvingSymlinksInPath()
        self.home = home
        let relativePaths = [
            "Library", "Library/Caches", "Library/Logs", "Library/Containers", "Library/Group Containers",
            "Library/Application Support", "Library/Preferences", "Library/Developer",
            "Library/Mobile Documents", "Library/CloudStorage",
            "Applications", "Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures", "Public",
        ]
        protectedPaths = Set([home.path] + relativePaths.map { home.appending(path: $0).path })
        trashPath = home.appending(path: ".Trash").path
    }

    func validate(_ item: ScanItem) throws(CleanError) {
        let url = item.url.standardizedFileURL
        // 只解析父目录的符号链接：目标本身是链接时，删除的是链接而不是它指向的内容
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath()
        guard parent.path == home.path || parent.path.hasPrefix(home.path + "/") else {
            throw .outsideHome
        }
        let path = parent.appending(path: url.lastPathComponent).path
        guard !protectedPaths.contains(path) else {
            throw .protectedLocation
        }

        switch item.action {
        case .delete, .moveToTrash:
            // 废纸篓只能清空，不能删除目录本身
            guard path != trashPath else { throw .protectedLocation }
        case .deleteContents:
            let isSymbolicLink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
            guard !isSymbolicLink else { throw .symbolicLink }
        }
    }
}
