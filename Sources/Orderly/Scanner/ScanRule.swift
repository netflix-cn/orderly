import Foundation
import Synchronization

/// 一条扫描规则：负责发现某一类可清理的文件。
///
/// 新增扫描能力时实现一个新的 ScanRule，并注册到 `ScanEngine.standard` 即可。
protocol ScanRule: Sendable {
    var id: String { get }
    /// 显示在扫描进度中的名称
    var title: String { get }
    /// 规则产出的扫描项都属于这个大类
    var category: ScanCategory { get }
    /// 是否需要完全磁盘访问权限。
    /// 没有该权限时访问「下载」「文稿」、其他 App 的容器等目录会触发系统弹窗或直接失败，此时引擎会跳过该规则。
    var requiresFullDiskAccess: Bool { get }

    func scan(in context: ScanContext) async throws -> [ScanItem]
}

struct ScanContext: Sendable {
    let home: URL
    let configuration: ScanConfiguration
    let catalog: AppCatalog
    let progress: ScanProgressReporter

    func url(_ relativePath: String) -> URL {
        home.appending(path: relativePath)
    }
}

/// 把扫描过程中的事件转发给界面，并对高频的路径事件做节流
final class ScanProgressReporter: Sendable {
    private let emit: @Sendable (ScanEvent) -> Void
    private let lastVisit = Mutex(ContinuousClock.now.advanced(by: .seconds(-1)))

    init(emit: @escaping @Sendable (ScanEvent) -> Void) {
        self.emit = emit
    }

    func ruleStarted(_ rule: any ScanRule) {
        emit(.ruleStarted(id: rule.id, category: rule.category))
    }

    func ruleFinished(_ rule: any ScanRule) {
        emit(.ruleFinished(id: rule.id, category: rule.category))
    }

    func found(_ item: ScanItem) {
        emit(.found(category: item.category, size: item.size))
    }

    func visiting(_ url: URL) {
        let now = ContinuousClock.now
        let shouldEmit = lastVisit.withLock { last in
            guard last.duration(to: now) >= .milliseconds(60) else { return false }
            last = now
            return true
        }
        if shouldEmit {
            emit(.visiting(path: url.path))
        }
    }
}
