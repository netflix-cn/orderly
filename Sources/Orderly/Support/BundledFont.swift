import CoreText
import os
import SwiftUI

/// 界面字体：思源宋体半粗（Noto Serif SC SemiBold，SIL OFL 1.1）。字体文件由 Scripts/build-app.sh 复制到 Contents/Resources/Fonts，
/// 启动时注册到本进程，不需要安装或联网。直接运行未打包的可执行文件时找不到字体，会退回系统字体
enum BundledFont {
    static let name = "NotoSerifSC-SemiBold"
    private static let logger = Logger(subsystem: "com.orderly.Orderly", category: "fonts")

    /// 必须在创建任何界面之前调用
    static func register() {
        guard let url = Bundle.main.url(forResource: "NotoSerifSC-SemiBold", withExtension: "otf", subdirectory: "Fonts") else {
            logger.error("App 包内没有字体文件")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            logger.error("字体注册失败：\(error?.takeRetainedValue().localizedDescription ?? "", privacy: .public)")
        }
    }
}

extension Font {
    /// 与系统文本样式同字号的思源宋体半粗。
    /// 只打包了这一个字重，.bold() 等不起作用，层级靠字号区分
    static func app(_ style: TextStyle) -> Font {
        .custom(BundledFont.name, size: style.pointSize, relativeTo: style)
    }

    static func app(size: CGFloat) -> Font {
        .custom(BundledFont.name, size: size)
    }
}

private extension Font.TextStyle {
    /// macOS 各文本样式的默认字号
    var pointSize: CGFloat {
        switch self {
        case .largeTitle: 26
        case .title: 22
        case .title2: 17
        case .title3: 15
        case .headline, .body: 13
        case .callout: 12
        case .subheadline: 11
        case .footnote, .caption, .caption2: 10
        @unknown default: 13
        }
    }
}
