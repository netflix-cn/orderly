import Foundation
import Testing
@testable import Orderly

@MainActor
struct ScanResultsModelTests {
    private let chrome = AppOwner(key: "com.google.chrome", name: "Google Chrome", kind: .installed, bundleID: "com.google.Chrome")
    private let leftover = AppOwner(key: "leftover:com.example.old", name: "com.example.old", kind: .leftover, bundleID: "com.example.old")

    private func item(_ name: String, size: Int64, owner: AppOwner, category: ScanCategory = .cache, recommended: Bool = true) -> ScanItem {
        ScanItem(
            url: URL(filePath: "/Users/test/Library/Caches/\(name)"),
            size: size, category: category, kind: "测试", owner: owner,
            action: .deleteContents, isRecommended: recommended
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
