import Foundation

/// 某一天的农历信息
struct LunarDay: Equatable, Sendable {
    /// 农历月名，如「九月」
    let month: String
    /// 农历日名，如「廿四」
    let day: String
    /// 当天交节的节气，如「立冬」
    let solarTerm: String?
    /// 当天恰逢朔、上弦、望、下弦时的月相
    let moonPhase: MoonPhase?

    /// 初一 … 初十、十一 … 十九、二十、廿一 … 廿九、三十
    static func dayName(_ day: Int) -> String {
        let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        return switch day {
        case 1...10: "初" + digits[day]
        case 11...19: "十" + digits[day - 10]
        case 20: "二十"
        case 21...29: "廿" + digits[day - 20]
        case 30: "三十"
        default: ""
        }
    }
}

enum MoonPhase: Sendable {
    /// 朔
    case new
    /// 上弦
    case firstQuarter
    /// 望
    case full
    /// 下弦
    case lastQuarter
}

/// 干支纪年、纪月、纪日
struct GanZhi: Equatable, Sendable {
    let year: String
    /// 生肖
    let zodiac: String
    let month: String
    let day: String

    private static let stems = Array("甲乙丙丁戊己庚辛壬癸")
    private static let branches = Array("子丑寅卯辰巳午未申酉戌亥")

    /// 日干支按 60 天循环，与儒略日数直接对应
    static func day(of date: SolarDate) -> String {
        let index = (date.julianDay + 49) % 60
        return String([stems[index % 10], branches[index % 12]])
    }
}

/// 农历、节气、月相、干支的数据来源
protocol ChineseCalendarSource: Sendable {
    /// 超出数据范围时返回 nil
    func lunarDay(for date: SolarDate) -> LunarDay?
    /// 超出数据范围时返回 nil
    func ganZhi(for date: SolarDate) -> GanZhi?
}

/// 模拟数据：只覆盖农历 2026 年九月、十月（公历 2026-10-10 至 2026-12-08），
/// 够显示 2026-11-02 前后五周的日历。之后换成真实的农历、节气、月相算法。
struct MockChineseCalendar: ChineseCalendarSource {
    private static let months: [(name: String, firstDay: SolarDate, length: Int)] = [
        ("九月", SolarDate(year: 2026, month: 10, day: 10), 30),
        ("十月", SolarDate(year: 2026, month: 11, day: 9), 30),
    ]

    private static let solarTerms: [SolarDate: String] = [
        SolarDate(year: 2026, month: 10, day: 23): "霜降",
        SolarDate(year: 2026, month: 11, day: 7): "立冬",
        SolarDate(year: 2026, month: 11, day: 22): "小雪",
        SolarDate(year: 2026, month: 12, day: 7): "大雪",
    ]

    private static let moonPhases: [SolarDate: MoonPhase] = [
        SolarDate(year: 2026, month: 11, day: 2): .lastQuarter,
        SolarDate(year: 2026, month: 11, day: 9): .new,
        SolarDate(year: 2026, month: 11, day: 17): .firstQuarter,
        SolarDate(year: 2026, month: 11, day: 24): .full,
        SolarDate(year: 2026, month: 12, day: 1): .lastQuarter,
    ]

    /// 月干支从「节」开始换：寒露起戊戌月，立冬起己亥月，大雪起庚子月
    private static let ganZhiMonths: [(firstDay: SolarDate, name: String)] = [
        (SolarDate(year: 2026, month: 10, day: 8), "戊戌"),
        (SolarDate(year: 2026, month: 11, day: 7), "己亥"),
        (SolarDate(year: 2026, month: 12, day: 7), "庚子"),
    ]

    func lunarDay(for date: SolarDate) -> LunarDay? {
        for month in Self.months {
            let offset = date.julianDay - month.firstDay.julianDay
            if (0..<month.length).contains(offset) {
                return LunarDay(
                    month: month.name,
                    day: LunarDay.dayName(offset + 1),
                    solarTerm: Self.solarTerms[date],
                    moonPhase: Self.moonPhases[date]
                )
            }
        }
        return nil
    }

    func ganZhi(for date: SolarDate) -> GanZhi? {
        guard lunarDay(for: date) != nil,
              let month = Self.ganZhiMonths.last(where: { $0.firstDay <= date })
        else {
            return nil
        }
        return GanZhi(year: "丙午", zodiac: "马", month: month.name, day: GanZhi.day(of: date))
    }
}
