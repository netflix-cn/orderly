import Foundation

/// 扫描结果的大类
enum ScanCategory: String, CaseIterable, Identifiable, Sendable {
    case junk
    case cache
    case largeFile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .junk: "系统垃圾"
        case .cache: "应用缓存"
        case .largeFile: "大文件"
        }
    }

    var summary: String {
        switch self {
        case .junk: "日志、崩溃报告、废纸篓、安装包与开发残留"
        case .cache: "App 运行时生成、可安全重建的缓存数据"
        case .largeFile: "个人目录中占用空间较大的文件"
        }
    }

    var symbol: String {
        switch self {
        case .junk: "trash"
        case .cache: "archivebox"
        case .largeFile: "doc.on.doc"
        }
    }
}

/// 清理一个扫描项的方式
enum CleanAction: Sendable {
    /// 永久删除该文件或目录
    case delete
    /// 保留目录本身，永久删除其中的内容（缓存目录、废纸篓等）
    case deleteContents
    /// 移到废纸篓，用户仍可恢复（用户自己的文件）
    case moveToTrash
}

/// 扫描项归属的 App（结果默认按它分组）
struct AppOwner: Identifiable, Hashable, Sendable {
    enum Kind: Sendable {
        /// 已安装的 App
        case installed
        /// macOS 系统组件
        case system
        /// 找不到对应 App，多为已卸载 App 的残留
        case leftover
        /// 无法归属到 App（普通文件夹、废纸篓等）
        case other
    }

    /// 分组键
    let key: String
    let name: String
    let kind: Kind
    var bundleID: String?
    var appURL: URL?
    /// 没有 App 图标时使用的 SF Symbol
    var symbol: String = "folder"

    var id: String { key }

    static let system = AppOwner(key: "macos-system", name: "macOS 系统", kind: .system, symbol: "apple.logo")
    static let trash = AppOwner(key: "trash", name: "废纸篓", kind: .other, symbol: "trash")
    static let otherFiles = AppOwner(key: "other-files", name: "其他文件", kind: .other, symbol: "doc")
}

/// 一个可清理的文件或目录
struct ScanItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    /// 实际占用的磁盘空间（字节）
    let size: Int64
    let category: ScanCategory
    /// 细分类型说明，例如「崩溃报告」「Xcode 派生数据」
    let kind: String
    let owner: AppOwner
    let action: CleanAction
    /// 是否推荐清理（决定扫描完成后是否默认勾选）
    let isRecommended: Bool
    var modificationDate: Date?

    var name: String { url.lastPathComponent }
    var displayPath: String { (url.path as NSString).abbreviatingWithTildeInPath }

    static func == (lhs: ScanItem, rhs: ScanItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ScanConfiguration: Sendable {
    var hasFullDiskAccess: Bool
    /// 达到该大小的文件视为大文件
    var largeFileThreshold: Int64 = 100 * 1024 * 1024
    /// 小于该大小的扫描项忽略，避免结果里充斥空目录
    var minimumItemSize: Int64 = 10 * 1024
}

struct ScanResult: Sendable {
    var items: [ScanItem]
    /// 因缺少完全磁盘访问权限而跳过的扫描项标题
    var skippedRuleTitles: [String]
    var duration: Duration

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

/// 扫描过程中上报给界面的事件
enum ScanEvent: Sendable {
    case ruleStarted(id: String, category: ScanCategory)
    case visiting(path: String)
    case found(category: ScanCategory, size: Int64)
    case ruleFinished(id: String, category: ScanCategory)
}
