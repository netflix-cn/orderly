import SwiftUI
import WidgetKit

struct CalendarEntry: TimelineEntry {
    let date: Date
}

struct CalendarTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (CalendarEntry) -> Void) {
        completion(CalendarEntry(date: .now))
    }

    /// 内容只在零点变化：一次给出现在和之后 7 个零点，用完后系统再来请求
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<CalendarEntry>) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let midnights = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = [CalendarEntry(date: .now)] + midnights.map(CalendarEntry.init)
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.orderly.Orderly.Widget.Calendar", provider: CalendarTimelineProvider()) { entry in
            CalendarWidgetView(today: SolarDate(entry.date))
                .containerBackground(CalendarStyle.background, for: .widget)
        }
        .configurationDisplayName("日历")
        .description("前后五周日历、农历与干支纪年")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}
