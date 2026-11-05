import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            switch model.phase {
            case .permission:
                PermissionView()
            case .ready:
                HomeView()
            case .scanning:
                ScanningView()
            case .results:
                if let results = model.results {
                    ResultsView(results: results)
                } else {
                    HomeView()
                }
            case .cleaning:
                CleaningView()
            case .finished:
                CleanSummaryView()
            }
        }
        .transition(.opacity)
        .frame(minWidth: 900, minHeight: 620)
        // 正文、按钮等默认使用思源宋体半粗
        .font(.app(.body))
        // 界面文案目前只有中文，日期等格式也统一使用中文；加入多语言后移除
        .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
        .animation(.easeInOut(duration: 0.25), value: model.phase)    }
}
