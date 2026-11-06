import SwiftUI

/// 扫描结果：左侧为分组（默认按应用），右侧为分组内的文件列表
struct ResultsView: View {
    @Environment(AppModel.self) private var model
    @Bindable var results: ScanResultsModel
    @State private var isConfirmingClean = false

    var body: some View {
        let summary = results.cleanupSummary
        NavigationSplitView {
            ResultsSidebar(results: results)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 440)
        } detail: {
            if let group = results.focusedGroup {
                GroupDetailView(results: results, group: group)
            } else if results.groups.isEmpty {
                // ContentUnavailableView 会给标题、说明套上自己的系统字体，字体要直接加在 Text 上
                ContentUnavailableView {
                    Label { Text("没有发现可清理的项目").font(.app(.title2)) } icon: { Image(systemName: "checkmark.seal") }
                } description: {
                    Text(results.skippedRuleTitles.isEmpty ? "你的 Mac 很整洁。" : "本次扫描范围内没有发现项目。")
                        .font(.app(.body))
                }
            } else {
                ContentUnavailableView {
                    Label { Text("选择左侧的分组查看详情").font(.app(.title2)) } icon: { Image(systemName: "sidebar.left") }
                }
            }
        }
        .navigationTitle("扫描结果")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    model.reset()
                } label: {
                    Label("返回", systemImage: "chevron.backward")
                }
                .help("返回首页")
            }
            ToolbarItem(placement: .principal) {
                Picker("分组方式", selection: $results.grouping) {
                    ForEach(ScanResultsModel.Grouping.allCases) { grouping in
                        Text(grouping.title).tag(grouping)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.startScan()
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                .help("重新扫描")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CleanBar(results: results, summary: summary) {
                isConfirmingClean = true
            }
        }
        .onChange(of: results.grouping) {
            results.focusedGroupID = results.groups.first?.id
        }
        .confirmationDialog(
            "处理已选的 \(results.selectedCount) 项？",
            isPresented: $isConfirmingClean,
            titleVisibility: .visible
        ) {
            Button(summary.actionTitle, role: .destructive) {
                model.cleanSelected()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(confirmationMessage(for: summary))
        }
    }

    private func confirmationMessage(for summary: ScanResultsModel.CleanupSummary) -> String {
        var lines: [String] = []
        if let size = summary.existingTrashBytes {
            lines.append("清空现有废纸篓，永久删除其中的全部内容（扫描时为 \(size.formattedBytes)）。")
        }
        if summary.deletionCount > 0 {
            lines.append("永久清理 \(summary.deletionCount) 项（\(summary.deletionBytes.formattedBytes)），删除后无法恢复。")
        }
        if summary.moveToTrashCount > 0 {
            lines.append("将 \(summary.moveToTrashCount) 项（\(summary.moveToTrashBytes.formattedBytes)）移到废纸篓，可在清空前恢复。")
        }
        if summary.includesRunningApp {
            lines.append("部分所属 App 正在运行，建议先退出这些 App。")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - 侧边栏

private struct ResultsSidebar: View {
    @Environment(AppModel.self) private var model
    @Bindable var results: ScanResultsModel

    var body: some View {
        List(selection: $results.focusedGroupID) {
            Section {
                ForEach(results.groups) { group in
                    GroupRow(results: results, group: group)
                }
            } header: {
                HStack {
                    Text("\(results.groups.count) 个\(results.grouping == .byApp ? "应用" : "类型")")
                    Spacer()
                    Text("共 \(results.totalSize.formattedBytes)")
                }
                // 侧边栏分组标题有自己的系统字体
                .font(.app(.subheadline))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !results.skippedRuleTitles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label(model.hasFullDiskAccess ? "已获得完全磁盘访问权限" : "部分位置需要授权",
                          systemImage: model.hasFullDiskAccess ? "checkmark.shield" : "lock")
                        .font(.app(.callout))
                    Text("本次未扫描：\(results.skippedRuleTitles.joined(separator: "、"))")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.hasFullDiskAccess {
                        Button("重新扫描以包含这些位置") { model.startScan() }
                    } else {
                        Button("打开系统设置授权") { FullDiskAccess.openSystemSettings() }
                    }
                }
                .buttonStyle(.link)
                .font(.app(.callout))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
    }
}

private struct GroupRow: View {
    let results: ScanResultsModel
    let group: ScanResultsModel.Group

    var body: some View {
        HStack(spacing: 10) {
            CheckBox(state: results.checkState(of: group)) {
                results.toggle(group)
            }
            GroupIcon(header: group.header, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(group.title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if group.isRunning {
                        TagLabel(text: "运行中", color: .green)
                    } else if group.owner?.kind == .leftover {
                        TagLabel(text: "未安装", color: .secondary)
                    }
                }
                Text("\(group.items.count) 项")
                    .font(.app(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(group.totalSize.formattedBytes)
                .font(.app(.callout))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - 详情

private struct GroupDetailView: View {
    let results: ScanResultsModel
    let group: ScanResultsModel.Group

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                GroupIcon(header: group.header, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.app(.title2))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.app(.callout))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(group.totalSize.formattedBytes)
                        .font(.app(.title2))
                    Text("已选 \(results.selectedSize(in: group).formattedBytes)")
                        .font(.app(.callout))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)

            if group.isRunning {
                Label("\(group.title) 正在运行，清理其缓存前建议先退出该 App。默认未勾选。", systemImage: "exclamationmark.triangle.fill")
                    .font(.app(.callout))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            Divider()

            HStack(spacing: 10) {
                CheckBox(state: results.checkState(of: group)) {
                    results.toggle(group)
                }
                Text("全选")
                Spacer()
                Text("大小")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.app(.callout))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            Divider()

            List(group.items) { item in
                ItemRow(results: results, item: item, showsOwner: results.grouping == .byCategory)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private var subtitle: String {
        switch group.header {
        case let .app(owner):
            switch owner.kind {
            case .installed: owner.appURL.map { ($0.path as NSString).abbreviatingWithTildeInPath } ?? ""
            case .system: "macOS 系统组件产生的数据"
            case .leftover: "未找到对应的 App，可能已被卸载"
            case .other: "\(group.items.count) 项"
            }
        case let .category(category):
            category.summary
        }
    }
}

private struct ItemRow: View {
    let results: ScanResultsModel
    let item: ScanItem
    let showsOwner: Bool

    var body: some View {
        HStack(spacing: 10) {
            CheckBox(state: results.isSelected(item) ? .on : .off) {
                results.toggle(item)
            }
            if showsOwner {
                OwnerIcon(owner: item.owner, size: 22)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(showsOwner && item.owner.name != item.name ? "\(item.owner.name) · \(item.name)" : item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.displayPath)
                    .font(.app(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            TagLabel(text: item.kind, color: Theme.color(for: item.category))
            if let date = item.modificationDate {
                Text(date, format: Date.FormatStyle(date: .numeric, time: .omitted))
                    .font(.app(.caption))
                    .foregroundStyle(.tertiary)
                    .frame(width: 84, alignment: .trailing)
            }
            Text(item.size.formattedBytes)
                .font(.app(.callout))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button("拷贝路径") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
    }
}

// MARK: - 底部操作栏

private struct CleanBar: View {
    let results: ScanResultsModel
    let summary: ScanResultsModel.CleanupSummary
    let onClean: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已选择 \(results.selectedCount) 项")
                        .font(.app(.title3))
                    Text(spaceDescription)
                        .font(.app(.callout))
                        .foregroundStyle(.secondary)
                    if summary.existingTrashBytes != nil {
                        Label("将永久清空现有废纸篓", systemImage: "exclamationmark.triangle")
                            .font(.app(.callout))
                    }
                }
                Spacer()
                Button("仅选推荐项") { results.selectRecommended() }
                Button("全部取消") { results.deselectAll() }
                    .disabled(results.selectedCount == 0)
                Button(action: onClean) {
                    Text(summary.actionTitle)
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(results.selectedCount == 0)
            }
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var spaceDescription: String {
        if results.selectedCount == 0 {
            return "共发现 \(results.items.count) 项，\(results.totalSize.formattedBytes)"
        }
        var parts: [String] = []
        if summary.deletionCount > 0 || summary.existingTrashBytes != nil {
            parts.append("预计释放 \(summary.estimatedFreedBytes.formattedBytes)")
        }
        if summary.moveToTrashCount > 0 {
            parts.append("移到废纸篓 \(summary.moveToTrashBytes.formattedBytes)（清空后释放）")
        }
        return parts.joined(separator: " · ")
    }
}
