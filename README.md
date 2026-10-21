# Orderly

macOS 磁盘清理工具。

- 仅支持 Apple 芯片（arm64），最低系统 macOS 15.0
- 启动后引导开启「完全磁盘访问权限」
- 扫描系统垃圾、应用缓存、大文件，结果默认按 App 分组，勾选后清理

## 构建与运行

需要 Swift 6 工具链（Xcode 16+ 或 Command Line Tools 16+）。

```bash
make run        # 打包 debug 版 build/Orderly.app 并启动
make app        # 打包 release 版 build/Orderly.app
make test       # 运行单元测试
```

**必须通过 `.app` 启动来测试权限。** 用 `swift run` 或在终端直接运行可执行文件时，
系统会把权限归属到终端，而不是 Orderly。

`make` 通过 `Scripts/swift.sh` 调用 swift。部分 Command Line Tools 升级后会残留旧文件，
导致 Package.swift 无法链接、Foundation 无法构建；该脚本检测到这种情况时会自动绕过（不修改系统文件）。
彻底解决的办法是重新安装 Command Line Tools，或安装 Xcode。

ad-hoc 签名（默认）的 App 每次重新构建签名都会变化，系统会把它当成新 App，
需要重新授予完全磁盘访问权限。日常开发建议用固定证书签名：

```bash
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" make run
```

## 目录结构

```
Sources/Orderly/
├── App/            入口、全局状态（AppModel）、扫描进度、结果页状态
├── Permissions/    完全磁盘访问权限检测与引导
├── Scanner/        扫描引擎
│   ├── ScanEngine      并发执行所有规则并汇总
│   ├── ScanRule        规则协议、上下文、进度上报
│   ├── AppCatalog      已安装 App 索引，负责把文件归属到 App
│   └── Rules/          具体扫描规则
├── Cleaner/        清理执行与删除前的安全检查（SafetyGuard）
├── Views/          SwiftUI 界面
└── Support/        主题、格式化等
Resources/          Info.plist、entitlements
Scripts/            打包脚本
```

## 流程

```
授权页 ──授权/跳过──▶ 等待界面 ──扫描──▶ 扫描中 ──▶ 结果（按应用 / 按类型）──清理──▶ 清理中 ──▶ 完成
```

## 扫描规则

| 规则 | 位置 | 类别 | 默认勾选 | 清理方式 | 需要完全磁盘访问 |
| --- | --- | --- | --- | --- | --- |
| 用户缓存 | `~/Library/Caches/*` | 应用缓存 | ✓ | 清空目录 | |
| 沙盒 App 缓存 | `~/Library/Containers/*/Data/Library/Caches` | 应用缓存 | ✓ | 清空目录 | ✓ |
| 日志与崩溃报告 | `~/Library/Logs` | 系统垃圾 | ✓ | 删除 | |
| 窗口恢复数据 | `~/Library/Saved Application State` | 系统垃圾 | ✓ | 删除 | |
| 开发工具残留 | Xcode DerivedData、模拟器缓存、设备支持文件 | 系统垃圾 | 部分 | 清空目录 | |
| 废纸篓 | `~/.Trash` | 系统垃圾 | ✓ | 清空 | ✓ |
| 安装包 | `~/Downloads/*.dmg/pkg/xip` | 系统垃圾 | | 移到废纸篓 | ✓ |
| 大文件 | 个人目录（不含 `~/Library`），≥ 100 MB | 大文件 | | 移到废纸篓 | ✓ |

所属 App 正在运行的项目默认不勾选。

新增规则：实现 `ScanRule` 协议，并加入 `ScanEngine.standard`。

## 安全措施

- App 不启用沙盒（需要访问其他 App 的数据），开启 Hardened Runtime
- 用户文件（大文件、安装包）只会移到废纸篓，可以恢复
- `SafetyGuard` 在每次删除前检查：目标必须位于个人目录内，不能是 `~/Library`、`~/Documents` 等关键目录本身，不清空符号链接
- iCloud、账户等系统服务相关的缓存直接跳过（见 `ScanPolicy`）

## 已知限制

- 只扫描当前用户的个人目录，不处理 `/Library`、`/private/var` 等需要管理员权限的位置
- 尚未做 App 图标、多语言、设置页（大文件阈值等目前写在 `ScanConfiguration` 中）
