import CoreText
import Foundation
import os

/// 江西拙楷 2.0（黄煜臣）。字体文件由 Scripts/build-app.sh 复制到扩展的 Contents/Resources/Fonts，
/// 小组件进程启动时注册到本进程，不需要安装或联网
enum BundledFont {
    static let name = "jiangxizhuokai-Regular"
    private static let logger = Logger(subsystem: "com.orderly.Orderly.Widget", category: "fonts")

    static func register() {
        guard let url = Bundle.main.url(forResource: "JiangxiZhuokai", withExtension: "ttf", subdirectory: "Fonts") else {
            logger.error("扩展包内没有字体文件")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            logger.error("字体注册失败：\(error?.takeRetainedValue().localizedDescription ?? "", privacy: .public)")
        }
    }
}
