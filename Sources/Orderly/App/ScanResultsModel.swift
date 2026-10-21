import AppKit
import Observation

enum CheckState {
    case on
    case off
    case mixed
}

/// 扫描结果页的状态：分组、勾选、汇总
@MainActor
@Observable
final class ScanResultsModel {
    enum Grouping: String, CaseIterable, Identifiable {
        case byApp
        case byCategory

        var id: String { rawValue }
        var title: String {
            switch self {
            case .byApp: "按应用"
            case .byCategory: "按类型"
            }
        }
    }

    struct Group: Identifiable {
        enum Header {
            case app(AppOwner)
            case category(ScanCategory)
        }

        let id: String
        let header: Header
        /// 按体积从大到小排列
        let items: [ScanItem]
        let totalSize: Int64
        /// 所属 App 正在运行（仅按应用分组时有意义）
        let isRunning: Bool

        var title: String {
            switch header {
            case let .app(owner): owner.name
            case let .category(category): category.title
            }
        }

        var owner: AppOwner? {
            if case let .app(owner) = header { owner } else { nil }
        }
    }

    let skippedRuleTitles: [String]
    let duration: Duration

    var grouping: Grouping = .byApp
    /// 侧边栏当前选中的分组
    var focusedGroupID: String?

    private(set) var items: [ScanItem]
    private(set) var selection: Set<ScanItem.ID>
    private(set) var appGroups: [Group] = []
    private(set) var categoryGroups: [Group] = []
    private let runningBundleIDs: Set<String>

    /// - Parameter runningBundleIDs: 正在运行的 App（小写 Bundle ID），默认读取当前系统状态
    init(result: ScanResult, runningBundleIDs: Set<String>? = nil) {
        skippedRuleTitles = result.skippedRuleTitles
        duration = result.duration
        items = result.items
        self.runningBundleIDs = runningBundleIDs
            ?? Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
        selection = []
        // 默认只勾选推荐清理、且所属 App 未在运行的项目
        selection = Set(items.filter { $0.isRecommended && !isRunning($0.owner) }.map(\.id))
        rebuildGroups()
        focusedGroupID = groups.first?.id
    }

    var groups: [Group] {
        grouping == .byApp ? appGroups : categoryGroups
    }

    var focusedGroup: Group? {
        groups.first { $0.id == focusedGroupID }
    }

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedItems: [ScanItem] { items.filter { selection.contains($0.id) } }
    var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.size } }
    var selectedCount: Int { selection.count }

    // MARK: - 勾选

    func isSelected(_ item: ScanItem) -> Bool {
        selection.contains(item.id)
    }

    func checkState(of group: Group) -> CheckState {
        let selectedCount = group.items.count { selection.contains($0.id) }
        if selectedCount == 0 { return .off }
        return selectedCount == group.items.count ? .on : .mixed
    }

    func selectedSize(in group: Group) -> Int64 {
        group.items.filter { selection.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    func toggle(_ item: ScanItem) {
        if selection.contains(item.id) {
            selection.remove(item.id)
        } else {
            selection.insert(item.id)
        }
    }

    func toggle(_ group: Group) {
        let ids = group.items.map(\.id)
        if checkState(of: group) == .on {
            selection.subtract(ids)
        } else {
            selection.formUnion(ids)
        }
    }

    func selectRecommended() {
        selection = Set(items.filter { $0.isRecommended && !isRunning($0.owner) }.map(\.id))
    }

    func deselectAll() {
        selection.removeAll()
    }

    /// 清理完成后移除已清理的项目
    func removeItems(withIDs ids: Set<ScanItem.ID>) {
        items.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        rebuildGroups()
        if focusedGroup == nil {
            focusedGroupID = groups.first?.id
        }
    }

    func isRunning(_ owner: AppOwner) -> Bool {
        guard let bundleID = owner.bundleID?.lowercased() else { return false }
        return runningBundleIDs.contains(bundleID)
    }

    // MARK: - Private

    private func rebuildGroups() {
        appGroups = Dictionary(grouping: items, by: \.owner.key)
            .map { key, items in
                makeGroup(id: "app:\(key)", header: .app(items[0].owner), items: items, isRunning: isRunning(items[0].owner))
            }
            .sorted { $0.totalSize > $1.totalSize }

        let itemsByCategory = Dictionary(grouping: items, by: \.category)
        categoryGroups = ScanCategory.allCases.compactMap { category in
            guard let items = itemsByCategory[category] else { return nil }
            return makeGroup(id: "category:\(category.rawValue)", header: .category(category), items: items, isRunning: false)
        }
    }

    private func makeGroup(id: String, header: Group.Header, items: [ScanItem], isRunning: Bool) -> Group {
        Group(
            id: id,
            header: header,
            items: items.sorted { $0.size > $1.size },
            totalSize: items.reduce(0) { $0 + $1.size },
            isRunning: isRunning
        )
    }
}
