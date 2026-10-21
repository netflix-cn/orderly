import Foundation

/// 个人目录中的大文件。属于用户文件，默认不勾选，清理时移到废纸篓。
struct LargeFileRule: ScanRule {
    let id = "large-files"
    let title = "大文件"
    let category = ScanCategory.largeFile
    /// 需要遍历「文稿」「桌面」「下载」，没有权限时会触发多次系统弹窗
    let requiresFullDiskAccess = true

    func scan(in context: ScanContext) async throws -> [ScanItem] {
        try Self.collect(in: context, category: category)
    }

    private static let keys: Set<URLResourceKey> = FileScanner.sizeKeys.union([
        .contentModificationDateKey, .localizedTypeDescriptionKey,
    ])

    private static func collect(in context: ScanContext, category: ScanCategory) throws -> [ScanItem] {
        // ~/Library 由其他规则负责，且其中多为 App 数据，不应作为「大文件」交给用户删除
        let excludedDirectories: Set<String> = [
            context.url("Library").path,
            context.url(".Trash").path,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: context.home,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var items: [ScanItem] = []
        var ownersByExtension: [String: AppOwner] = [:]
        var visited = 0

        for case let url as URL in enumerator {
            visited += 1
            if visited % 512 == 0 {
                try Task.checkCancellation()
            }
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }

            if values.isDirectory == true {
                if excludedDirectories.contains(url.path) {
                    enumerator.skipDescendants()
                } else {
                    context.progress.visiting(url)
                }
                continue
            }

            guard values.isRegularFile == true else { continue }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size >= context.configuration.largeFileThreshold else { continue }

            let fileExtension = url.pathExtension.lowercased()
            let owner: AppOwner
            if let cached = ownersByExtension[fileExtension] {
                owner = cached
            } else {
                owner = context.catalog.owner(forDocument: url)
                ownersByExtension[fileExtension] = owner
            }

            let item = ScanItem(
                url: url,
                size: size,
                category: category,
                kind: values.localizedTypeDescription ?? "文件",
                owner: owner,
                action: .moveToTrash,
                isRecommended: false,
                modificationDate: values.contentModificationDate
            )
            context.progress.found(item)
            items.append(item)
        }
        return items
    }
}
