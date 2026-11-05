// 生成 App 图标 Resources/AppIcon.icns：渐变圆角方底上一张带金属光泽的磁盘盘片，配闪光，表示“清理磁盘”。
//
// 用法：
//   Scripts/swift.sh Scripts/generate-app-icon.swift Resources/AppIcon.icns [预览.png]
//
// 每个尺寸都按矢量重新绘制，小尺寸也清晰。配色取自 Theme.heroGradient；画布与 macOS 图标模板一致：
// 1024 画布，图标主体 824×824 居中，四周留白给阴影。

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = Array(CommandLine.arguments.dropFirst())
guard (1...2).contains(arguments.count) else {
    FileHandle.standardError.write(Data("用法：generate-app-icon.swift <输出 .icns> [预览 .png]\n".utf8))
    exit(2)
}
let outputURL = URL(filePath: arguments[0])
let previewURL = arguments.count == 2 ? URL(filePath: arguments[1]) : nil

// MARK: - 配色

func color(_ rgb: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255,
        green: CGFloat(rgb >> 8 & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: alpha
    )
}

/// Theme.gradientStart / gradientEnd
let teal = color(0x2ECCA8)
let blue = color(0x337AF5)
let deepBlue = color(0x2A5FD0)

func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
}

// MARK: - 形状（坐标系为 1024 画布，y 轴向下）

/// macOS 图标的连续圆角方形，用超椭圆近似
func squircle(center: CGPoint, halfSize: CGFloat, exponent: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let steps = 720
    for step in 0...steps {
        let angle = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let c = cos(angle), s = sin(angle)
        let x = center.x + halfSize * copysign(pow(abs(c), 2 / exponent), c)
        let y = center.y + halfSize * copysign(pow(abs(s), 2 / exponent), s)
        step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

/// 四角闪光：四个尖角之间用向内的曲线连接
func sparkle(center: CGPoint, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let inner = radius * 0.16
    let tips = (0..<4).map { index -> CGPoint in
        let angle = CGFloat(index) * .pi / 2 - .pi / 2
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
    path.move(to: tips[0])
    for index in 0..<4 {
        let next = tips[(index + 1) % 4]
        let angle = CGFloat(index) * .pi / 2 - .pi / 4
        let control = CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle))
        path.addQuadCurve(to: next, control: control)
    }
    path.closeSubpath()
    return path
}

/// 锥形渐变：颜色沿圆周均匀插值，用细扇形逐段填充（命令行工具的 SDK 里没有 drawConicGradient）
func fillConicGradient(_ context: CGContext, center: CGPoint, radius: CGFloat, rotation: CGFloat, colors: [UInt32]) {
    func channel(_ rgb: UInt32, _ shift: UInt32) -> CGFloat { CGFloat(rgb >> shift & 0xFF) / 255 }
    let segments = 720
    context.saveGState()
    // 扇形之间不做抗锯齿，避免出现放射状细缝；外圈边缘由调用方的圆形裁剪负责平滑
    context.setShouldAntialias(false)
    for segment in 0..<segments {
        let position = CGFloat(segment) / CGFloat(segments) * CGFloat(colors.count - 1)
        let index = min(Int(position), colors.count - 2)
        let fraction = position - CGFloat(index)
        let (from, to) = (colors[index], colors[index + 1])
        let mix = { (shift: UInt32) in channel(from, shift) + (channel(to, shift) - channel(from, shift)) * fraction }
        context.setFillColor(CGColor(srgbRed: mix(16), green: mix(8), blue: mix(0), alpha: 1))
        let start = rotation + CGFloat(segment) / CGFloat(segments) * 2 * .pi
        let end = rotation + CGFloat(segment + 1) / CGFloat(segments) * 2 * .pi + 0.002
        context.move(to: center)
        context.addArc(center: center, radius: radius + 2, startAngle: start, endAngle: end, clockwise: false)
        context.closePath()
        context.fillPath()
    }
    context.restoreGState()
}

// MARK: - 绘制

func drawIcon(_ context: CGContext, pixels: Int) {
    let scale = CGFloat(pixels) / 1024
    context.saveGState()
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)
    // 阴影的偏移和模糊不受坐标变换影响，按像素换算；偏移在设备坐标里 y 向上，向下偏移取负值
    func shadow(_ offset: CGFloat, blur: CGFloat, alpha: CGFloat) {
        context.setShadow(offset: CGSize(width: 0, height: -offset * scale), blur: blur * scale, color: color(0x000000, alpha))
    }

    // 主体：青绿到蓝的对角渐变
    let body = squircle(center: CGPoint(x: 512, y: 512), halfSize: 412)
    context.saveGState()
    shadow(10, blur: 24, alpha: 0.28)
    context.addPath(body)
    context.setFillColor(blue)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(body)
    context.clip()
    context.drawLinearGradient(gradient([teal, blue, deepBlue], [0, 0.62, 1]), start: CGPoint(x: 150, y: 120), end: CGPoint(x: 880, y: 920), options: [])
    // 左上角柔光，增加层次
    context.drawRadialGradient(
        gradient([color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)]),
        startCenter: CGPoint(x: 300, y: 220), startRadius: 0,
        endCenter: CGPoint(x: 300, y: 220), endRadius: 520, options: []
    )
    context.restoreGState()

    // 盘片
    let disk = CGPoint(x: 488, y: 548)
    let diskRadius: CGFloat = 282
    let diskRect = CGRect(x: disk.x - diskRadius, y: disk.y - diskRadius, width: diskRadius * 2, height: diskRadius * 2)
    context.saveGState()
    shadow(16, blur: 36, alpha: 0.30)
    context.addEllipse(in: diskRect)
    context.setFillColor(color(0xFFFFFF))
    context.fillPath()
    context.restoreGState()

    // 盘片的金属光泽：锥形渐变让亮暗沿圆周交替，再压一层由中心向边缘略暗的径向渐变
    context.saveGState()
    context.addEllipse(in: diskRect)
    context.clip()
    fillConicGradient(context, center: disk, radius: diskRadius, rotation: -.pi / 3,
                      colors: [0xFFFFFF, 0xD3DDEB, 0xF7FAFE, 0xC9D5E6, 0xFFFFFF, 0xD3DDEB, 0xF7FAFE, 0xC9D5E6, 0xFFFFFF])
    context.drawRadialGradient(
        gradient([color(0xFFFFFF, 0), color(0x9FB2CC, 0.28)]),
        startCenter: disk, startRadius: diskRadius * 0.55, endCenter: disk, endRadius: diskRadius, options: []
    )
    context.restoreGState()

    // 磁道
    context.setLineWidth(4)
    context.setStrokeColor(color(0xB8C7DD, 0.75))
    for radius: CGFloat in [248, 206, 164] {
        context.strokeEllipse(in: CGRect(x: disk.x - radius, y: disk.y - radius, width: radius * 2, height: radius * 2))
    }
    // 主轴外的垫圈
    context.setFillColor(color(0xEEF3FA))
    context.fillEllipse(in: CGRect(x: disk.x - 112, y: disk.y - 112, width: 224, height: 224))
    context.setLineWidth(4)
    context.setStrokeColor(color(0xB8C7DD))
    context.strokeEllipse(in: CGRect(x: disk.x - 112, y: disk.y - 112, width: 224, height: 224))

    // 主轴
    let hubRadius: CGFloat = 74
    context.saveGState()
    context.addEllipse(in: CGRect(x: disk.x - hubRadius, y: disk.y - hubRadius, width: hubRadius * 2, height: hubRadius * 2))
    context.clip()
    context.drawLinearGradient(gradient([teal, blue]), start: CGPoint(x: disk.x - hubRadius, y: disk.y - hubRadius), end: CGPoint(x: disk.x + hubRadius, y: disk.y + hubRadius), options: [])
    context.restoreGState()
    context.setFillColor(color(0xFFFFFF))
    context.fillEllipse(in: CGRect(x: disk.x - 24, y: disk.y - 24, width: 48, height: 48))

    // 闪光
    context.saveGState()
    context.setShadow(offset: .zero, blur: 22 * scale, color: color(0xFFFFFF, 0.75))
    context.setFillColor(color(0xFFFFFF))
    for (center, radius) in [(CGPoint(x: 768, y: 262), CGFloat(104)), (CGPoint(x: 852, y: 392), CGFloat(50)), (CGPoint(x: 676, y: 170), CGFloat(36))] {
        context.addPath(sparkle(center: center, radius: radius))
        context.fillPath()
    }
    context.restoreGState()

    context.restoreGState()
}

func renderPNG(pixels: Int, to url: URL) throws {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    drawIcon(context, pixels: pixels)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
    }
}

// MARK: - 输出

let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    try renderPNG(pixels: points, to: iconset.appending(path: "icon_\(points)x\(points).png"))
    try renderPNG(pixels: points * 2, to: iconset.appending(path: "icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(filePath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", "--output", outputURL.path, iconset.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil 失败\n".utf8))
    exit(1)
}

if let previewURL {
    try renderPNG(pixels: 1024, to: previewURL)
}
print("已生成 \(outputURL.path)")
