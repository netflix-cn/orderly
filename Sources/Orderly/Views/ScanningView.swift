import SwiftUI

struct ScanningView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let progress = model.scanProgress

        VStack(spacing: 28) {
            Spacer(minLength: 0)

            ProgressRing(fraction: progress.fraction) {
                Text(progress.foundBytes.formattedBytes)
                    .font(.app(size: 30))
                    .contentTransition(.numericText())
                    .animation(.default, value: progress.foundBytes)
                Text("已发现")
                    .font(.app(.callout))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("正在扫描…")
                    .font(.app(.title2))
                Text(progress.currentPath.isEmpty ? "正在准备" : progress.currentPath)
                    .font(.app(.callout))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 560)
            }

            VStack(spacing: 0) {
                ForEach(ScanCategory.allCases) { category in
                    CategoryProgressRow(category: category, state: progress.state(of: category))
                    if category != ScanCategory.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 520)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button("停止扫描") {
                model.cancelScan()
            }
            .controlSize(.large)
            .keyboardShortcut(.cancelAction)

            Spacer(minLength: 0)
        }
        .padding(40)
    }
}

/// 环形进度，外圈附带一段持续旋转的高光表示仍在工作
struct ProgressRing<Content: View>: View {
    let fraction: Double
    @ViewBuilder let label: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(Theme.heroGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: fraction)
            TimelineView(.animation) { context in
                let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) * 180
                Circle()
                    .trim(from: 0, to: 0.12)
                    .stroke(Theme.gradientStart.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .padding(-14)
                    .rotationEffect(.degrees(angle))
            }
            VStack(spacing: 4, content: label)
        }
        .frame(width: 200, height: 200)
        .padding(14)
    }
}

private struct CategoryProgressRow: View {
    let category: ScanCategory
    let state: ScanProgress.CategoryState

    var body: some View {
        HStack(spacing: 12) {
            SymbolTile(symbol: category.symbol, tint: Theme.color(for: category), size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.app(.body))
                Text(statusText)
                    .font(.app(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if state.bytes > 0 {
                Text(state.bytes.formattedBytes)
                    .font(.app(.callout))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            statusIcon
                .frame(width: 20)
        }
        .padding(.vertical, 12)
    }

    private var statusText: String {
        switch state.status {
        case .pending: "等待中"
        case .running: "扫描中 · 已发现 \(state.itemCount) 项"
        case .done: "已完成 · \(state.itemCount) 项"
        case .skipped: "需要完全磁盘访问权限"
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state.status {
        case .pending:
            Image(systemName: "clock").foregroundStyle(.tertiary)
        case .running:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .skipped:
            Image(systemName: "lock.fill").foregroundStyle(.tertiary)
        }
    }
}
