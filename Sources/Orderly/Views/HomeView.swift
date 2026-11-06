import SwiftUI

/// 等待界面：点击扫描按钮开始扫描
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var disk = DiskUsage.current()

    var body: some View {
        let engine = ScanEngine.standard
        let active = engine.activeRules(for: ScanConfiguration(hasFullDiskAccess: model.hasFullDiskAccess))
        let activeIDs = Set(active.map(\.id))
        let skipped = engine.rules.filter { !activeIDs.contains($0.id) }

        VStack(spacing: 0) {
            Spacer(minLength: 12)

            VStack(spacing: 8) {
                Text("Orderly")
                    .font(.app(size: 34))
                Text("先扫描，再由你选择要清理的项目")
                    .foregroundStyle(.secondary)
            }

            ScanButton {
                model.startScan()
            }
            .padding(.vertical, 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("本次扫描范围")
                    .font(.app(.title3))
                HStack(spacing: 16) {
                    ForEach(ScanCategory.allCases) { category in
                        CategoryCard(
                            category: category,
                            activeTitles: active.filter { $0.category == category }.map(\.title),
                            skippedTitles: skipped.filter { $0.category == category }.map(\.title)
                        )
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 760)

            if let disk {
                DiskUsageBar(usage: disk)
                    .frame(maxWidth: 760)
                    .padding(.top, 16)
            }

            Spacer(minLength: 12)

            PermissionFooter()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .onAppear { disk = DiskUsage.current() }
    }
}

private struct ScanButton: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.scanButtonGradient)
                    .frame(width: 176, height: 176)
                    .shadow(color: Theme.gradientEnd.opacity(0.35), radius: isHovering ? 26 : 16, y: 10)

                VStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 36, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("开始扫描")
                        .font(.app(.title2))
                }
                .foregroundStyle(.white)
            }
            .scaleEffect(isHovering && !reduceMotion ? 1.03 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: isHovering)
    }
}

private struct CategoryCard: View {
    let category: ScanCategory
    let activeTitles: [String]
    let skippedTitles: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                SymbolTile(symbol: category.symbol, tint: Theme.color(for: category), size: 30)
                    .accessibilityHidden(true)
                Text(category.title)
                    .font(.app(.title3))
                if activeTitles.isEmpty {
                    Label("需授权", systemImage: "lock.fill")
                        .font(.app(.callout))
                        .foregroundStyle(.secondary)
                }
            }
            Text(activeTitles.isEmpty || category == .largeFile ? category.summary : activeTitles.joined(separator: "、"))
                .font(.app(.callout))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !activeTitles.isEmpty && !skippedTitles.isEmpty {
                Label("授权后可扫\(skippedTitles.joined(separator: "、"))", systemImage: "lock")
                    .font(.app(.callout))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct DiskUsageBar: View {
    let usage: DiskUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(usage.name, systemImage: "internaldrive")
                    .font(.app(.callout))
                Text("已用 \(usage.used.formattedBytes)（\(usage.fraction, format: .percent.precision(.fractionLength(0)))）")
                    .font(.app(.callout))
                Spacer()
                Text("可用 \(usage.available.formattedBytes)，共 \(usage.total.formattedBytes)")
                    .font(.app(.callout))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(Theme.heroGradient)
                        .frame(width: proxy.size.width * usage.fraction)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct PermissionFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.hasFullDiskAccess {
            Label {
                Text("已获得完全磁盘访问权限")
            } icon: {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            }
            .font(.app(.callout))
            .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 6) {
                Label("完全磁盘访问权限未开启", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                Button("去授权") { model.showPermission() }
                    .buttonStyle(.link)
            }
            .font(.app(.callout))
        }
    }
}
