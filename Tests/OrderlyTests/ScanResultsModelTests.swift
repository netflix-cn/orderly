import Foundation
import Testing
@testable import Orderly

@MainActor
struct ScanResultsModelTests {
    private let chrome = AppOwner(key: "com.google.chrome", name: "Google Chrome", kind: .installed, bundleID: "com.google.Chrome")
    private let leftover = AppOwner(key: "leftover:com.example.old", name: "com.example.old", kind: .leftover, bundleID: "com.example.old")

    private func item(_ name: String, size: Int64, owner: AppOwner, category: ScanCategory = .cache, action: CleanAction = .deleteContents, recommended: Bool = true) -> ScanItem {
        ScanItem(
            url: URL(filePath: "/Users/test/Library/Caches/\(name)"),
            size: size, category: category, kind: "测试", owner: owner,
            action: action, isRecommended: recommended
        )
    }

    private func makeModel(running: Set<String> = []) -> ScanResultsModel {
        ScanResultsModel(
            result: ScanResult(
                items: [
                    item("a", size: 100, owner: chrome),
                    item("b", size: 300, owner: chrome, category: .largeFile, recommended: false),
                    item("c", size: 50, owner: leftover, category: .junk),
                ],
                skippedRuleTitles: [],
                duration: .zero
            ),
            runningBundleIDs: running
        )
    }

    @Test func runningAppsAreNotSelectedByDefault() {
        let model = makeModel(running: ["com.google.chrome"])
        #expect(model.groups[0].isRunning)
        #expect(model.checkState(of: model.groups[0]) == .off)
        #expect(model.selectedSize == 50)
    }

    @Test func groupsByAppSortedBySize() {
        let model = makeModel()
        #expect(model.groups.map(\.title) == ["Google Chrome", "com.example.old"])
        #expect(model.groups.first?.totalSize == 400)
        #expect(model.focusedGroupID == model.groups.first?.id)
    }

    @Test func groupsByCategoryInFixedOrder() {
        let model = makeModel()
        model.grouping = .byCategory
        #expect(model.groups.map(\.title) == [ScanCategory.junk.title, ScanCategory.cache.title, ScanCategory.largeFile.title])
    }

    @Test func selectsOnlyRecommendedItemsByDefault() {
        let model = makeModel()
        #expect(model.selectedCount == 2)
        #expect(model.selectedSize == 150)
        #expect(model.checkState(of: model.groups[0]) == .mixed)
    }

    @Test func existingTrashRequiresAnExplicitSelection() async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let trash = home.appending(path: ".Trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        try Data(repeating: 42, count: 8192).write(to: trash.appending(path: "keep.txt"))
        let context = ScanContext(
            home: home,
            configuration: ScanConfiguration(hasFullDiskAccess: true),
            catalog: AppCatalog(entries: [], usesLaunchServices: false),
            progress: ScanProgressReporter { _ in }
        )
        let scanned = try await TrashRule().scan(in: context)
        let trashItem = try #require(scanned.first)
        let model = ScanResultsModel(
            result: ScanResult(items: scanned, skippedRuleTitles: [], duration: .zero),
            runningBundleIDs: []
        )
        #expect(!model.isSelected(trashItem))
        model.toggle(trashItem)
        #expect(model.cleanupSummary.actionTitle == "清空废纸篓")
        #expect(model.cleanupSummary.existingTrashBytes == trashItem.size)
        #expect(model.cleanupSummary.estimatedFreedBytes == trashItem.size)
        model.selectRecommended()
        #expect(!model.isSelected(trashItem))
        #expect(model.cleanupSummary.existingTrashBytes == nil)
    }

    @Test func cleanupSummarySeparatesFreedSpaceFromTrashTransfers() {
        let log = item("log", size: 20, owner: .system, action: .delete)
        let cache = item("cache", size: 30, owner: chrome)
        let trash = item("trash", size: 40, owner: .trash, recommended: false)
        let installer = item("disk.dmg", size: 100, owner: .otherFiles, action: .moveToTrash, recommended: false)
        let model = ScanResultsModel(
            result: ScanResult(items: [log, cache, trash, installer], skippedRuleTitles: [], duration: .zero),
            runningBundleIDs: []
        )
        #expect(model.cleanupSummary.actionTitle == "永久清理")
        #expect(model.cleanupSummary.estimatedFreedBytes == 50)
        #expect(model.cleanupSummary.deletionCount == 2)
        model.toggle(trash)
        model.toggle(installer)
        #expect(model.cleanupSummary.actionTitle == "清理所选项目")
        #expect(model.cleanupSummary.deletionBytes == 50)
        #expect(model.cleanupSummary.existingTrashBytes == 40)
        #expect(model.cleanupSummary.estimatedFreedBytes == 90)
        #expect(model.cleanupSummary.moveToTrashCount == 1)
        #expect(model.cleanupSummary.moveToTrashBytes == 100)
        model.deselectAll()
        #expect(model.cleanupSummary.estimatedFreedBytes == 0)
        #expect(model.cleanupSummary.moveToTrashCount == 0)
        model.toggle(installer)
        #expect(model.cleanupSummary.actionTitle == "移到废纸篓")
        #expect(model.cleanupSummary.estimatedFreedBytes == 0)
        #expect(model.cleanupSummary.moveToTrashBytes == installer.size)
    }

    @Test func togglingGroupSelectsAllThenNone() {
        let model = makeModel()
        let chromeGroup = model.groups[0]
        model.toggle(chromeGroup)
        #expect(model.checkState(of: chromeGroup) == .on)
        model.toggle(chromeGroup)
        #expect(model.checkState(of: chromeGroup) == .off)
    }

    @Test func removingCleanedItemsRebuildsGroups() {
        let model = makeModel()
        let leftoverIDs = Set(model.items.filter { $0.owner == leftover }.map(\.id))
        model.removeItems(withIDs: leftoverIDs)
        #expect(model.groups.map(\.title) == ["Google Chrome"])
        #expect(model.selectedCount == 1)
    }
}
