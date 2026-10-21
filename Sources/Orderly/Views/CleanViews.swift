import SwiftUI

struct CleaningView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let progress = model.cleanProgress

        VStack(spacing: 28) {
            Spacer(minLength: 0)

            ProgressRing(fraction: progress.fraction) {
                Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text("\(progress.completed) / \(progress.total)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("正在清理…")
                    .font(.title2.bold())
                Text(progress.currentPath)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 560)
            }

            Spacer(minLength: 0)
        }
        .padding(40)
    }
}

struct CleanSummaryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let report = model.cleanReport ?? CleanReport()
        let hasRemaining = !(model.results?.items.isEmpty ?? true)

        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Image(systemName: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(report.failures.isEmpty ? AnyShapeStyle(Theme.heroGradient) : AnyShapeStyle(.orange))
                .symbolEffect(.bounce, value: report.cleanedItemIDs.count)

            VStack(spacing: 8) {
                Text("清理完成")
                    .font(.largeTitle.bold())
                Text("已释放 \(report.freedBytes.formattedBytes)")
                    .font(.title2.monospacedDigit())
                if report.trashedBytes > 0 {
                    Text("另有 \(report.trashedBytes.formattedBytes) 已移到废纸篓，清空废纸篓后释放。")
                        .foregroundStyle(.secondary)
                }
            }

            if !report.failures.isEmpty {
                FailureList(failures: report.failures)
                    .frame(maxWidth: 560)
            }

            HStack(spacing: 12) {
                if hasRemaining {
                    Button("查看剩余项目") { model.returnToResults() }
                }
                Button("完成") { model.reset() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(40)
    }
}

private struct FailureList: View {
    let failures: [CleanReport.Failure]
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(failures) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.path)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(failure.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 180)
        } label: {
            Label("\(failures.count) 项未能完全清理", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
