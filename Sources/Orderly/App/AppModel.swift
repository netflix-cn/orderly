import SwiftUI

/// 全局状态：驱动「授权 → 等待 → 扫描 → 结果 → 清理 → 完成」的流程
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case permission
        case ready
        case scanning
        case results
        case cleaning
        case finished
    }

    private(set) var phase: Phase
    private(set) var hasFullDiskAccess: Bool
    private(set) var scanProgress = ScanProgress(rules: [])
    private(set) var results: ScanResultsModel?
    private(set) var cleanProgress = CleanProgress(total: 0)
    private(set) var cleanReport: CleanReport?

    private let engine = ScanEngine.standard
    private var scanTask: Task<Void, Never>?

    init() {
        let granted = FullDiskAccess.isGranted
        hasFullDiskAccess = granted
        phase = granted ? .ready : .permission
    }

    // MARK: - 权限

    /// 重新检测权限；在授权页时，获得权限后自动进入等待界面
    func refreshPermission() {
        hasFullDiskAccess = FullDiskAccess.isGranted
        if hasFullDiskAccess && phase == .permission {
            phase = .ready
        }
    }

    /// 暂不授权：只扫描不需要完全磁盘访问权限的位置
    func skipPermission() {
        phase = .ready
    }

    func showPermission() {
        guard phase == .ready || phase == .results else { return }
        results = nil
        phase = .permission
    }

    // MARK: - 扫描

    func startScan() {
        guard phase != .scanning else { return }
        refreshPermission()

        let configuration = ScanConfiguration(hasFullDiskAccess: hasFullDiskAccess)
        let engine = engine
        scanProgress = ScanProgress(rules: engine.activeRules(for: configuration))
        results = nil
        phase = .scanning

        let (events, continuation) = AsyncStream.makeStream(of: ScanEvent.self)
        scanTask = Task {
            let consumer = Task {
                for await event in events {
                    scanProgress.apply(event)
                }
            }
            do {
                let result = try await engine.run(configuration: configuration) { continuation.yield($0) }
                continuation.finish()
                await consumer.value
                results = ScanResultsModel(result: result)
                phase = .results
            } catch {
                // 只有取消会抛出错误
                continuation.finish()
                consumer.cancel()
                if phase == .scanning {
                    phase = .ready
                }
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
    }

    // MARK: - 清理

    func cleanSelected() {
        guard let results, phase == .results else { return }
        let items = results.selectedItems
        guard !items.isEmpty else { return }

        cleanProgress = CleanProgress(total: items.count)
        cleanReport = nil
        phase = .cleaning

        Task {
            let report = await Cleaner().clean(items) { progress in
                self.cleanProgress = progress
            }
            results.removeItems(withIDs: report.cleanedItemIDs)
            cleanReport = report
            phase = .finished
        }
    }

    /// 清理完成后回到结果列表，继续处理剩余项
    func returnToResults() {
        guard results != nil else { return reset() }
        phase = .results
    }

    func reset() {
        results = nil
        cleanReport = nil
        phase = .ready
    }
}
