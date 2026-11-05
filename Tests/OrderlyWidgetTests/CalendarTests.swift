import Foundation
import Testing
@testable import OrderlyWidget

struct SolarDateTests {
    @Test func julianDayRoundTrips() {
        let date = SolarDate(year: 2026, month: 11, day: 2)
        #expect(date.julianDay == 2_461_347)
        #expect(SolarDate(julianDay: date.julianDay) == date)
        #expect(SolarDate(julianDay: SolarDate(year: 2024, month: 2, day: 29).julianDay + 1) == SolarDate(year: 2024, month: 3, day: 1))
    }

    @Test func weekdayStartsOnSunday() {
        #expect(SolarDate(year: 2026, month: 11, day: 1).weekday == 0)
        #expect(SolarDate(year: 2026, month: 11, day: 2).weekday == 1)
        #expect(SolarDate(year: 2026, month: 11, day: 7).isWeekend)
    }

    @Test func headerNumbersMatchReference() {
        let date = SolarDate(year: 2026, month: 11, day: 2)
        #expect(date.dayOfYear == 306)
        #expect(date.weekOfYear == 45)
        #expect(date.zodiacSign == "天蝎")
    }

    @Test(arguments: [
        (SolarDate(year: 2026, month: 12, day: 31), 53),
        (SolarDate(year: 2027, month: 1, day: 3), 53),
        (SolarDate(year: 2027, month: 1, day: 4), 1),
        (SolarDate(year: 2024, month: 12, day: 30), 1),
    ])
    func isoWeekAcrossYearBoundary(_ date: SolarDate, _ week: Int) {
        #expect(date.weekOfYear == week)
    }

    @Test(arguments: [
        (SolarDate(year: 2026, month: 11, day: 22), "天蝎"),
        (SolarDate(year: 2026, month: 11, day: 23), "射手"),
        (SolarDate(year: 2026, month: 12, day: 22), "摩羯"),
        (SolarDate(year: 2027, month: 1, day: 19), "摩羯"),
        (SolarDate(year: 2027, month: 1, day: 20), "水瓶"),
    ])
    func zodiacBoundaries(_ date: SolarDate, _ sign: String) {
        #expect(date.zodiacSign == sign)
    }
}

struct WeekCalendarTests {
    @Test func currentWeekIsThirdRow() {
        let calendar = WeekCalendar(today: SolarDate(year: 2026, month: 11, day: 2))
        #expect(calendar.weeks.count == 5)
        #expect(calendar.weeks.allSatisfy { $0.count == 7 })
        #expect(calendar.weeks[0][0].date == SolarDate(year: 2026, month: 10, day: 18))
        #expect(calendar.weeks[2][0].date == SolarDate(year: 2026, month: 11, day: 1))
        #expect(calendar.weeks[4][6].date == SolarDate(year: 2026, month: 11, day: 21))
        #expect(calendar.weeks[2][1].isToday)
        #expect(calendar.weeks.joined().filter(\.isToday).count == 1)
    }

    // 周日、周六、月末、跨年、闰日：本周都在第 3 行，今天在对应星期的那一列
    @Test(arguments: [
        SolarDate(year: 2026, month: 11, day: 1),
        SolarDate(year: 2026, month: 11, day: 7),
        SolarDate(year: 2026, month: 11, day: 30),
        SolarDate(year: 2027, month: 1, day: 1),
        SolarDate(year: 2028, month: 2, day: 29),
    ])
    func todayAlwaysInThirdRow(_ today: SolarDate) {
        let calendar = WeekCalendar(today: today)
        #expect(calendar.weeks.count == 5)
        #expect(calendar.weeks[2][today.weekday].isToday)
        #expect(calendar.weeks[2][today.weekday].date == today)
        #expect(calendar.weeks.joined().filter(\.isToday).count == 1)
        let days = calendar.weeks.joined().map(\.date.julianDay)
        #expect(days == Array(days[0]..<(days[0] + 35)))
    }

    @Test func spansYearBoundary() {
        let calendar = WeekCalendar(today: SolarDate(year: 2026, month: 12, day: 31))
        #expect(calendar.weeks[0][0].date == SolarDate(year: 2026, month: 12, day: 13))
        #expect(calendar.weeks[2].map(\.date.day) == [27, 28, 29, 30, 31, 1, 2])
        #expect(calendar.weeks[4][6].date == SolarDate(year: 2027, month: 1, day: 16))
    }
}

struct ChineseCalendarTests {
    /// 测试进程的 Bundle.main 里没有数据文件，直接读仓库里的
    let calendar: BundledChineseCalendar

    init() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        calendar = try BundledChineseCalendar(data: Data(contentsOf: root.appending(path: "Resources/Calendar/chinese-calendar.json")))
    }

    private var sortedDays: [(date: SolarDate, day: BundledChineseCalendar.Day)] {
        calendar.days.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    @Test func coversEveryDayOf2026And2027() {
        let first = SolarDate(year: 2026, month: 1, day: 1).julianDay
        let last = SolarDate(year: 2027, month: 12, day: 31).julianDay
        #expect(sortedDays.map(\.date.julianDay) == Array(first...last))
        #expect(calendar.lunarDay(for: SolarDate(year: 2025, month: 12, day: 31)) == nil)
        #expect(calendar.ganZhi(for: SolarDate(year: 2028, month: 1, day: 1)) == nil)
    }

    // 参考图（2026-11-02）上的农历、节气、月相、干支
    @Test func matchesReference() {
        #expect(calendar.lunarDay(for: SolarDate(year: 2026, month: 11, day: 2))
            == LunarDay(month: "九月", day: "廿四", solarTerm: nil, moonPhase: .lastQuarter))
        #expect(calendar.ganZhi(for: SolarDate(year: 2026, month: 11, day: 2))
            == GanZhi(year: "丙午", zodiac: "马", month: "戊戌", day: "庚辰"))
        #expect(calendar.lunarDay(for: SolarDate(year: 2026, month: 10, day: 10))?.day == "初一")
        #expect(calendar.lunarDay(for: SolarDate(year: 2026, month: 10, day: 23))?.solarTerm == "霜降")
        #expect(calendar.lunarDay(for: SolarDate(year: 2026, month: 11, day: 7))?.solarTerm == "立冬")
        #expect(calendar.ganZhi(for: SolarDate(year: 2026, month: 11, day: 7))?.month == "己亥")
        #expect(calendar.lunarDay(for: SolarDate(year: 2026, month: 11, day: 8))?.day == "三十")
        #expect(calendar.lunarDay(for: SolarDate(year: 2026, month: 11, day: 9))
            == LunarDay(month: "十月", day: "初一", solarTerm: nil, moonPhase: .new))
        #expect(calendar.lunarDay(for: SolarDate(year: 2026, month: 11, day: 17))?.moonPhase == .firstQuarter)
        #expect(calendar.lunarDay(for: SolarDate(year: 2026, month: 11, day: 24))?.moonPhase == .full)
        #expect(calendar.lunarDay(for: SolarDate(year: 2026, month: 12, day: 1))?.moonPhase == .lastQuarter)
        #expect(calendar.ganZhi(for: SolarDate(year: 2026, month: 12, day: 7))?.month == "庚子")
    }

    // 农历年从正月初一换，干支纪年和生肖从立春换
    @Test func yearBoundaries() throws {
        let beforeSpring = try #require(calendar.days[SolarDate(year: 2026, month: 2, day: 3)])
        let beginningOfSpring = try #require(calendar.days[SolarDate(year: 2026, month: 2, day: 4)])
        let newYearsEve = try #require(calendar.days[SolarDate(year: 2026, month: 2, day: 16)])
        let newYear = try #require(calendar.days[SolarDate(year: 2026, month: 2, day: 17)])
        #expect((beforeSpring.ganZhiYear, beforeSpring.zodiac, beforeSpring.ganZhiMonth) == ("乙巳", "蛇", "己丑"))
        #expect((beginningOfSpring.solarTerm, beginningOfSpring.ganZhiYear, beginningOfSpring.zodiac, beginningOfSpring.ganZhiMonth)
            == ("立春", "丙午", "马", "庚寅"))
        #expect((newYearsEve.lunarYear, newYearsEve.lunarMonthName, newYearsEve.lunarDayName) == ("乙巳", "腊月", "廿九"))
        #expect((newYear.lunarYear, newYear.lunarMonthName, newYear.lunarDayName) == ("丙午", "正月", "初一"))
        let nextNewYear = try #require(calendar.days[SolarDate(year: 2027, month: 2, day: 6)])
        #expect((nextNewYear.lunarYear, nextNewYear.lunarMonth, nextNewYear.lunarDay, nextNewYear.zodiac) == ("丁未", 1, 1, "羊"))
    }

    /// 与系统的农历（ICU 实现）逐日比对月、日、闰月
    @Test func matchesFoundationChineseCalendar() throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = timeZone
        let mismatches = sortedDays.filter { date, day in
            let noon = gregorian.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: 12))!
            let expected = chinese.dateComponents([.month, .day], from: noon)
            return expected.month != day.lunarMonth || expected.day != day.lunarDay || expected.isLeapMonth != day.isLeapMonth
        }
        #expect(mismatches.map(\.day.date) == [])
    }

    @Test(arguments: [2026, 2027])
    func twentyFourSolarTermsInOrder(_ year: Int) {
        let terms = sortedDays.filter { $0.date.year == year }.compactMap(\.day.solarTerm)
        #expect(terms == [
            "小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
            "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至",
        ])
    }

    @Test func lunarDaysAndGanZhiDaysAdvanceDaily() {
        let stems = Array("甲乙丙丁戊己庚辛壬癸")
        let branches = Array("子丑寅卯辰巳午未申酉戌亥")
        let cycle = (0..<60).map { String([stems[$0 % 10], branches[$0 % 12]]) }
        for (previous, next) in zip(sortedDays, sortedDays.dropFirst()) {
            let index = cycle.firstIndex(of: previous.day.ganZhiDay) ?? -1
            #expect(next.day.ganZhiDay == cycle[(index + 1) % 60], "\(next.day.date)")
            if next.day.lunarDay == 1 {
                #expect(previous.day.lunarDay == previous.day.lunarMonthDays, "\(previous.day.date)")
            } else {
                #expect(next.day.lunarDay == previous.day.lunarDay + 1, "\(next.day.date)")
            }
        }
    }

    @Test func moonPhasesCycleInOrder() {
        let phases = sortedDays.compactMap(\.day.moonPhase)
        let order: [MoonPhase] = [.new, .firstQuarter, .full, .lastQuarter]
        let start = order.firstIndex(of: phases[0]) ?? 0
        #expect(phases == phases.indices.map { order[(start + $0) % 4] })
        // 朔日即初一
        #expect(sortedDays.filter { $0.day.moonPhase == .new }.allSatisfy { $0.day.lunarDay == 1 })
    }
}
