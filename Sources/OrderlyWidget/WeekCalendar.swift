import Foundation

/// 公历日期，不含时间与时区
struct SolarDate: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// 按公历取某一时刻在指定时区的日期（不受用户所选日历类型影响）
    init(_ date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year!, month: components.month!, day: components.day!)
    }

    init(julianDay: Int) {
        let a = julianDay + 32044
        let b = (4 * a + 3) / 146_097
        let c = a - 146_097 * b / 4
        let d = (4 * c + 3) / 1461
        let e = c - 1461 * d / 4
        let m = (5 * e + 2) / 153
        self.init(year: 100 * b + d - 4800 + m / 10, month: m + 3 - 12 * (m / 10), day: e - (153 * m + 2) / 5 + 1)
    }

    /// 儒略日数。日期间隔、星期、干支纪日都由它计算
    var julianDay: Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    /// 0 = 周日 … 6 = 周六
    var weekday: Int { (julianDay + 1) % 7 }

    var isWeekend: Bool { weekday == 0 || weekday == 6 }

    /// 当年第几天，1 月 1 日为第 1 天
    var dayOfYear: Int {
        julianDay - SolarDate(year: year, month: 1, day: 1).julianDay + 1
    }

    /// ISO 8601 周数：周一开始，含当年第一个周四的那周为第 1 周
    var weekOfYear: Int {
        let thursday = SolarDate(julianDay: julianDay - (julianDay % 7) + 3)
        return (thursday.dayOfYear - 1) / 7 + 1
    }

    /// 星座，按常用的公历日期划分
    var zodiacSign: String {
        let starts: [(month: Int, day: Int, name: String)] = [
            (1, 20, "水瓶"), (2, 19, "双鱼"), (3, 21, "白羊"), (4, 20, "金牛"), (5, 21, "双子"), (6, 22, "巨蟹"),
            (7, 23, "狮子"), (8, 23, "处女"), (9, 23, "天秤"), (10, 24, "天蝎"), (11, 23, "射手"), (12, 22, "摩羯"),
        ]
        return starts.last { (month, day) >= ($0.month, $0.day) }?.name ?? "摩羯"
    }

    static func < (lhs: SolarDate, rhs: SolarDate) -> Bool {
        lhs.julianDay < rhs.julianDay
    }
}

/// 日历中的一格
struct CalendarDay: Identifiable, Sendable {
    let date: SolarDate
    /// 是否与今天同月；否则是上月、下月的日期
    let isInMonth: Bool
    let isToday: Bool

    var id: Int { date.julianDay }
}

/// 以今天所在周为中心的 5 周日历：周日开头，依次为前两周、前一周、本周、后一周、后两周，本周固定在第 3 行
struct WeekCalendar: Sendable {
    /// 本周前后各显示的周数
    static let surroundingWeeks = 2

    let today: SolarDate
    let weeks: [[CalendarDay]]

    init(today: SolarDate) {
        self.today = today
        let start = today.julianDay - today.weekday - 7 * Self.surroundingWeeks
        weeks = (0..<(2 * Self.surroundingWeeks + 1)).map { row in
            (0..<7).map { column in
                let date = SolarDate(julianDay: start + row * 7 + column)
                return CalendarDay(date: date, isInMonth: date.month == today.month, isToday: date == today)
            }
        }
    }
}
