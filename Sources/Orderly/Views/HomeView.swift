import SwiftUI

/// 等待界面：点击扫描按钮开始扫描
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var disk = DiskUsage.current()

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 8) {
                Text("Orderly")
                    .font(.app(size: 34))
                Text("让你的 Mac 保持井井有条")
                    .foregroundStyle(.secondary)
            }

            ScanButton {
                model.startScan()
            }
            .padding(.vertical, 36)

            HStack(spacing: 16) {
                ForEach(ScanCategory.allCases) { category in
                    CategoryCard(category: category)
                }
            }
            .frame(maxWidth: 760)

            if let disk {
                DiskUsageBar(usage: disk)
                    .frame(maxWidth: 760)
                    .padding(.top, 16)
            }

            Spacer(minLength: 24)

            PermissionFooter()
        }
        .padding(32)
        .onAppear { disk = DiskUsage.current() }
    }
}

private struct ScanButton: View {
    let action: () -> Void
    @State private var isHovering = false
    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Theme.heroGradient, lineWidth: 6)
                    .frame(width: 176, height: 176)
                    .scaleEffect(isPulsing ? 1.22 : 1)
                    .opacity(isPulsing ? 0 : 0.5)

                Circle()
                    .fill(Theme.heroGradient)
                    .frame(width: 176, height: 176)
                    .shadow(color: Theme.gradientEnd.opacity(0.35), radius: isHovering ? 26 : 16, y: 10)

                VStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 36, weight: .semibold))
                    Text("开始扫描")
                        .font(.app(.title2))
                }
                .foregroundStyle(.white)
            }
            .scaleEffect(isHovering ? 1.03 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
        .onHover { isHovering = $0 }
        .animation(.spring(duration: 0.3), value: isHovering)
        .onAppear {
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

private struct CategoryCard: View {
    let category: ScanCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SymbolTile(symbol: category.symbol, tint: Theme.color(for: category), size: 34)
            Text(category.title)
                .font(.app(.title3))
            Text(category.summary)
                .font(.app(.callout))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DiskUsageBar: View {
    let usage: DiskUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(usage.name, systemImage: "internaldrive")
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
    }
}

private struct PermissionFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.hasFullDiskAccess {
            Label("已获得完全磁盘访问权限", systemImage: "checkmark.shield.fill")
                .font(.app(.callout))
                .foregroundStyle(.green)
        } else {
            HStack(spacing: 6) {
                Label("未获得完全磁盘访问权限，部分位置不会被扫描", systemImage: "exclamationmark.shield.fill")
                    .foregroundStyle(.orange)
                Button("去授权") { model.showPermission() }
                    .buttonStyle(.link)
            }
            .font(.app(.callout))
        }
    }
}
