import CoreText
import Foundation
import os

/// 楷体是 macOS 按需下载的系统字体（存放在 /System/Library/AssetsV2），
/// 沙盒里的小组件进程默认找不到它，SwiftUI 会退回系统字体。
/// 进程启动时先向 CoreText 请求匹配一次，字体才对本进程可用。
enum DownloadableFonts {
    private static let fonts = [(postScriptName: "STKaitiSC-Bold", fileName: "Kaiti.ttc")]
    private static let logger = Logger(subsystem: "com.orderly.Orderly.Widget", category: "fonts")

    static func activate() {
        let missing = fonts.filter { !isAvailable($0.postScriptName) }
        guard !missing.isEmpty else { return }

        let descriptors = missing.map {
            CTFontDescriptorCreateWithAttributes([kCTFontNameAttribute: $0.postScriptName] as CFDictionary)
        } as CFArray
        let finished = DispatchSemaphore(value: 0)
        CTFontDescriptorMatchFontDescriptorsWithProgressHandler(descriptors, nil) { state, _ in
            if state == .didFinish {
                finished.signal()
            }
            return true
        }
        // 已下载过时很快完成；没下载过会触发下载，不能让小组件一直等
        if finished.wait(timeout: .now() + 3) == .timedOut {
            logger.error("字体匹配超时")
        }

        for font in missing where !isAvailable(font.postScriptName) {
            registerFromAssets(font.fileName)
        }
        for font in missing {
            logger.notice("\(font.postScriptName, privacy: .public) 可用：\(isAvailable(font.postScriptName))")
        }
    }

    private static func isAvailable(_ postScriptName: String) -> Bool {
        CTFontCopyPostScriptName(CTFontCreateWithName(postScriptName as CFString, 12, nil)) as String == postScriptName
    }

    /// 退路：在系统字体资源目录中找到字体文件，直接注册到本进程
    private static func registerFromAssets(_ fileName: String) {
        let root = URL(filePath: "/System/Library/AssetsV2")
        let fileManager = FileManager.default
        let collections = (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        for collection in collections where collection.lastPathComponent.hasPrefix("com_apple_MobileAsset_Font") {
            let assets = (try? fileManager.contentsOfDirectory(at: collection, includingPropertiesForKeys: nil)) ?? []
            for asset in assets {
                let file = asset.appending(path: "AssetData/\(fileName)")
                if fileManager.fileExists(atPath: file.path) {
                    CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
                    return
                }
            }
        }
        logger.error("没有找到 \(fileName, privacy: .public)")
    }
}
