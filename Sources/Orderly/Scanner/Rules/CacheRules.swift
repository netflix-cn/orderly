import Foundation

/// ~/Library/Caches 下的每个子目录
struct UserCachesRule: ScanRule {
    let id = "user-caches"
    let title = "用户缓存"
    let category = ScanCategory.cache
    let requiresFullDiskAccess = false

    func scan(in context: ScanContext) async throws -> [ScanItem] {
        var items: [ScanItem] = []
        for url in FileScanner.children(of: context.url("Library/Caches")) {
            try Task.checkCancellation()
            let name = url.lastPathComponent
            guard !ScanPolicy.isProtectedCache(name) else { continue }
            let item = context.makeItem(
                url: url,
                category: category,
                kind: "应用缓存",
                owner: context.catalog.owner(forIdentifier: name),
                action: FileScanner.isDirectory(url) ? .deleteContents : .delete
            )
            if let item { items.append(item) }
        }
        return items
    }
}

/// 沙盒 App 的缓存：~/Library/Containers/<id>/Data/Library/Caches
struct ContainerCachesRule: ScanRule {
    let id = "container-caches"
    let title = "沙盒 App 缓存"
    let category = ScanCategory.cache
    let requiresFullDiskAccess = true

    func scan(in context: ScanContext) async throws -> [ScanItem] {
        var items: [ScanItem] = []
        for container in FileScanner.children(of: context.url("Library/Containers")) {
            try Task.checkCancellation()
            let caches = container.appending(path: "Data/Library/Caches", directoryHint: .isDirectory)
            guard FileScanner.isDirectory(caches) else { continue }
            let identifier = Self.identifier(ofContainer: container)
            guard !ScanPolicy.isProtectedCache(identifier) else { continue }
            let item = context.makeItem(
                url: caches,
                category: category,
                kind: "沙盒缓存",
                owner: context.catalog.owner(forIdentifier: identifier),
                action: .deleteContents
            )
            if let item { items.append(item) }
        }
        return items
    }

    /// 容器目录名一般就是 Bundle ID；部分容器以 UUID 命名，真实 ID 记录在元数据中
    static func identifier(ofContainer url: URL) -> String {
        let metadataURL = url.appending(path: ".com.apple.containermanagerd.metadata.plist")
        if let data = try? Data(contentsOf: metadataURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let identifier = plist["MCMMetadataIdentifier"] as? String {
            return identifier
        }
        return url.lastPathComponent
    }
}
