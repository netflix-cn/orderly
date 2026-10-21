import SwiftUI

enum Theme {
    static let gradientStart = Color(red: 0.18, green: 0.80, blue: 0.66)
    static let gradientEnd = Color(red: 0.20, green: 0.48, blue: 0.96)

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [gradientStart, gradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func color(for category: ScanCategory) -> Color {
        switch category {
        case .junk: .orange
        case .cache: .blue
        case .largeFile: .purple
        }
    }

    static func tint(for kind: AppOwner.Kind) -> Color {
        switch kind {
        case .installed: .accentColor
        case .system: .gray
        case .leftover: .gray.opacity(0.6)
        case .other: .teal
        }
    }
}

extension Int64 {
    var formattedBytes: String {
        formatted(.byteCount(style: .file))
    }
}

/// 启动盘容量
struct DiskUsage {
    let name: String
    let total: Int64
    let available: Int64

    var used: Int64 { total - available }
    var fraction: Double { total == 0 ? 0 : Double(used) / Double(total) }

    static func current() -> DiskUsage? {
        let keys: Set<URLResourceKey> = [
            .volumeLocalizedNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let values = try? URL(filePath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage
        else {
            return nil
        }
        return DiskUsage(name: values.volumeLocalizedName ?? "Macintosh HD", total: Int64(total), available: available)
    }
}
