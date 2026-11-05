import SwiftUI

/// 大号日历小组件（344 × 344pt）
struct CalendarWidgetView: View {
    let today: SolarDate
    var source: any ChineseCalendarSource = BundledChineseCalendar.shared

    var body: some View {
        VStack(spacing: 0) {
            header
                // 思源宋体的行高约为字号的 1.44 倍，居中放会把月份压到星期行上；改为把基线固定在头部内的同一位置
                .alignmentGuide(.top) { $0[.lastTextBaseline] - Metrics.headerBaseline }
                .frame(height: Metrics.headerHeight, alignment: .top)
            weekdayRow
                .frame(height: Metrics.weekdayRowHeight)
            DayGrid(weeks: WeekCalendar(today: today).weeks, source: source)
        }
        .padding(.top, Metrics.topPadding)
        .padding(.bottom, Metrics.bottomPadding)
        .font(.app(size: 11))
    }

    private var header: some View {
        // 月份、农历行、干支行落在同一条基线上
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            // 数字与汉字同一字体，按基线对齐即可
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(verbatim: "\(today.month)")
                    .font(.app(size: 39))
                Text(verbatim: "月")
                    .font(.app(size: 35))
            }
            .foregroundStyle(CalendarStyle.text)
            .fixedSize()
            // 收紧两行的行距，让日期行顶端与月份数字顶端齐平
            VStack(alignment: .leading, spacing: Metrics.dateLineSpacing) {
                // 不用 Text 插值拼接：小组件里插值进来的 Text 不会显示
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(verbatim: "\(today.day)")
                        .font(.app(size: 19))
                    Text(verbatim: "日")
                        .font(.app(size: 17))
                    // 竖线底边与数字基线对齐
                    Rectangle()
                        .fill(CalendarStyle.separator)
                        .frame(width: 1, height: 10)
                        .padding(.leading, 3)
                        .padding(.trailing, 4.5)
                    Text(verbatim: "\(today.year)")
                        .font(.app(size: 19))
                }
                if let lunar = source.lunarDay(for: today) {
                    Text(verbatim: "农历\(lunar.month)\(lunar.day)")
                        .font(.app(size: 12.5))
                }
            }
            .foregroundStyle(CalendarStyle.text)
            .padding(.leading, 4)
            .fixedSize()
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: Metrics.infoLineSpacing) {
                Text(verbatim: "第\(today.dayOfYear)天·第\(today.weekOfYear)周 \(today.zodiacSign)月")
                if let ganZhi = source.ganZhi(for: today) {
                    Text(verbatim: "\(ganZhi.year)·\(ganZhi.zodiac)年 \(ganZhi.month)月 \(ganZhi.day)日")
                }
            }
            .font(.app(size: 11))
            .foregroundStyle(CalendarStyle.secondaryText)
            // 仍放不下时整体缩小，不截断成省略号
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.leading, Metrics.headerInset)
        .padding(.trailing, Metrics.headerTrailingInset)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(["周日", "周一", "周二", "周三", "周四", "周五", "周六"].enumerated()), id: \.offset) { index, name in
                Text(verbatim: name)
                    .font(.app(size: 10.5))
                    .foregroundStyle(index == 0 || index == 6 ? CalendarStyle.weekendLabel : CalendarStyle.secondaryText)
                    .frame(maxWidth: .infinity)
                    .offset(y: -0.75)
            }
        }
        .padding(.horizontal, Metrics.gridInset)
    }
}

private struct DayGrid: View {
    let weeks: [[CalendarDay]]
    let source: any ChineseCalendarSource

    var body: some View {
        GeometryReader { proxy in
            let rowHeight = proxy.size.height / CGFloat(weeks.count)
            VStack(spacing: 0) {
                ForEach(weeks.indices, id: \.self) { row in
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(CalendarStyle.separator)
                            .frame(height: 0.5)
                            .padding(.horizontal, Metrics.separatorInset - Metrics.gridInset)
                        HStack(spacing: 0) {
                            ForEach(weeks[row]) { day in
                                DayCell(day: day, lunar: source.lunarDay(for: day.date), rowHeight: rowHeight)
                            }
                        }
                    }
                    .frame(height: rowHeight)
                }
            }
        }
        .padding(.horizontal, Metrics.gridInset)
    }
}

private struct DayCell: View {
    let day: CalendarDay
    let lunar: LunarDay?
    let rowHeight: CGFloat

    var body: some View {
        // 位置按参考图的行高标定；实际行高不同时按比例缩放
        let scale = rowHeight / Metrics.referenceRowHeight
        ZStack(alignment: .top) {
            number
                .offset(y: Metrics.numberCenter * scale - Metrics.todaySize.height / 2)
            lunarLine
                .frame(height: Metrics.termSize.height)
                .offset(y: Metrics.lunarCenter * scale - Metrics.termSize.height / 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var number: some View {
        Text(verbatim: "\(day.date.day)")
            .font(.app(size: 20))
            .foregroundStyle(day.isToday ? .white : day.date.isWeekend ? CalendarStyle.weekendText : CalendarStyle.text)
            .frame(width: Metrics.todaySize.width, height: Metrics.todaySize.height)
            .background {
                if day.isToday {
                    Capsule(style: .continuous).fill(CalendarStyle.today)
                }
            }
    }

    @ViewBuilder
    private var lunarLine: some View {
        if let lunar {
            Group {
                if let term = lunar.solarTerm {
                    Text(verbatim: term)
                        .foregroundStyle(.white)
                        .frame(width: Metrics.termSize.width, height: Metrics.termSize.height)
                        .background(RoundedRectangle(cornerRadius: 4.5, style: .circular).fill(CalendarStyle.solarTerm))
                } else {
                    HStack(spacing: 3) {
                        if let phase = lunar.moonPhase {
                            MoonPhaseIcon(phase: phase)
                        }
                        Text(verbatim: lunar.day)
                            .foregroundStyle(CalendarStyle.text)
                    }
                }
            }
            .font(.app(size: 11))
        }
    }
}

private struct MoonPhaseIcon: View {
    let phase: MoonPhase

    var body: some View {
        ZStack {
            if phase != .full {
                Circle().strokeBorder(CalendarStyle.moonOutline, lineWidth: 0.75)
            }
            switch phase {
            case .new:
                EmptyView()
            case .firstQuarter:
                litHalf.rotationEffect(.degrees(180))
            case .full:
                Circle().fill(CalendarStyle.moon)
            case .lastQuarter:
                litHalf
            }
        }
        .frame(width: 11, height: 11)
        .offset(y: -0.75)
    }

    /// 左半边亮（下弦月）；上弦月转 180°
    private var litHalf: some View {
        Circle().trim(from: 0.25, to: 0.75).fill(CalendarStyle.moon)
    }
}

/// 尺寸取自参考图（单位 pt）
private enum Metrics {
    static let headerHeight: CGFloat = 46.5
    /// 月份、农历行、干支行的基线到头部顶端的距离
    static let headerBaseline: CGFloat = 34
    /// 日期行与农历行、右侧两行之间的间距；思源宋体行高较大，取负值收紧
    static let dateLineSpacing: CGFloat = -5.3
    static let infoLineSpacing: CGFloat = -1.5
    static let headerInset: CGFloat = 20
    static let headerTrailingInset: CGFloat = 17.5
    static let weekdayRowHeight: CGFloat = 21.5
    static let gridInset: CGFloat = 7.5
    static let separatorInset: CGFloat = 17.5
    /// 让月份离上边框与最后一行农历离下边框的距离相同（约 14.5pt），空间从日期区的行高里匀出
    static let topPadding: CGFloat = 9
    static let bottomPadding: CGFloat = 8
    /// 参考图的行高（无上边距时为 53.6pt），以及日期、农历中心到行顶分隔线的距离
    static let referenceRowHeight: CGFloat = 53.6
    static let numberCenter: CGFloat = 20.25
    static let lunarCenter: CGFloat = 41.75
    static let todaySize = CGSize(width: 40, height: 26)
    static let termSize = CGSize(width: 28, height: 15)
}

enum CalendarStyle {
    static let background = Color(rgb: 0x292929)
    static let text = Color(rgb: 0xFFF9E8)
    static let secondaryText = Color(rgb: 0x9B978E)
    static let weekendLabel = Color(rgb: 0x9C8B68)
    static let weekendText = Color(rgb: 0xFFE199)
    static let separator = Color(rgb: 0x444444)
    static let today = Color(rgb: 0x3794E3)
    static let solarTerm = Color(rgb: 0x73B34A)
    static let moon = Color(rgb: 0xFBCA06)
    static let moonOutline = Color(rgb: 0xA6BFDF)
}

private extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double(rgb >> 16 & 0xFF) / 255,
            green: Double(rgb >> 8 & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

private extension Font {
    /// 思源宋体半粗；小组件进程启动时由 BundledFont 注册，否则会退回系统字体
    static func app(size: CGFloat) -> Font {
        .custom(BundledFont.name, size: size)
    }
}
