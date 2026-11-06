# Orderly

macOS 磁盘清理工具。

- 仅支持 Apple 芯片（arm64），最低系统 macOS 15.0
- 启动后引导开启「完全磁盘访问权限」
- 扫描系统垃圾、应用缓存、大文件，结果默认按 App 分组，勾选后清理

> [!WARNING]
> 本软件会**永久删除**文件。使用前请先备份重要数据，并阅读文末的[免责声明](#免责声明--disclaimer)。
> 构建、运行或分发本项目，即表示你同意该声明。

## 构建与运行

需要 Swift 6 工具链（Xcode 16+ 或 Command Line Tools 16+）。

```bash
make app-1password  # 从 1Password 取证书，生成 build/Orderly.app 和 build/Orderly-<版本>.dmg
Scripts/sign-with-1password.sh make run  # 同样从 1Password 取证书，打包 debug 版并启动
make test       # 运行单元测试
make calendar-data  # 按天文算法重新生成小组件的离线农历数据
make app-icon   # 重新绘制 App 图标 Resources/AppIcon.icns
```

**必须通过 `.app` 启动来测试权限。** 用 `swift run` 或在终端直接运行可执行文件时，
系统会把权限归属到终端，而不是 Orderly。

`make` 通过 `Scripts/swift.sh` 调用 swift。部分 Command Line Tools 升级后会残留旧文件，
导致 Package.swift 无法链接、Foundation 无法构建；该脚本检测到这种情况时会自动绕过（不修改系统文件）。
彻底解决的办法是重新安装 Command Line Tools，或安装 Xcode。

打包统一从 1Password 取签名证书。首次在新检出中使用时，创建本地配置：

```bash
cp .signing.example.json .signing.local.json
chmod 600 .signing.local.json
# 编辑 .signing.local.json，填入实际的 OP_SIGN_VAULT 和 OP_SIGN_ITEM（26 位 ID）
Scripts/sign-with-1password.sh --check-config
make app-1password
```

`.signing.local.json` 已加入 Git 忽略规则，只保存保险库与条目 ID；可提交的 `.signing.example.json` 只含占位符。
脚本按自身位置定位仓库根目录，自动读取本地配置；环境变量 `OP_SIGN_VAULT`、`OP_SIGN_ITEM` 优先，
也可用 `OP_SIGN_CONFIG` 指定其他 JSON 配置文件。配置仅按数据解析，不执行其中的代码；
`--check-config` 只检查配置格式，不访问 1Password，实际条目权限和证书内容在打包时校验。

需要 1Password CLI（`op`）及有效授权，条目中应包含 p12 文件和保存导出密码的隐藏字段。
脚本将证书导入临时钥匙串供签名，结束时清理，私钥不必留在登录钥匙串。
取不到证书时会停止，不改用登录钥匙串或 ad-hoc 签名；构建与签名约定见 `AGENTS.md`。
固定证书可保持完全磁盘访问权限与小组件的签名身份；换证书后系统会当成新 App，需重新授权。
dmg 没有公证，在其他 Mac 上打开时需要在「隐私与安全性」里允许。

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
Sources/OrderlyWidget/  桌面小组件扩展（打包为 Orderly.app/Contents/PlugIns/OrderlyWidget.appex）
├── CalendarWidget      小组件定义与时间线（每天零点刷新）
├── CalendarWidgetView  大号日历界面
├── WeekCalendar        公历：前后五周排布、第几天/第几周、星座
└── ChineseCalendar     读取离线农历数据：农历、节气、月相、干支
Resources/          Info.plist、entitlements（App 与小组件各一份）、AppIcon.icns 图标、Fonts/ 界面字体、Calendar/ 离线农历数据
Scripts/            打包脚本、农历数据与 App 图标的生成脚本
Tools/              开发辅助：widget-font-preview.html 小组件字体预览页
AGENTS.md           项目规范、当前进度与协作约定的统一维护入口
CLAUDE.md           Claude 初始化入口，加载并遵守 AGENTS.md
.signing.example.json  可提交的 1Password 签名配置模板（占位符）
.signing.local.json    本机签名配置，Git 忽略
```

## 字体

App 和小组件全部文字使用思源宋体半粗（Noto Serif SC SemiBold，`Resources/Fonts/NotoSerifSC-SemiBold.otf`，
PostScript 名为 `NotoSerifSC-SemiBold`），来自 [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk) 的简体中文子集，
按 SIL Open Font License 1.1 授权，许可证见 `Resources/Fonts/NotoSerifSC-OFL.txt`。
打包时字体与许可证复制进 App 和小组件扩展各一份，启动时注册到本进程（`BundledFont`），不需要安装或联网。

- 只打包了半粗一个字重，`.bold()` 等不起作用，层级靠字号区分
- 菜单栏、窗口标题、工具栏分段控件、确认对话框、右键菜单由系统绘制，仍是系统字体
- 直接运行未打包的可执行文件（`swift run`）时找不到字体，会退回系统字体
- 换字体前可以用 `Tools/widget-font-preview.html` 预览小组件效果（见 AGENTS.md）

## 桌面小组件

大号「日历」小组件：星期、农历、节气、月相、干支纪年。日期区固定 5 行，本周在第 3 行，
上下依次为前两周、前一周、后一周、后两周；所有日期同样颜色显示，跨月的日期不变暗。

- 农历、节气、月相、干支来自离线数据 `Resources/Calendar/chinese-calendar.json`，覆盖公历 2026-01-01 至 2027-12-31，
  打包时复制进扩展；超出范围的日期不显示农历行和干支行。星座、当年第几天、第几周由 `SolarDate` 直接计算
- 数据由 `Scripts/generate-chinese-calendar.swift` 按天文算法生成（`make calendar-data`，可用 `CALENDAR_FROM`、
  `CALENDAR_TO` 调整范围）：节气用 VSOP87 计算太阳视黄经，朔望用 Meeus《天文算法》第 49 章，
  农历按 GB/T 33661-2017 编排（北京时间，含冬至的月为十一月，无中气的月置闰）
- 干支纪年和生肖以立春为界，干支纪月以「节」为界；数据中另有以正月初一为界的农历年（`lunarYear`）
- 生成结果已与香港天文台 2026、2027 年公历与农历日期对照表逐日核对一致（农历月日、节气日期），
  测试中再与系统的农历（ICU）逐日比对
- 扩展必须启用 App Sandbox（见 `Resources/OrderlyWidget.entitlements`），不需要其他权限
- 使用 `make app-1password` 从 1Password 取固定证书签名，保持小组件的签名身份
- `Scripts/sign-with-1password.sh make run` 启动一次 App 后，在桌面右键 →「编辑小组件」→ 搜索 Orderly，添加大号「日历」

## 流程

```
授权页 ──授权/跳过──▶ 等待界面 ──扫描──▶ 扫描中 ──▶ 结果（按应用 / 按类型）──清理──▶ 清理中 ──▶ 完成
```

首页按当前权限显示可扫描的位置。扫描后可以逐项勾选，结果页会分别列出预计释放的容量和将移到废纸篓的容量。
在结果页打开系统设置授权时，本轮结果和勾选会保留在当前窗口。返回后可以继续处理，也可以重新扫描以包含新获授权的位置。

## 扫描规则

| 规则 | 位置 | 类别 | 默认勾选 | 清理方式 | 需要完全磁盘访问 |
| --- | --- | --- | --- | --- | --- |
| 用户缓存 | `~/Library/Caches/*` | 应用缓存 | ✓ | 清空目录 | |
| 沙盒 App 缓存 | `~/Library/Containers/*/Data/Library/Caches` | 应用缓存 | ✓ | 清空目录 | ✓ |
| 日志与崩溃报告 | `~/Library/Logs` | 系统垃圾 | ✓ | 删除 | |
| 窗口恢复数据 | `~/Library/Saved Application State` | 系统垃圾 | ✓ | 删除 | |
| 开发工具残留 | Xcode DerivedData、模拟器缓存、设备支持文件 | 系统垃圾 | 部分 | 清空目录 | |
| 废纸篓 | `~/.Trash` | 系统垃圾 | | 永久清空已有内容 | ✓ |
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
- 尚未做多语言、设置页（大文件阈值等目前写在 `ScanConfiguration` 中）

## 许可证

Copyright © 2026 nanashi@top.ge

本项目基于 [MIT 许可证](LICENSE) 开源。

## 免责声明 / Disclaimer

本声明是对 [LICENSE](LICENSE) 中免责条款的补充说明。

本项目源码及由其构建的任何程序均按「原样」提供，不附带任何明示或暗示的担保，
包括但不限于对适销性、特定用途适用性、扫描结果准确性及不侵权的担保。

1. **删除风险**：本软件会永久删除缓存、日志、废纸篓等文件，或将文件移到废纸篓。
   被永久删除的文件通常无法恢复。清理前请自行确认勾选的项目，并使用 Time Machine 等方式备份重要数据。
2. **安全措施不构成保证**：项目中的安全检查、默认勾选策略和归属判断只能降低误删风险，不能完全避免。
   扫描结果可能不准确，某些被判断为可清理的文件可能仍被 App 或系统使用。
3. **责任限制**：因使用、修改、构建或分发本项目源码（包括任何第三方修改或构建的版本），
   或因无法使用本软件而造成的任何直接、间接、附带、特殊或后果性损失，
   包括但不限于文件误删、数据丢失、App 或系统异常、业务中断，
   作者及贡献者均不承担任何责任，即使事先已被告知发生此类损失的可能性。
4. **第三方构建**：他人使用本源码构建、修改或分发的程序与本项目作者无关，作者不对其行为及后果负责。
5. **风险自负**：你须自行承担使用本软件的全部风险。如不同意本声明，请勿构建、运行或分发本项目。

在适用法律不允许排除或限制上述责任的范围内，作者的责任以法律允许的最小范围为限。

---

This source code and any software built from it are provided "AS IS", without warranty of any kind,
express or implied, including but not limited to the warranties of merchantability, fitness for a
particular purpose, accuracy of scan results, and non-infringement.

The software permanently deletes files (such as caches, logs and Trash contents) or moves them to the
Trash; permanently deleted files usually cannot be recovered. Its safety checks and default selections
reduce, but do not eliminate, the risk of deleting files that are still needed. Review your selection
and back up important data before cleaning.

In no event shall the authors or contributors be liable for any direct, indirect, incidental, special
or consequential damages, including but not limited to accidental file deletion, data loss, application
or system malfunction, or business interruption, arising from the use, modification, building or
distribution of this source code (including versions modified or built by third parties), or from the
inability to use the software, even if advised of the possibility of such damages. You use this
software entirely at your own risk; if you do not agree, do not build, run or distribute it.
