import Foundation
import os

/// 某一天的农历信息
struct LunarDay: Equatable, Sendable {
    /// 农历月名，如「九月」「冬月」「闰六月」
    let month: String
    /// 农历日名，如「廿四」
    let day: String
    /// 当天交节的节气，如「立冬」
    let solarTerm: String?
    /// 当天恰逢朔、上弦、望、下弦时的月相
    let moonPhase: MoonPhase?
}

/// 原始值与数据文件中的写法一致
enum MoonPhase: String, Decodable, Sendable {
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
}

/// 农历、节气、月相、干支的数据来源
protocol ChineseCalendarSource: Sendable {
    /// 超出数据范围时返回 nil
    func lunarDay(for date: SolarDate) -> LunarDay?
    /// 超出数据范围时返回 nil
    func ganZhi(for date: SolarDate) -> GanZhi?
}

/// 离线农历数据：Resources/Calendar/chinese-calendar.json，打包时复制进扩展。
/// 由 Scripts/generate-chinese-calendar.swift 按天文算法生成，覆盖公历 2026-01-01 至 2027-12-31；
/// 干支纪年以立春为界，纪月以「节」为界
struct BundledChineseCalendar: ChineseCalendarSource {
    /// 数据文件中的一天，字段与文件一致
    struct Day: Decodable, Sendable {
        let date: String
        /// 以正月初一为界的农历年干支
        let lunarYear: String
        let lunarMonth: Int
        let isLeapMonth: Bool
        let lunarMonthName: String
        let lunarMonthDays: Int
        let lunarDay: Int
        let lunarDayName: String
        let ganZhiYear: String
        let ganZhiMonth: String
        let ganZhiDay: String
        let zodiac: String
        let solarTerm: String?
        let moonPhase: MoonPhase?
    }

    private struct File: Decodable {
        let days: [Day]
    }

    /// 扩展包内的数据。读取失败时为空，小组件不显示农历行和干支行
    static let shared: BundledChineseCalendar = {
        let logger = Logger(subsystem: "com.orderly.Orderly.Widget", category: "calendar")
        guard let url = Bundle.main.url(forResource: "chinese-calendar", withExtension: "json", subdirectory: "Calendar") else {
            logger.error("扩展包内没有农历数据")
            return BundledChineseCalendar(days: [:])
        }
        do {
            return try BundledChineseCalendar(data: Data(contentsOf: url))
        } catch {
            logger.error("农历数据读取失败：\(error.localizedDescription, privacy: .public)")
            return BundledChineseCalendar(days: [:])
        }
    }()

    let days: [SolarDate: Day]

    private init(days: [SolarDate: Day]) {
        self.days = days
    }

    init(data: Data) throws {
        let file = try JSONDecoder().decode(File.self, from: data)
        var days: [SolarDate: Day] = [:]
        for day in file.days {
            let parts = day.date.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "日期格式不正确：\(day.date)"))
            }
            days[SolarDate(year: parts[0], month: parts[1], day: parts[2])] = day
        }
        self.days = days
    }

    func lunarDay(for date: SolarDate) -> LunarDay? {
        days[date].map { LunarDay(month: $0.lunarMonthName, day: $0.lunarDayName, solarTerm: $0.solarTerm, moonPhase: $0.moonPhase) }
    }

    func ganZhi(for date: SolarDate) -> GanZhi? {
        days[date].map { GanZhi(year: $0.ganZhiYear, zodiac: $0.zodiac, month: $0.ganZhiMonth, day: $0.ganZhiDay) }
    }
}
