import Foundation

/// 扫描进度（界面状态），由 ScanEvent 逐条累积
struct ScanProgress {
    enum Status {
        case pending
        case running
        case done
        /// 没有可执行的规则（缺少权限）
        case skipped
    }

    struct CategoryState {
        var ruleCount = 0
        var startedRules = 0
        var finishedRules = 0
        var itemCount = 0
        var bytes: Int64 = 0

        var status: Status {
            if ruleCount == 0 { return .skipped }
            if finishedRules == ruleCount { return .done }
            return startedRules > 0 ? .running : .pending
        }
    }

    private(set) var categories: [ScanCategory: CategoryState] = [:]
    private(set) var currentPath = ""
    private(set) var totalRules = 0
    private(set) var finishedRules = 0

    init(rules: [any ScanRule]) {
        for category in ScanCategory.allCases {
            categories[category] = CategoryState()
        }
        for rule in rules {
            categories[rule.category, default: CategoryState()].ruleCount += 1
        }
        totalRules = rules.count
    }

    var fraction: Double {
        totalRules == 0 ? 0 : Double(finishedRules) / Double(totalRules)
    }

    var foundBytes: Int64 {
        categories.values.reduce(0) { $0 + $1.bytes }
    }

    func state(of category: ScanCategory) -> CategoryState {
        categories[category] ?? CategoryState()
    }

    mutating func apply(_ event: ScanEvent) {
        switch event {
        case let .ruleStarted(_, category):
            categories[category, default: CategoryState()].startedRules += 1
        case let .visiting(path):
            currentPath = (path as NSString).abbreviatingWithTildeInPath
        case let .found(category, size):
            categories[category, default: CategoryState()].itemCount += 1
            categories[category, default: CategoryState()].bytes += size
        case let .ruleFinished(_, category):
            categories[category, default: CategoryState()].finishedRules += 1
            finishedRules += 1
        }
    }
}
