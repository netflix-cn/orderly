import AppKit

/// 已安装 App 的索引，用于把缓存目录、日志、文件等归属到具体 App。
struct AppCatalog: Sendable {
    struct Entry: Hashable, Sendable {
        let bundleID: String
        let name: String
        let url: URL
        /// 可执行文件名（崩溃报告以进程名命名）
        var executableName: String?
    }

    private let byBundleID: [String: Entry]
    private let byName: [String: Entry]
    /// 厂商名（Bundle ID 第二段）→ 该厂商唯一安装的 App，用于归属「Google」「Mozilla」这类厂商目录
    private let byVendor: [String: Entry]
    /// 索引中找不到时是否再向 LaunchServices 查询（单元测试中关闭）
    private let usesLaunchServices: Bool

    init(entries: [Entry], usesLaunchServices: Bool = true) {
        var byBundleID: [String: Entry] = [:]
        var byName: [String: Entry] = [:]
        // 先出现的优先（/Applications 优先于系统目录）
        for entry in entries {
            byBundleID[entry.bundleID.lowercased()] = byBundleID[entry.bundleID.lowercased()] ?? entry
            for name in [entry.name, entry.executableName].compactMap({ $0?.lowercased() }) {
                byName[name] = byName[name] ?? entry
            }
        }

        var appsByVendor: [String: [Entry]] = [:]
        for entry in byBundleID.values {
            let components = entry.bundleID.lowercased().split(separator: ".")
            guard components.count >= 3, components[1] != "apple" else { continue }
            appsByVendor[String(components[1]), default: []].append(entry)
        }
        // 同一厂商装了多个 App 时无法判断归属，不参与匹配
        self.byVendor = appsByVendor.compactMapValues { $0.count == 1 ? $0[0] : nil }
        self.byBundleID = byBundleID
        self.byName = byName
        self.usesLaunchServices = usesLaunchServices
    }

    /// 扫描常见安装位置，建立索引
    static func installed() -> AppCatalog {
        let roots = [
            "/Applications",
            "/Applications/Utilities",
            URL.homeDirectory.appending(path: "Applications").path,
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices",
        ]
        let entries = roots.flatMap { root in
            FileScanner.children(of: URL(filePath: root, directoryHint: .isDirectory))
                .filter { $0.pathExtension == "app" }
                .compactMap(entry(forAppAt:))
        }
        return AppCatalog(entries: entries)
    }

    static func entry(forAppAt url: URL) -> Entry? {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return nil }
        // displayName 会返回本地化名称，例如「访达」「邮件」
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
        return Entry(
            bundleID: bundleID,
            name: name,
            url: url,
            executableName: bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        )
    }

    // MARK: - 归属判断

    /// 根据目录名判断归属。目录名通常是 Bundle ID（com.google.Chrome），也可能是 App 名称（Firefox）。
    func owner(forIdentifier rawIdentifier: String) -> AppOwner {
        let identifier = rawIdentifier.trimmingCharacters(in: .whitespaces)
        let lowercased = identifier.lowercased()

        if Self.looksLikeBundleID(identifier) {
            if let entry = lookup(bundleID: identifier) {
                return owner(for: entry)
            }
            if lowercased.hasPrefix("com.apple.") {
                return .system
            }
            return AppOwner(key: "leftover:\(lowercased)", name: identifier, kind: .leftover, bundleID: identifier, symbol: "app.dashed")
        }

        if let entry = byName[lowercased] ?? byVendor[lowercased] {
            return owner(for: entry)
        }
        return AppOwner(key: "folder:\(lowercased)", name: identifier, kind: .other, symbol: "folder")
    }

    /// 已知 Bundle ID 的归属（例如 Xcode 的派生数据）；App 未安装时使用 fallbackName 显示
    func owner(bundleID: String, fallbackName: String) -> AppOwner {
        if let entry = lookup(bundleID: bundleID) {
            return owner(for: entry)
        }
        return AppOwner(key: "leftover:\(bundleID.lowercased())", name: fallbackName, kind: .leftover, bundleID: bundleID, symbol: "app.dashed")
    }

    /// 根据进程名归属（崩溃报告）。依次去掉末尾单词重试：「Google Chrome Helper」→「Google Chrome」
    func owner(forProcessName processName: String) -> AppOwner? {
        var words = processName.split(separator: " ")
        while !words.isEmpty {
            if let entry = byName[words.joined(separator: " ").lowercased()] {
                return owner(for: entry)
            }
            words.removeLast()
        }
        return nil
    }

    /// 普通文件按「默认打开它的 App」归属
    func owner(forDocument url: URL) -> AppOwner {
        guard usesLaunchServices,
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: url),
              let entry = Self.entry(forAppAt: appURL)
        else {
            return .otherFiles
        }
        return owner(for: entry)
    }

    // MARK: - Private

    /// 先精确匹配，再逐级去掉末尾组件匹配：com.google.Chrome.helper → com.google.Chrome
    private func lookup(bundleID: String) -> Entry? {
        var components = bundleID.lowercased().split(separator: ".")
        if let entry = byBundleID[components.joined(separator: ".")] {
            return entry
        }
        while components.count > 3 {
            components.removeLast()
            if let entry = byBundleID[components.joined(separator: ".")] {
                return entry
            }
        }
        if usesLaunchServices, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return Self.entry(forAppAt: url)
        }
        return nil
    }

    private func owner(for entry: Entry) -> AppOwner {
        AppOwner(
            key: entry.bundleID.lowercased(),
            name: entry.name,
            kind: .installed,
            bundleID: entry.bundleID,
            appURL: entry.url,
            symbol: "app"
        )
    }

    static func looksLikeBundleID(_ string: String) -> Bool {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, parts[0].first?.isLetter == true else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        }
    }
}
