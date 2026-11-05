// 生成小组件离线使用的农历数据：每个公历日的农历月日、干支、节气、月相。
//
// 用法：
//   Scripts/swift.sh Scripts/generate-chinese-calendar.swift 2026-01-01 2027-12-31 Resources/Calendar/chinese-calendar.json
//
// 算法（时刻先按力学时计算，减去 ΔT 得世界时，再加 8 小时得北京时间）：
// - 节气：太阳视黄经每 15° 一个。视黄经由 VSOP87 地球日心坐标截断项（Meeus《天文算法》附录 III）
//   加 FK5 修正、章动、光行差得到，误差约 1 角秒，相当于节气时刻差半分钟左右
// - 朔、上弦、望、下弦：Meeus《天文算法》第 49 章，误差在 1 分钟以内
// - 农历编排按 GB/T 33661-2017《农历的编算和颁行》：朔所在的北京时间日期为初一；含冬至的月为十一月；
//   两个十一月之间有 13 个月时，其中第一个不含中气的月为闰月，月名沿用上一个月
// - 干支纪年以立春为界，干支纪月以「节」为界（立春起寅月、惊蛰起卯月……），干支纪日按 60 日循环；
//   生肖随干支纪年。农历年（lunarYear）以正月初一为界
//
// 星座、当年第几天、第几周由 SolarDate 直接计算，不在这里生成。
// 朔和节气离北京时间零点不足 10 分钟时打印到标准错误：日期可能因算法误差差一天，需要人工核对。

import Foundation

// MARK: - 参数

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 3,
      let firstDay = parseDate(arguments[0]),
      let lastDay = parseDate(arguments[1]),
      firstDay <= lastDay
else {
    FileHandle.standardError.write(Data("用法：generate-chinese-calendar.swift <起始日期> <结束日期> <输出 JSON>，日期格式 2026-01-01\n".utf8))
    exit(2)
}
let outputURL = URL(filePath: arguments[2])

/// 力学时与世界时之差（秒）。2026–2027 年约 69 秒；生成其他年份时按 IERS 公布值调整
let deltaTSeconds = 69.0

// MARK: - 日期

func julianDayNumber(year: Int, month: Int, day: Int) -> Int {
    let a = (14 - month) / 12
    let y = year + 4800 - a
    let m = month + 12 * a - 3
    return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
}

func civilDate(_ jdn: Int) -> (year: Int, month: Int, day: Int) {
    let a = jdn + 32044
    let b = (4 * a + 3) / 146_097
    let c = a - 146_097 * b / 4
    let d = (4 * c + 3) / 1461
    let e = c - 1461 * d / 4
    let m = (5 * e + 2) / 153
    return (100 * b + d - 4800 + m / 10, m + 3 - 12 * (m / 10), e - (153 * m + 2) / 5 + 1)
}

/// 「2026-01-01」→ 儒略日数
func parseDate(_ text: String) -> Int? {
    let parts = text.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return julianDayNumber(year: parts[0], month: parts[1], day: parts[2])
}

func formatDate(_ jdn: Int) -> String {
    let date = civilDate(jdn)
    return String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
}

/// 力学时儒略日 → 北京时间，以子夜为日界：整数部分即当天的儒略日数
func beijingTime(_ jde: Double) -> Double {
    jde - deltaTSeconds / 86400 + 0.5 + 8.0 / 24
}

func beijingDay(_ jde: Double) -> Int {
    Int(beijingTime(jde).rounded(.down))
}

func formatBeijingTime(_ jde: Double) -> String {
    let minutes = Int((beijingTime(jde) * 1440).rounded())
    let day = Int((Double(minutes) / 1440).rounded(.down))
    let minuteOfDay = minutes - day * 1440
    return formatDate(day) + String(format: " %02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
}

/// 离北京时间零点不足 10 分钟
func isNearMidnight(_ jde: Double) -> Bool {
    let fraction = beijingTime(jde) - beijingTime(jde).rounded(.down)
    return min(fraction, 1 - fraction) * 1440 < 10
}

// MARK: - 太阳视黄经

let radiansPerDegree = Double.pi / 180

func normalizedDegrees(_ degrees: Double) -> Double {
    let value = degrees.truncatingRemainder(dividingBy: 360)
    return value < 0 ? value + 360 : value
}

typealias PeriodicTerm = (a: Double, b: Double, c: Double)

func series(_ terms: [PeriodicTerm], _ tau: Double) -> Double {
    terms.reduce(0) { $0 + $1.a * cos($1.b + $1.c * tau) }
}

// VSOP87 地球日心黄经 L、日地距离 R 的周期项（Meeus《天文算法》附录 III），单位 1e-8 弧度 / 1e-8 AU
let earthL0: [PeriodicTerm] = [
    (175347046, 0, 0), (3341656, 4.6692568, 6283.0758500), (34894, 4.62610, 12566.15170),
    (3497, 2.7441, 5753.3849), (3418, 2.8289, 3.5231), (3136, 3.6277, 77713.7715),
    (2676, 4.4181, 7860.4194), (2343, 6.1352, 3930.2097), (1324, 0.7425, 11506.7698),
    (1273, 2.0371, 529.6910), (1199, 1.1096, 1577.3435), (990, 5.233, 5884.927),
    (902, 2.045, 26.298), (857, 3.508, 398.149), (780, 1.179, 5223.694),
    (753, 2.533, 5507.553), (505, 4.583, 18849.228), (492, 4.205, 775.523),
    (357, 2.920, 0.067), (317, 5.849, 11790.629), (284, 1.899, 796.298),
    (271, 0.315, 10977.079), (243, 0.345, 5486.778), (206, 4.806, 2544.314),
    (205, 1.869, 5573.143), (202, 2.458, 6069.777), (156, 0.833, 213.299),
    (132, 3.411, 2942.463), (126, 1.083, 20.775), (115, 0.645, 0.980),
    (103, 0.636, 4694.003), (102, 0.976, 15720.839), (102, 4.267, 7.114),
    (99, 6.21, 2146.17), (98, 0.68, 155.42), (86, 5.98, 161000.69),
    (85, 1.30, 6275.96), (85, 3.67, 71430.70), (80, 1.81, 17260.15),
    (79, 3.04, 12036.46), (75, 1.76, 5088.63), (74, 3.50, 3154.69),
    (74, 4.68, 801.82), (70, 0.83, 9437.76), (62, 3.98, 8827.39),
    (61, 1.82, 7084.90), (57, 2.78, 6286.60), (56, 4.39, 14143.50),
    (56, 3.47, 6279.55), (52, 0.19, 12139.55), (52, 1.33, 1748.02),
    (51, 0.28, 5856.48), (49, 0.49, 1194.45), (41, 5.37, 8429.24),
    (41, 2.40, 19651.05), (39, 6.17, 10447.39), (37, 6.04, 10213.29),
    (37, 2.57, 1059.38), (36, 1.71, 2352.87), (36, 1.78, 6812.77),
    (33, 0.59, 17789.85), (30, 0.44, 83996.85), (30, 2.74, 1349.87),
    (25, 3.16, 4690.48),
]
let earthL1: [PeriodicTerm] = [
    (628331966747, 0, 0), (206059, 2.678235, 6283.075850), (4303, 2.6351, 12566.1517),
    (425, 1.590, 3.523), (119, 5.796, 26.298), (109, 2.966, 1577.344),
    (93, 2.59, 18849.23), (72, 1.14, 529.69), (68, 1.87, 398.15),
    (67, 4.41, 5507.55), (59, 2.89, 5223.69), (56, 2.17, 155.42),
    (45, 0.40, 796.30), (36, 0.47, 775.52), (29, 2.65, 7.11),
    (21, 5.34, 0.98), (19, 1.85, 5486.78), (19, 4.97, 213.30),
    (17, 2.99, 6275.96), (16, 0.03, 2544.31), (16, 1.43, 2146.17),
    (15, 1.21, 10977.08), (12, 2.83, 1748.02), (12, 3.26, 5088.63),
    (12, 5.27, 1194.45), (12, 2.08, 4694.00), (11, 0.77, 553.57),
    (10, 1.30, 6286.60), (10, 4.24, 1349.87), (9, 2.70, 242.73),
    (9, 5.64, 951.72), (8, 5.30, 2352.87), (6, 2.65, 9437.76),
    (6, 4.67, 4690.48),
]
let earthL2: [PeriodicTerm] = [
    (52919, 0, 0), (8720, 1.0721, 6283.0758), (309, 0.867, 12566.152),
    (27, 0.05, 3.52), (16, 5.19, 26.30), (16, 3.68, 155.42),
    (10, 0.76, 18849.23), (9, 2.06, 77713.77), (7, 0.83, 775.52),
    (5, 4.66, 1577.34), (4, 1.03, 7.11), (4, 3.44, 5573.14),
    (3, 5.14, 796.30), (3, 6.05, 5507.55), (3, 1.19, 242.73),
    (3, 6.12, 529.69), (3, 0.31, 398.15), (3, 2.28, 553.57),
    (2, 4.38, 5223.69), (2, 3.75, 0.98),
]
let earthL3: [PeriodicTerm] = [
    (289, 5.844, 6283.076), (35, 0, 0), (17, 5.49, 12566.15),
    (3, 5.20, 155.42), (1, 4.72, 3.52), (1, 5.30, 18849.23),
    (1, 5.97, 242.73),
]
let earthL4: [PeriodicTerm] = [(114, 3.142, 0), (8, 4.13, 6283.08), (1, 3.84, 12566.15)]
let earthL5: [PeriodicTerm] = [(1, 3.14, 0)]
/// 日地距离只用于光行差，取主要几项即可
let earthR0: [PeriodicTerm] = [
    (100013989, 0, 0), (1670700, 3.0984635, 6283.0758500), (13956, 3.05525, 12566.15170),
    (3084, 5.1985, 77713.7715), (1628, 1.1739, 5753.3849), (1576, 2.8469, 7860.4194),
]
let earthR1: [PeriodicTerm] = [(103019, 1.107490, 6283.075850), (1721, 1.0644, 12566.1517)]

/// 太阳视黄经（度）
func apparentSolarLongitude(_ jde: Double) -> Double {
    let tau = (jde - 2_451_545) / 365_250
    let t = tau * 10
    let longitude = [earthL0, earthL1, earthL2, earthL3, earthL4, earthL5].enumerated()
        .reduce(0) { $0 + series($1.element, tau) * pow(tau, Double($1.offset)) } / 1e8
    let distance = (series(earthR0, tau) + series(earthR1, tau) * tau) / 1e8
    // 日心黄经 + 180° 为太阳的地心几何黄经，再转到 FK5
    let geometric = longitude / radiansPerDegree + 180 - 0.09033 / 3600
    // 黄经章动（Meeus 第 22 章简化式，误差 0.5 角秒）
    let node = (125.04452 - 1934.136261 * t) * radiansPerDegree
    let sunMean = (280.4665 + 36000.7698 * t) * radiansPerDegree
    let moonMean = (218.3165 + 481267.8813 * t) * radiansPerDegree
    let nutation = (-17.20 * sin(node) - 1.32 * sin(2 * sunMean) - 0.23 * sin(2 * moonMean) + 0.21 * sin(2 * node)) / 3600
    let aberration = -20.4898 / 3600 / distance
    return normalizedDegrees(geometric + nutation + aberration)
}

/// 太阳视黄经到达 target 度的时刻（力学时），从 guess 附近开始迭代
func solarLongitudeTime(_ target: Double, near guess: Double) -> Double {
    var jde = guess
    for _ in 0..<30 {
        var difference = normalizedDegrees(target - apparentSolarLongitude(jde))
        if difference > 180 { difference -= 360 }
        jde += difference * 365.2422 / 360
        if abs(difference) < 1e-9 { break }
    }
    return jde
}

// MARK: - 月相

enum MoonPhase: Int {
    case new, firstQuarter, full, lastQuarter

    var key: String {
        switch self {
        case .new: "new"
        case .firstQuarter: "firstQuarter"
        case .full: "full"
        case .lastQuarter: "lastQuarter"
        }
    }
}

/// 第 lunation 个朔望月中某一月相的时刻（力学时）。lunation = 0 为 2000 年 1 月 6 日的朔（Meeus 第 49 章）
func moonPhaseTime(lunation: Int, phase: MoonPhase) -> Double {
    let k = Double(lunation) + Double(phase.rawValue) / 4
    let t = k / 1236.85
    let t2 = t * t, t3 = t2 * t, t4 = t3 * t
    var jde = 2_451_550.09766 + 29.530588861 * k + 0.00015437 * t2 - 0.000000150 * t3 + 0.00000000073 * t4
    let e = 1 - 0.002516 * t - 0.0000074 * t2
    let m = (2.5534 + 29.10535670 * k - 0.0000014 * t2 - 0.00000011 * t3) * radiansPerDegree
    let mp = (201.5643 + 385.81693528 * k + 0.0107582 * t2 + 0.00001238 * t3 - 0.000000058 * t4) * radiansPerDegree
    let f = (160.7108 + 390.67050284 * k - 0.0016118 * t2 - 0.00000227 * t3 + 0.000000011 * t4) * radiansPerDegree
    let node = (124.7746 - 1.56375588 * k + 0.0020672 * t2 + 0.00000215 * t3) * radiansPerDegree

    switch phase {
    case .new, .full:
        let isNew = phase == .new
        jde += (isNew ? -0.40720 : -0.40614) * sin(mp)
            + (isNew ? 0.17241 : 0.17302) * e * sin(m)
            + (isNew ? 0.01608 : 0.01614) * sin(2 * mp)
            + (isNew ? 0.01039 : 0.01043) * sin(2 * f)
            + (isNew ? 0.00739 : 0.00734) * e * sin(mp - m)
            + (isNew ? -0.00514 : -0.00515) * e * sin(mp + m)
            + (isNew ? 0.00208 : 0.00209) * e * e * sin(2 * m)
            - 0.00111 * sin(mp - 2 * f)
            - 0.00057 * sin(mp + 2 * f)
            + 0.00056 * e * sin(2 * mp + m)
            - 0.00042 * sin(3 * mp)
            + 0.00042 * e * sin(m + 2 * f)
            + 0.00038 * e * sin(m - 2 * f)
            - 0.00024 * e * sin(2 * mp - m)
            - 0.00017 * sin(node)
            - 0.00007 * sin(mp + 2 * m)
            + 0.00004 * sin(2 * mp - 2 * f)
            + 0.00004 * sin(3 * m)
            + 0.00003 * sin(mp + m - 2 * f)
            + 0.00003 * sin(2 * mp + 2 * f)
            - 0.00003 * sin(mp + m + 2 * f)
            + 0.00003 * sin(mp - m + 2 * f)
            - 0.00002 * sin(mp - m - 2 * f)
            - 0.00002 * sin(3 * mp + m)
            + 0.00002 * sin(4 * mp)
    case .firstQuarter, .lastQuarter:
        jde += -0.62801 * sin(mp)
            + 0.17172 * e * sin(m)
            - 0.01183 * e * sin(mp + m)
            + 0.00862 * sin(2 * mp)
            + 0.00804 * sin(2 * f)
            + 0.00454 * e * sin(mp - m)
            + 0.00204 * e * e * sin(2 * m)
            - 0.00180 * sin(mp - 2 * f)
            - 0.00070 * sin(mp + 2 * f)
            - 0.00040 * sin(3 * mp)
            - 0.00034 * e * sin(2 * mp - m)
            + 0.00032 * e * sin(m + 2 * f)
            + 0.00032 * e * sin(m - 2 * f)
            - 0.00028 * e * e * sin(mp + 2 * m)
            + 0.00027 * e * sin(2 * mp + m)
            - 0.00017 * sin(node)
            - 0.00005 * sin(mp - m - 2 * f)
            + 0.00004 * sin(2 * mp + 2 * f)
            - 0.00004 * sin(mp + m + 2 * f)
            + 0.00004 * sin(mp - 2 * m)
            + 0.00003 * sin(mp + m - 2 * f)
            + 0.00003 * sin(3 * m)
            + 0.00002 * sin(2 * mp - 2 * f)
            + 0.00002 * sin(mp - m + 2 * f)
            - 0.00002 * sin(3 * mp + m)
        let w = 0.00306 - 0.00038 * e * cos(m) + 0.00026 * cos(mp) - 0.00002 * cos(mp - m) + 0.00002 * cos(mp + m) + 0.00002 * cos(2 * f)
        jde += phase == .firstQuarter ? w : -w
    }

    // 行星摄动等附加项，四种月相相同
    let planetary: [(coefficient: Double, angle: Double)] = [
        (0.000325, 299.77 + 0.107408 * k - 0.009173 * t2),
        (0.000165, 251.88 + 0.016321 * k),
        (0.000164, 251.83 + 26.651886 * k),
        (0.000126, 349.42 + 36.412478 * k),
        (0.000110, 84.66 + 18.206239 * k),
        (0.000062, 141.74 + 53.303771 * k),
        (0.000060, 207.14 + 2.453732 * k),
        (0.000056, 154.84 + 7.306860 * k),
        (0.000047, 34.52 + 27.261239 * k),
        (0.000042, 207.19 + 0.121824 * k),
        (0.000040, 291.34 + 1.844379 * k),
        (0.000037, 161.72 + 24.198154 * k),
        (0.000035, 239.56 + 25.513099 * k),
        (0.000023, 331.55 + 3.592518 * k),
    ]
    jde += planetary.reduce(0) { $0 + $1.coefficient * sin($1.angle * radiansPerDegree) }
    return jde
}

// MARK: - 历法名称

let stems = Array("甲乙丙丁戊己庚辛壬癸")
let branches = Array("子丑寅卯辰巳午未申酉戌亥")
let zodiacs = Array("鼠牛虎兔龙蛇马羊猴鸡狗猪")
/// 从春分（视黄经 0°）起每 15° 一个节气；下标为偶数的是中气，奇数的是节
let termNames = [
    "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露",
    "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至", "小寒", "大寒", "立春", "雨水", "惊蛰",
]
let winterSolstice = 18
let beginningOfSpring = 21
let monthNames = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]

/// 六十甲子中的第 index 个（0 为甲子）
func ganZhi(_ index: Int) -> String {
    let index = (index % 60 + 60) % 60
    return String([stems[index % 10], branches[index % 12]])
}

/// 初一 … 初十、十一 … 十九、二十、廿一 … 廿九、三十
func lunarDayName(_ day: Int) -> String {
    let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    return switch day {
    case 1...10: "初" + digits[day]
    case 11...19: "十" + digits[day - 10]
    case 20: "二十"
    case 21...29: "廿" + digits[day - 20]
    default: "三十"
    }
}

// MARK: - 计算节气与月相

// 农历编排要用到前一个冬至和后一个冬至，干支纪年要用到前一个立春，所以计算范围前后各放宽一年多
let firstYear = civilDate(firstDay).year
let lastYear = civilDate(lastDay).year
let windowStart = Double(julianDayNumber(year: firstYear - 2, month: 12, day: 1))
let windowEnd = Double(julianDayNumber(year: lastYear + 1, month: 12, day: 31))

struct Event {
    let jde: Double
    var day: Int { beijingDay(jde) }
}

var solarTerms: [(event: Event, index: Int)] = []
do {
    var index = Int(apparentSolarLongitude(windowStart) / 15) + 1
    var guess = windowStart + Double(index * 15) - apparentSolarLongitude(windowStart)
    while guess < windowEnd + 20 {
        let jde = solarLongitudeTime(Double(index % 24 * 15), near: guess)
        solarTerms.append((Event(jde: jde), index % 24))
        index += 1
        guess = jde + 15.2
    }
}

var moonPhases: [(event: Event, phase: MoonPhase)] = []
do {
    let firstLunation = Int(((windowStart - 60 - 2_451_550.1) / 29.530588861).rounded(.down))
    let lastLunation = Int(((windowEnd + 60 - 2_451_550.1) / 29.530588861).rounded(.up))
    for lunation in firstLunation...lastLunation {
        for phase in [MoonPhase.new, .firstQuarter, .full, .lastQuarter] {
            moonPhases.append((Event(jde: moonPhaseTime(lunation: lunation, phase: phase)), phase))
        }
    }
}

let outputRange = firstDay...lastDay
for (event, index) in solarTerms where outputRange.contains(event.day) && isNearMidnight(event.jde) {
    FileHandle.standardError.write(Data("⚠︎ \(termNames[index]) \(formatBeijingTime(event.jde)) 离零点不足 10 分钟，请核对日期\n".utf8))
}
for (event, phase) in moonPhases where phase == .new && outputRange.contains(event.day) && isNearMidnight(event.jde) {
    FileHandle.standardError.write(Data("⚠︎ 朔 \(formatBeijingTime(event.jde)) 离零点不足 10 分钟，请核对初一的日期\n".utf8))
}

// MARK: - 农历月

/// 每个农历月初一的儒略日数；最后一项只作为前一个月的结束
let monthStarts = moonPhases.filter { $0.phase == .new }.map(\.event.day).sorted()
let principalTermDays = solarTerms.filter { $0.index % 2 == 0 }.map(\.event.day)

struct LunarMonth {
    let start: Int
    let end: Int
    var number = 0
    var isLeap = false
}

var lunarMonths = zip(monthStarts, monthStarts.dropFirst()).map { LunarMonth(start: $0, end: $1) }

func monthIndex(containing day: Int) -> Int? {
    lunarMonths.firstIndex { $0.start <= day && day < $0.end }
}

let solsticeMonths = solarTerms.filter { $0.index == winterSolstice }.compactMap { monthIndex(containing: $0.event.day) }
for (from, to) in zip(solsticeMonths, solsticeMonths.dropFirst()) {
    let count = to - from
    precondition(count == 12 || count == 13, "两个冬至月之间有 \(count) 个月")
    var number = 11
    var needsLeap = count == 13
    lunarMonths[from].number = 11
    for index in (from + 1)..<to {
        let month = lunarMonths[index]
        let hasPrincipalTerm = principalTermDays.contains { month.start <= $0 && $0 < month.end }
        if needsLeap && !hasPrincipalTerm {
            lunarMonths[index].isLeap = true
            needsLeap = false
        } else {
            number = number % 12 + 1
        }
        lunarMonths[index].number = number
    }
    precondition(!needsLeap, "冬至月 \(formatDate(lunarMonths[from].start)) 起的 13 个月里找不到无中气的月")
}

// MARK: - 逐日数据

func lastEvent<T>(_ events: [(event: Event, value: T)], onOrBefore day: Int) -> (event: Event, value: T)? {
    events.last { $0.event.day <= day }
}

let beginningsOfSpring = solarTerms.filter { $0.index == beginningOfSpring }.map { (event: $0.event, value: civilDate($0.event.day).year) }
/// 节（下标为奇数）对应的干支月序：立春 1（寅月）… 小寒 12（丑月）
let monthBoundaries = solarTerms.filter { $0.index % 2 == 1 }.map { (event: $0.event, value: ($0.index - beginningOfSpring + 24) % 24 / 2 + 1) }
let termByDay = Dictionary(solarTerms.map { ($0.event.day, termNames[$0.index]) }, uniquingKeysWith: { first, _ in first })
let phaseByDay = Dictionary(moonPhases.map { ($0.event.day, $0.phase) }, uniquingKeysWith: { first, _ in first })

var dayLines: [String] = []
for day in outputRange {
    guard let index = monthIndex(containing: day), lunarMonths[index].number > 0,
          let lunarNewYear = lunarMonths[...index].last(where: { $0.number == 1 && !$0.isLeap }),
          let spring = lastEvent(beginningsOfSpring, onOrBefore: day),
          let boundary = lastEvent(monthBoundaries, onOrBefore: day)
    else {
        fatalError("\(formatDate(day)) 超出计算范围")
    }
    let month = lunarMonths[index]
    let lunarDay = day - month.start + 1
    let lunarYear = civilDate(lunarNewYear.start).year
    let ganZhiYear = spring.value
    // 1984 年为甲子年，其寅月为丙寅（六十甲子第 2 个），之后每月顺延
    let ganZhiMonth = 2 + (ganZhiYear - 1984) * 12 + boundary.value - 1

    var fields = [
        "\"date\":\"\(formatDate(day))\"",
        "\"lunarYear\":\"\(ganZhi(lunarYear - 1984))\"",
        "\"lunarMonth\":\(month.number)",
        "\"isLeapMonth\":\(month.isLeap)",
        "\"lunarMonthName\":\"\(month.isLeap ? "闰" : "")\(monthNames[month.number - 1])\"",
        "\"lunarMonthDays\":\(month.end - month.start)",
        "\"lunarDay\":\(lunarDay)",
        "\"lunarDayName\":\"\(lunarDayName(lunarDay))\"",
        "\"ganZhiYear\":\"\(ganZhi(ganZhiYear - 1984))\"",
        "\"ganZhiMonth\":\"\(ganZhi(ganZhiMonth))\"",
        // 2000-01-01（儒略日数 2451545）为戊午日，即六十甲子第 54 个
        "\"ganZhiDay\":\"\(ganZhi(day + 49))\"",
        "\"zodiac\":\"\(zodiacs[((ganZhiYear - 1984) % 12 + 12) % 12])\"",
    ]
    if let term = termByDay[day] {
        fields.append("\"solarTerm\":\"\(term)\"")
    }
    if let phase = phaseByDay[day] {
        fields.append("\"moonPhase\":\"\(phase.key)\"")
    }
    dayLines.append("    {" + fields.joined(separator: ",") + "}")
}

// MARK: - 输出

let termLines = solarTerms.filter { outputRange.contains($0.event.day) }.map {
    "    {\"name\":\"\(termNames[$0.index])\",\"time\":\"\(formatBeijingTime($0.event.jde))\"}"
}
let phaseLines = moonPhases.filter { outputRange.contains($0.event.day) }.map {
    "    {\"phase\":\"\($0.phase.key)\",\"time\":\"\(formatBeijingTime($0.event.jde))\"}"
}

let json = """
{
  "generator": "Scripts/generate-chinese-calendar.swift",
  "timeZone": "UTC+8",
  "deltaTSeconds": \(Int(deltaTSeconds)),
  "firstDay": "\(formatDate(firstDay))",
  "lastDay": "\(formatDate(lastDay))",
  "solarTerms": [
\(termLines.joined(separator: ",\n"))
  ],
  "moonPhases": [
\(phaseLines.joined(separator: ",\n"))
  ],
  "days": [
\(dayLines.joined(separator: ",\n"))
  ]
}

"""
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try Data(json.utf8).write(to: outputURL)
print("已生成 \(outputURL.path)：\(dayLines.count) 天，\(termLines.count) 个节气，\(phaseLines.count) 个月相")
