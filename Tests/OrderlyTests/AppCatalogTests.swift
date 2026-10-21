import Foundation
import Testing
@testable import Orderly

struct AppCatalogTests {
    private let catalog = AppCatalog(
        entries: [
            .init(bundleID: "com.google.Chrome", name: "Google Chrome", url: URL(filePath: "/Applications/Google Chrome.app"), executableName: "Google Chrome"),
            .init(bundleID: "org.mozilla.firefox", name: "Firefox", url: URL(filePath: "/Applications/Firefox.app"), executableName: "firefox"),
            .init(bundleID: "com.apple.Safari", name: "Safari", url: URL(filePath: "/Applications/Safari.app")),
        ],
        usesLaunchServices: false
    )

    @Test(arguments: ["com.google.Chrome", "org.mozilla.firefox", "a.b", "com.apple.dt.Xcode"])
    func recognizesBundleIDs(_ identifier: String) {
        #expect(AppCatalog.looksLikeBundleID(identifier))
    }

    @Test(arguments: ["Firefox", "Google Chrome", "fsck_apfs", ".hidden", "1password.data", "a..b"])
    func rejectsNonBundleIDs(_ identifier: String) {
        #expect(!AppCatalog.looksLikeBundleID(identifier))
    }

    @Test func matchesExactBundleIDCaseInsensitively() {
        let owner = catalog.owner(forIdentifier: "com.google.chrome")
        #expect(owner.kind == .installed)
        #expect(owner.name == "Google Chrome")
    }

    @Test func matchesHelperBundleIDByPrefix() {
        let owner = catalog.owner(forIdentifier: "com.google.Chrome.helper.renderer")
        #expect(owner.key == "com.google.chrome")
    }

    @Test func matchesFolderNamedAfterApp() {
        #expect(catalog.owner(forIdentifier: "Firefox").key == "org.mozilla.firefox")
    }

    @Test func matchesVendorFolderWhenVendorHasOneApp() {
        #expect(catalog.owner(forIdentifier: "Mozilla").key == "org.mozilla.firefox")
        #expect(catalog.owner(forIdentifier: "Google").key == "com.google.chrome")
    }

    @Test func ambiguousVendorFolderStaysUnattributed() {
        let catalog = AppCatalog(
            entries: [
                .init(bundleID: "com.jetbrains.intellij", name: "IntelliJ IDEA", url: URL(filePath: "/Applications/IntelliJ IDEA.app")),
                .init(bundleID: "com.jetbrains.pycharm", name: "PyCharm", url: URL(filePath: "/Applications/PyCharm.app")),
            ],
            usesLaunchServices: false
        )
        #expect(catalog.owner(forIdentifier: "JetBrains").kind == .other)
    }

    @Test func unknownAppleIdentifierBelongsToSystem() {
        #expect(catalog.owner(forIdentifier: "com.apple.akd").key == AppOwner.system.key)
    }

    @Test func unknownBundleIDIsLeftover() {
        let owner = catalog.owner(forIdentifier: "com.example.Removed")
        #expect(owner.kind == .leftover)
        #expect(owner.name == "com.example.Removed")
    }

    @Test func plainFolderIsOther() {
        let owner = catalog.owner(forIdentifier: "node-gyp")
        #expect(owner.kind == .other)
        #expect(owner.appURL == nil)
    }

    @Test func processNameDropsTrailingWords() {
        #expect(catalog.owner(forProcessName: "Google Chrome Helper (Renderer)")?.key == "com.google.chrome")
        #expect(catalog.owner(forProcessName: "firefox")?.key == "org.mozilla.firefox")
        #expect(catalog.owner(forProcessName: "WindowServer") == nil)
    }

    @Test func crashReportFileNameParsing() {
        #expect(LogsRule.processName(fromCrashReport: "Google Chrome-2026-10-21-101010.ips") == "Google Chrome")
        #expect(LogsRule.processName(fromCrashReport: "WindowServer_2026-01-02-030405_Mac.userspace_watchdog_timeout.spin") == "WindowServer")
        #expect(LogsRule.processName(fromCrashReport: "notes.txt") == nil)
    }
}
