import SwiftUI

/// 支持「部分选中」状态的勾选框
struct CheckBox: View {
    let state: CheckState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(state == .off ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state == .off ? "未选中" : state == .on ? "已选中" : "部分选中")
    }

    private var symbol: String {
        switch state {
        case .on: "checkmark.square.fill"
        case .off: "square"
        case .mixed: "minus.square.fill"
        }
    }
}

/// 圆角色块 + SF Symbol 图标
struct SymbolTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// App 图标；没有对应 App 时显示类型图标
struct OwnerIcon: View {
    let owner: AppOwner
    var size: CGFloat = 28

    var body: some View {
        if let appURL = owner.appURL {
            Image(nsImage: IconCache.shared.icon(for: appURL))
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            SymbolTile(symbol: owner.symbol, tint: Theme.tint(for: owner.kind), size: size * 0.86)
                .frame(width: size, height: size)
        }
    }
}

struct GroupIcon: View {
    let header: ScanResultsModel.Group.Header
    var size: CGFloat = 28

    var body: some View {
        switch header {
        case let .app(owner):
            OwnerIcon(owner: owner, size: size)
        case let .category(category):
            SymbolTile(symbol: category.symbol, tint: Theme.color(for: category), size: size * 0.86)
                .frame(width: size, height: size)
        }
    }
}

/// 小号胶囊标签
struct TagLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
}

@MainActor
final class IconCache {
    static let shared = IconCache()
    private var icons: [URL: NSImage] = [:]

    func icon(for url: URL) -> NSImage {
        if let icon = icons[url] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[url] = icon
        return icon
    }
}
