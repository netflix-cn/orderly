import Foundation
import Testing
@testable import Orderly

/// 在临时目录中模拟个人目录，验证安全检查与清理行为
struct CleanerTests {
    let home: URL

    init() throws {
        home = FileManager.default.temporaryDirectory.appending(path: "OrderlyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home.appending(path: "Library/Caches"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home.appending(path: ".Trash"), withIntermediateDirectories: true)
    }

    private func item(_ url: URL, action: CleanAction, size: Int64 = 0) -> ScanItem {
        ScanItem(url: url, size: size, category: .cache, kind: "测试", owner: .otherFiles, action: action, isRecommended: true)
    }

    private func write(_ relativePath: String, bytes: Int = 64 * 1024) throws -> URL {
        let url = home.appending(path: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: bytes).write(to: url)
        return url
    }

    @Test func rejectsPathsOutsideHome() {
        let safety = SafetyGuard(home: home)
        #expect(throws: CleanError.outsideHome) {
            try safety.validate(item(URL(filePath: "/System/Library/Caches"), action: .deleteContents))
        }
        #expect(throws: CleanError.outsideHome) {
            try safety.validate(item(home.appending(path: "../escape"), action: .delete))
        }
    }

    @Test func rejectsProtectedDirectories() {
        let safety = SafetyGuard(home: home)
        for path in ["Library", "Library/Caches", "Documents", "Downloads"] {
            #expect(throws: CleanError.protectedLocation) {
                try safety.validate(item(home.appending(path: path), action: .deleteContents))
            }
        }
        #expect(throws: CleanError.self) {
            try safety.validate(item(home, action: .delete))
        }
    }

    @Test func trashCanOnlyBeEmptied() throws {
        let safety = SafetyGuard(home: home)
        let trash = home.appending(path: ".Trash")
        try safety.validate(item(trash, action: .deleteContents))
        #expect(throws: CleanError.protectedLocation) {
            try safety.validate(item(trash, action: .delete))
        }
    }

    @Test func deleteContentsKeepsDirectory() async throws {
        let cacheDirectory = home.appending(path: "Library/Caches/com.example.App")
        _ = try write("Library/Caches/com.example.App/a.bin")
        _ = try write("Library/Caches/com.example.App/nested/b.bin")
        let size = FileScanner.allocatedSize(of: cacheDirectory)
        #expect(size > 0)

        let report = await Cleaner(home: home).clean([item(cacheDirectory, action: .deleteContents, size: size)]) { _ in }

        #expect(report.failures.isEmpty)
        #expect(report.freedBytes == size)
        #expect(FileScanner.isDirectory(cacheDirectory))
        #expect(FileScanner.children(of: cacheDirectory, includingHidden: true).isEmpty)
    }

    @Test func refusedItemsAreReportedNotDeleted() async throws {
        let documents = home.appending(path: "Documents")
        _ = try write("Documents/keep.txt")

        let report = await Cleaner(home: home).clean([item(documents, action: .deleteContents)]) { _ in }

        #expect(report.cleanedItemIDs.isEmpty)
        #expect(report.failures.count == 1)
        #expect(FileManager.default.fileExists(atPath: documents.appending(path: "keep.txt").path))
    }
}
