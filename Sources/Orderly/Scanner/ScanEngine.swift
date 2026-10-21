import Foundation

/// 并发执行所有扫描规则并汇总结果
struct ScanEngine: Sendable {
    let rules: [any ScanRule]

    static let standard = ScanEngine(rules: [
        UserCachesRule(),
        ContainerCachesRule(),
        LogsRule(),
        SavedApplicationStateRule(),
        DeveloperJunkRule(),
        TrashRule(),
        InstallerPackagesRule(),
        LargeFileRule(),
    ])

    /// 当前权限下可以执行的规则
    func activeRules(for configuration: ScanConfiguration) -> [any ScanRule] {
        rules.filter { configuration.hasFullDiskAccess || !$0.requiresFullDiskAccess }
    }

    func run(
        configuration: ScanConfiguration,
        onEvent: @escaping @Sendable (ScanEvent) -> Void
    ) async throws -> ScanResult {
        let clock = ContinuousClock()
        let start = clock.now
        let active = activeRules(for: configuration)
        let context = ScanContext(
            home: .homeDirectory,
            configuration: configuration,
            catalog: .installed(),
            progress: ScanProgressReporter(emit: onEvent)
        )

        let buckets = try await withThrowingTaskGroup(of: (Int, [ScanItem]).self) { group in
            for (index, rule) in active.enumerated() {
                group.addTask {
                    context.progress.ruleStarted(rule)
                    let items = try await rule.scan(in: context)
                    context.progress.ruleFinished(rule)
                    return (index, items)
                }
            }
            var buckets = Array(repeating: [ScanItem](), count: active.count)
            for try await (index, items) in group {
                buckets[index] = items
            }
            return buckets
        }
        try Task.checkCancellation()

        // 不同规则可能命中同一路径（例如「下载」中的大安装包），按规则顺序保留先出现的
        var seenPaths = Set<String>()
        let items = buckets.joined().filter { seenPaths.insert($0.url.standardizedFileURL.path).inserted }
        let activeIDs = Set(active.map(\.id))

        return ScanResult(
            items: items,
            skippedRuleTitles: rules.filter { !activeIDs.contains($0.id) }.map(\.title),
            duration: start.duration(to: clock.now)
        )
    }
}
