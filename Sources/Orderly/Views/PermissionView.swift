import Combine
import SwiftUI

/// 启动后的授权页：引导用户开启「完全磁盘访问权限」
struct PermissionView: View {
    @Environment(AppModel.self) private var model
    @State private var hasOpenedSettings = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Theme.heroGradient.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "lock.shield")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(Theme.heroGradient)
            }

            VStack(spacing: 10) {
                Text("需要「完全磁盘访问权限」")
                    .font(.app(.largeTitle))
                Text("Orderly 需要读取各个 App 的缓存、日志和容器目录，才能完整找出可清理的文件。\n所有扫描都在本机完成，不会上传任何数据。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 14) {
                StepRow(number: 1, text: "点击「打开系统设置」，进入「隐私与安全性 › 完全磁盘访问权限」")
                StepRow(number: 2, text: "找到 Orderly 并打开开关；如果列表中没有，点击「+」添加，或把 Orderly 拖入列表")
                StepRow(number: 3, text: "回到 Orderly，授权成功后会自动进入下一步")
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 12) {
                Button {
                    FullDiskAccess.openSystemSettings()
                    hasOpenedSettings = true
                } label: {
                    Label("打开系统设置", systemImage: "gearshape")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                Button("在 Finder 中显示 Orderly") {
                    FullDiskAccess.revealAppInFinder()
                }
            }
            .controlSize(.large)

            if hasOpenedSettings {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在等待授权，授权后将自动继续。")
                        .foregroundStyle(.secondary)
                    Button("已授权但未生效？重新启动 Orderly") {
                        FullDiskAccess.relaunch()
                    }
                    .buttonStyle(.link)
                }
                .font(.app(.callout))
                .transition(.opacity)
            }

            Spacer(minLength: 0)

            Button("暂不授权，仅扫描部分位置") {
                model.skipPermission()
            }
            .buttonStyle(.link)
            .font(.app(.callout))
        }
        .padding(40)
        .animation(.default, value: hasOpenedSettings)
        .task {
            // 系统不会通知授权变化，只能轮询
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                model.refreshPermission()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshPermission()
        }
    }
}

private struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.app(.callout))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Theme.heroGradient, in: Circle())
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
