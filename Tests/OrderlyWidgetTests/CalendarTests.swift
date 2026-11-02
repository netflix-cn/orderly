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
        #expect(calendar.weeks[1].allSatisfy { !$0.isInMonth })
        #expect(calendar.weeks[2...].joined().allSatisfy { $0.isInMonth })
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
        #expect(calendar.weeks[2].map(\.isInMonth) == [true, true, true, true, true, false, false])
        #expect(calendar.weeks[4][6].date == SolarDate(year: 2027, month: 1, day: 16))
    }
}

struct ChineseCalendarTests {
    @Test(arguments: [(1, "初一"), (10, "初十"), (11, "十一"), (20, "二十"), (21, "廿一"), (30, "三十")])
    func lunarDayNames(_ day: Int, _ name: String) {
        #expect(LunarDay.dayName(day) == name)
    }

    @Test func dayGanZhi() {
        #expect(GanZhi.day(of: SolarDate(year: 2000, month: 1, day: 1)) == "戊午")
        #expect(GanZhi.day(of: SolarDate(year: 2026, month: 11, day: 2)) == "庚辰")
    }

    @Test func mockMatchesReference() {
        let source = MockChineseCalendar()
        let today = source.lunarDay(for: SolarDate(year: 2026, month: 11, day: 2))
        #expect(today == LunarDay(month: "九月", day: "廿四", solarTerm: nil, moonPhase: .lastQuarter))
        #expect(source.lunarDay(for: SolarDate(year: 2026, month: 11, day: 7))?.solarTerm == "立冬")
        #expect(source.lunarDay(for: SolarDate(year: 2026, month: 11, day: 8))?.day == "三十")
        #expect(source.lunarDay(for: SolarDate(year: 2026, month: 11, day: 9))?.month == "十月")
        #expect(source.lunarDay(for: SolarDate(year: 2026, month: 12, day: 5))?.day == "廿七")
        #expect(source.ganZhi(for: SolarDate(year: 2026, month: 11, day: 2)) == GanZhi(year: "丙午", zodiac: "马", month: "戊戌", day: "庚辰"))
        #expect(source.ganZhi(for: SolarDate(year: 2026, month: 11, day: 7))?.month == "己亥")
    }

    @Test func mockReturnsNilOutsideRange() {
        let source = MockChineseCalendar()
        #expect(source.lunarDay(for: SolarDate(year: 2026, month: 10, day: 9)) == nil)
        #expect(source.lunarDay(for: SolarDate(year: 2026, month: 12, day: 9)) == nil)
        #expect(source.ganZhi(for: SolarDate(year: 2026, month: 12, day: 9)) == nil)
    }
}
