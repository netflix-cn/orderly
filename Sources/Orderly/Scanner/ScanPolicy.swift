import Foundation

/// 扫描时需要跳过的内容
enum ScanPolicy {
    /// 与 iCloud 同步、账户、家庭共享等系统服务相关的缓存，删除可能导致重新同步或服务异常
    static let protectedCacheNames: Set<String> = [
        "com.apple.bird",
        "com.apple.cloudkit",
        "cloudkit",
        "com.apple.akd",
        "com.apple.homed",
        "com.apple.homekit",
        "familycircle",
        "com.apple.containermanagerd",
        "com.apple.ap.adprivacyd",
    ]

    static func isProtectedCache(_ name: String) -> Bool {
        let name = name.lowercased()
        return protectedCacheNames.contains(name) || name == Bundle.main.bundleIdentifier?.lowercased()
    }
}

extension ScanContext {
    /// 计算大小并生成扫描项，同时上报进度。小于最小阈值时返回 nil。
    func makeItem(
        url: URL,
        category: ScanCategory,
        kind: String,
        owner: AppOwner,
        action: CleanAction,
        recommended: Bool = true,
        minimumSize: Int64? = nil
    ) -> ScanItem? {
        progress.visiting(url)
        let size = FileScanner.allocatedSize(of: url)
        guard size >= (minimumSize ?? configuration.minimumItemSize) else { return nil }
        let item = ScanItem(
            url: url,
            size: size,
            category: category,
            kind: kind,
            owner: owner,
            action: action,
            isRecommended: recommended,
            modificationDate: FileScanner.modificationDate(of: url)
        )
        progress.found(item)
        return item
    }
}
