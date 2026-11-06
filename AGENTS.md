# AGENTS.md

给参与本仓库的 AI 代理与协作进程阅读：项目进度、代码事实依据、主要功能、代码规范和引用资源。
面向使用者的说明见 [README.md](README.md)；两者冲突时以代码为准，并修正文档。
项目规范与进度统一维护在本文件；[CLAUDE.md](CLAUDE.md) 是 Claude 初始化时加载本文件的入口，仅保留引用与加载要求。

**快照时间：2026-11-05 17:57（UTC+8）。** 完成一项工作后，请更新「1. 当前进度」，不要只在对话里说明。

---

## 1. 当前进度

### 1.1 版本库状态

- 2026-11-05 资源审查结束时，`main` 和本地远程跟踪引用 `origin/main` 均为 `c06f9dd`。下表和 1.2 记录的是 11-03 的工作过程。
- 2026-11-03 改写过历史：原 `319b70a` 去掉 `Resources/Fonts/JiangxiZhuokai.ttf` 后成为 `22657f4`，代码改动不变；`bundled-zhuokai-font` 分支同步指向 `22657f4`。现在没有任何分支包含江西拙楷
- 其他工具（Codex）留下的引用 `refs/codex/turn-diffs/checkpoints/…` 里有一份含江西拙楷的目录快照，已按用户要求删除。现在所有引用都不再包含江西拙楷；旧对象只在本地 reflog 中，等 Git 自动清理。推送仍只推具体分支，不要用 `--all`、`--mirror`
- 远程：`origin` = `git@github.com:netflix-cn/orderly.git`
- 本地 `widget-week-calendar`、`bundled-zhuokai-font` 两个分支已快进合并进 `main`，可以删除

| 提交 | 内容 |
| --- | --- |
| `22657f4` | 界面与小组件统一改用江西拙楷（未推送）。不含字体文件，检出这个提交构建时需自行放入 `JiangxiZhuokai.ttf` |
| `13d024f` | 新增日历小组件，日期区改为本周居中的前后五周（未推送） |
| `e782865` | 新增小组件相关代码（Package.swift、打包脚本、README） |
| `020960c` | MIT 许可证与免责声明 |
| `8fba554` | 修复 UTF-8 locale 下的打包脚本，扩充 .gitignore |
| `91bfb9a` | 磁盘清理工具初始框架 |

### 1.2 工作区里未提交的改动

动手前先 `git status`，不要覆盖或回退这些改动。

| 改动 | 涉及文件 | 状态 |
| --- | --- | --- |
| 1Password 信息脱敏与本地配置 | `.signing.example.json`、Git 忽略的 `.signing.local.json`、`.gitignore`、`Scripts/sign-with-1password.sh`、`Makefile` 注释、README 与本文件；`Scripts/build-dmg.sh` 修正变量引用 | 完成；真实 ID 已迁移且权限为 600，可提交文件扫描通过，24 个模拟签名用例通过；直接 `make app-1password` 已完成真实签名打包及产物校验 |
| Claude 初始化入口与统一文档维护 | 新增 `CLAUDE.md`，引用 `AGENTS.md`；本文件说明统一维护规则；`README.md` 补充文档入口 | 完成，已核对引用路径与文档内容；仅文档改动，未运行测试 |
| **全局改用思源宋体半粗**，替换江西拙楷与 classic | 新增 `Resources/Fonts/NotoSerifSC-SemiBold.otf`、`NotoSerifSC-OFL.txt`；删除 `JiangxiZhuokai.ttf`（已 `git rm`）和 `imoon_tab.ttf`（未跟踪，已移到废纸篓）；两个 `BundledFont.swift` 只注册这一份字体；`CalendarWidgetView.swift` 统一用 `.app(size:)`，头部改为按基线定位；`build-app.sh` 复制 `Resources/Fonts` 下全部文件；`RootView.swift` 注释；预览页、`README.md`「字体」节 | 完成，测试通过；小组件与主界面已用 `ImageRenderer` 渲染核对；已打包安装 |
| 小组件所有日期同色，跨月日期不再变暗 | `CalendarWidgetView.swift` 去掉 `.opacity`；`WeekCalendar.swift` 删除 `CalendarDay.isInMonth`；`CalendarTests.swift` 删除对应断言；`README.md`「桌面小组件」节 | 完成，测试通过 |
| 小组件头部重排 | `CalendarWidgetView.swift` 的 `header` | 完成；换思源宋体后重新调整（见下） |
| 小组件上边距：日期区行高匀出 9pt 给顶部 | `CalendarWidgetView.swift`：新增 `Metrics.topPadding`，日期区行高由 53.6pt 变为约 51.8pt | 完成，本地渲染核对：内容离上边框 14.5pt、离下边框 14pt；已安装 |
| 用 1Password 里的 p12 签名 | 新增 `Scripts/sign-with-1password.sh`；`build-app.sh`、`build-dmg.sh` 支持 `SIGN_KEYCHAIN`；`Makefile` 新增 `app-1password`；`README.md` | 完成：13:13 用 1Password 签名打包成功，证书 SHA-1 与登录钥匙串里的 `Orderly Dev 2036` 相同；临时钥匙串已删除、钥匙串搜索列表不变 |
| 打包只允许从 1Password 取证书 | `AGENTS.md` 的 3.1、3.2、5 与 README | 用户 14:31 要求，约定已生效，README 已同步；`Makefile` 和打包脚本没有强制，`make app` 仍能读登录钥匙串 |
| App 图标 | 新增 `Scripts/generate-app-icon.swift`、`Resources/AppIcon.icns`；`Resources/Info.plist` 加 `CFBundleIconFile`；`build-app.sh` 复制图标；`Makefile` 新增 `app-icon`；`README.md` | 完成，已核对 16–1024 各尺寸和打包结果；已安装 |
| 小组件字体预览页 | 新增 `Tools/widget-font-preview.html`；`README.md` 目录结构 | 完成，已在浏览器里核对：12 款字体都能加载，缺字检查与本机字体检测结果一致；换字体后改为以思源宋体半粗为默认 |
| 换用 10 年期证书，打包时一并生成 dmg | 新增 `Scripts/build-dmg.sh`；`Makefile` 的 `app` 在打好 App 后生成 dmg；`README.md`「构建与运行」 | 完成，已安装 |
| 离线农历数据替换模拟数据 | 新增 `Scripts/generate-chinese-calendar.swift`、`Resources/Calendar/chinese-calendar.json`；`ChineseCalendar.swift` 改为 `BundledChineseCalendar` 并删除 `MockChineseCalendar`；`build-app.sh` 复制数据进扩展；`Makefile` 新增 `calendar-data`；`swift.sh` 支持直接运行脚本；`CalendarTests.swift`、`README.md` | 完成，测试通过；已安装 |

头部现在的排版：

- 月份、日期两块与右侧信息列用 `HStack(alignment: .lastTextBaseline)`，“11月”、农历行、干支行落在同一条基线上
- 这条基线固定在头部顶端以下 `Metrics.headerBaseline`（34pt）。思源宋体行高约为字号的 1.44 倍，原来的居中会把月份压到星期行上
- 日期行与农历行间距 `Metrics.dateLineSpacing`（-5.3pt），让日期行顶端与月份数字顶端齐平；右侧两行间距 `Metrics.infoLineSpacing`（-1.5pt）
- 干支行恢复为 `丙午·马年 戊戌月 庚辰日`：思源宋体的“·”是窄的
- 左侧两块加 `.fixedSize()`；右侧信息列加 `.lineLimit(1)` 和 `.minimumScaleFactor(0.8)`，放不下时缩小，不出现省略号
- 渲染核对：内容离上边框 14pt、离下边框 13pt；最宽的 12-28 右侧仍有约 12pt 空隙

### 1.3 已安装版本与验证情况

- `/Applications/Orderly.app` 于 2026-11-03 12:58 安装（12:50 打包），签名证书为 **`Orderly Dev 2036`**，含上表全部改动（App 图标、思源宋体半粗、离线农历数据、上边距、头部重排）
- 安装后 App 正常启动；12:58:33 用户点关闭按钮关掉了窗口，App 随之退出（最后一个窗口关闭即退出，不是崩溃）
- 12:02 那次换了证书，系统把它当成新 App：用户需要重新授予完全磁盘访问权限，桌面小组件不显示时要删掉重新添加
- 安装后小组件的时间线缓存已重新生成，引用的是 `NotoSerifSC-SemiBold`，干支行为“丙午·马年”格式；日志中没有字体或农历数据加载失败的记录
- 系统只登记 `/Applications/Orderly.app/Contents/PlugIns/OrderlyWidget.appex` 这一份小组件
- `build/Orderly-0.1.0.dmg`（2026-11-03 16:56，经本地配置加载、1Password 签名）：应用代码与已安装版本相同，签名要求一致，用 `Orderly Dev 2036` 签名，另有「应用程序」快捷方式。本次 App、扩展、dmg 严格签名校验及 dmg 完整性校验全部通过，小组件沙盒已启用；未替换已安装的 App
- `make test`：38 个测试全部通过
- 思源宋体版本只用 `ImageRenderer` 渲染核对过小组件和主界面首页，结果页等其他页面、桌面实机待用户核对。本机没有屏幕录制权限，`screencapture` 无法使用；只能用 `ImageRenderer` 渲染核对（见 3.5）
- 2026-11-03 16:32（UTC+8）重新加载项目上下文：已读取本文件、README、Package.swift、Makefile 与扫描清理、小组件的主要代码，核对 Git 状态和资源文件。当前仍为 `main` / `22657f4`，相对本地 `origin/main` 领先 2 个提交，工作区保留既有未提交改动；未联网核对远程。现有 dmg 文件存在；本次只更新本条进度记录和快照时间，没有修改代码、重新测试、打包或安装。上面的 38 个测试通过是此前记录。
- 2026-11-03 16:38（UTC+8）完成 1Password 信息提交风险审查：规范与签名脚本中未发现硬编码的实际密码、令牌或私钥；保险库/条目 ID 属于定位元数据，公开文档建议使用占位符并由本机环境变量提供实际值。已核对 `.gitignore` 覆盖 p12、私钥、钥匙串与 `.env`，当前 Git 跟踪列表中未发现这些类型的文件；未审计完整 Git 历史。脚本会清理临时证书和钥匙串，但密码作为 `security` 命令参数传递仍有本地运行时暴露风险。参照 [1Password 引用文档](https://www.1password.dev/cli/secret-references) 与 [CLI 授权模型](https://www.1password.dev/cli/app-integration-security) 核对；本次仅记录结论，尚未脱敏文档或修改脚本，未读取 1Password 实际凭据、运行测试或提交。
- 2026-11-03 16:58（UTC+8）完成 1Password 文档脱敏和本地配置迁移：移除真实保险库/条目 ID 与私人条目标题，增加只含占位符的模板；本机配置已忽略且未被 Git 跟踪。脚本增加 JSON 数据解析、环境覆盖和 `--check-config`，24 个模拟用例验证了错误提前失败、任意工作目录、参数传递、失败退出码与清理。真实打包发现 dmg 签名提示中的变量紧邻中文右括号，已改用 `${SIGN_IDENTITY}` 明确边界；重新完整打包并校验通过。默认沙盒内 CLI 连接桌面 App 失败，在允许桌面通信的权限下按原有 1Password 流程验证成功。README 已同步签名约定；本次未运行 Swift 测试、安装或提交，密码命令行参数的既有运行时风险仍在。

- 2026-11-05 已在本机 Codex 用户级技能目录安装 `ui-ux-pro-max`（上游提交 `b7d5353`），并用安装后的脚本验证了 SwiftUI 指南搜索和设计系统生成。
- 2026-11-05 用 `ui-ux-pro-max` 评审主 App，以示例容量和权限离屏渲染 1040×700 浅色首页和 900×620 深色首页，并核对扫描、授权、清理流程源码。建议优先明确废纸篓的永久清空操作，并在首页按授权状态展示实际扫描范围。此次仅记录评审，未更改应用代码或执行扫描、清理。
- 2026-11-05 审查 `c06f9dd` 及现有 `build/Orderly-0.1.0.dmg` 的第三方资源。主 App、扩展各附 Noto Serif SC SemiBold 与 OFL，均匹配上游 `Serif2.003`。DMG 内 App 的 13 个文件逐一匹配 `build/Orderly.app`。项目脚本生成的图标和日历 JSON 均逐字节复现。当前 Git 引用的可达历史只含 Noto 字体；旧 reflog 仍可找到江西拙楷。
  - 已确认 `ScanModels.swift` 将受限符号 `apple.logo` 用于「macOS 系统」分组。本机 macOS 15.8 的 `CoreGlyphs.bundle/Contents/Resources/symbol_restrictions.strings` 将此符号限定于「通过 Apple 登录」，发布前应替换。
  - 源码侧待核对或补充：字体预览页中霞鹜新致宋的 IPA 许可链接与原始字体替换指引；日历生成器中 Meeus 附录 III 所列成组系数的再分发依据。发布 App/DMG 未附项目自身的 MIT 许可。此次仅记录审查结果，未修改或重打发布包。

- 2026-11-05 完成主 App 首页和结果清理页优化。首页按当前权限列出扫描范围，磁盘条同时标注已用比例与可用容量，扫描按钮采用较深渐变和静止待机状态。现有废纸篓改为手动勾选；底栏区分预计释放与移入废纸篓的容量，确认框单列清空现有废纸篓的后果。结果页可直接打开系统设置，在当前进程内保留勾选和分组，用户可在权限生效后主动重扫。新增 2 个回归测试，`make test` 共 40 项通过；用示例数据在 900×620 深色和 1040×700 浅色窗口核对首页、结果底栏及原生确认框。未用真实文件清理、变更系统授权、重打包或替换安装版本。

- 2026-11-05 17:56 使用 `make app-1password` 构建本轮首页和结果清理页的手动验收包 `build/Orderly-0.1.0.dmg`（0.1.0 build 1，arm64，22,811,799 字节）。App、扩展和 DMG 均使用 `Orderly Dev 2036` 签名并通过严格校验。镜像完整性、扩展沙盒权限和 Applications 安装链接已核对，镜像内 App 的 13 个文件与本次构建逐一一致。SHA-256 为 `ccb30c52109277eab2c01e6bd651208a8b2afb326032dda814b449b5bd7914a9`。等待用户手动验收，未替换已安装的 App。

### 1.4 待办

1. 用户重新授予完全磁盘访问权限，必要时重新添加桌面小组件
2. 用户核对主界面各页、桌面小组件的字体效果和 App 图标
3. 离线数据只到 2027-12-31，2028 年前需重新生成（见 2.4）
4. 提交工作区改动：需用户明确要求后才做

---

## 2. 主要功能与代码依据

Swift Package（`Package.swift`，`swift-tools-version: 6.0`），没有 Xcode 工程。Target 如下：

| Target | 路径 | 产物 |
| --- | --- | --- |
| `Orderly` | `Sources/Orderly` | 主 App 可执行文件 |
| `OrderlyWidget` | `Sources/OrderlyWidget` | 小组件扩展。链接入口为 `_NSExtensionMain`，带 `-application-extension` |
| `OrderlyTests` | `Tests/OrderlyTests` | 主 App 测试 |
| `OrderlyWidgetTests` | `Tests/OrderlyWidgetTests` | 小组件测试 |

- 平台：仅 Apple 芯片 arm64，macOS 15.0 及以上
- 版本：`0.1.0 (1)`。扩展的版本号由打包脚本从 `Resources/Info.plist` 复制
- Bundle ID：主 App `com.orderly.Orderly`；小组件 `com.orderly.Orderly.Widget`
- 小组件 kind：`com.orderly.Orderly.Widget.Calendar`

### 2.1 主 App：磁盘清理

| 功能 | 代码依据 |
| --- | --- |
| 流程：授权 → 等待 → 扫描 → 结果 → 清理 → 完成 | `AppModel.Phase`（`Sources/Orderly/App/AppModel.swift`）；页面切换在 `RootView` |
| 完全磁盘访问权限检测 | `FullDiskAccess.isGranted` 尝试打开 TCC.db、Safari 书签等受保护文件；`openSystemSettings()` 引导开启 |
| 扫描引擎 | `ScanEngine.standard` 用 `withThrowingTaskGroup` 并发执行规则，按路径去重；没有权限时跳过 `requiresFullDiskAccess` 的规则 |
| 扫描规则 | `ScanRule` 协议（`Scanner/ScanRule.swift`），实现在 `Scanner/Rules/`。见下表 |
| 文件归属到 App | `AppCatalog`：按 bundle ID、进程名、文档位置把扫描项归到已安装 App、系统、残留（leftover）或其他 |
| 系统服务缓存保护 | `ScanPolicy.isProtectedCache`：iCloud、CloudKit、账户、家庭、家人共享等系统服务的缓存，以及 Orderly 自己的缓存，直接跳过 |
| 结果页 | `ScanResultsModel`：按应用 / 按类型分组，三态勾选；默认只勾推荐项，跳过所属 App 正在运行的项目。废纸篓由用户勾选；清理前区分永久清理、清空现有废纸篓和移到废纸篓 |
| 清理 | `Cleaner.clean`：逐项先过 `SafetyGuard.validate` 再执行 `CleanAction`（`.delete`、`.deleteContents`、`.moveToTrash`） |
| 删除前安全检查 | `SafetyGuard`：目标必须在个人目录内；不能是 `~/Library`、`~/Documents` 等关键目录本身；不能删除废纸篓目录本身；不清空符号链接 |
| 磁盘占用、配色 | `Support/Theme.swift`（`Theme`、`DiskUsage`） |
| 界面 | `Views/`：`PermissionView`、`HomeView`、`ScanningView`、`ResultsView`、`CleanViews`（`CleaningView`、`CleanSummaryView`）、`Components/Components.swift` |

扫描规则（`ScanEngine.standard` 的顺序）：

| 规则类型 | 位置 | 类别 | 清理方式 | 需要完全磁盘访问 |
| --- | --- | --- | --- | --- |
| `UserCachesRule` | `~/Library/Caches/*` | 应用缓存 | 清空目录 | |
| `ContainerCachesRule` | `~/Library/Containers/*/Data/Library/Caches` | 应用缓存 | 清空目录 | ✓ |
| `LogsRule` | `~/Library/Logs`、崩溃报告 | 系统垃圾 | 删除 | |
| `SavedApplicationStateRule` | `~/Library/Saved Application State` | 系统垃圾 | 删除 | |
| `DeveloperJunkRule` | DerivedData、模拟器缓存、设备支持文件 | 系统垃圾 | 清空目录 | |
| `TrashRule` | `~/.Trash` | 系统垃圾 | 清空 | ✓ |
| `InstallerPackagesRule` | `~/Downloads` 下的 dmg、pkg、mpkg、xip | 系统垃圾 | 移到废纸篓 | ✓ |
| `LargeFileRule` | 个人目录（不含 `~/Library`）中不小于 100 MB 的文件 | 大文件 | 移到废纸篓 | ✓ |

阈值在 `ScanConfiguration`：`largeFileThreshold` = 100 MB，`minimumItemSize` = 10 KB。

App **不启用沙盒**，见 `Resources/Orderly.entitlements`：需要读其他 App 的数据。签名时开启 Hardened Runtime。

### 2.2 小组件：大号日历

| 功能 | 代码依据 |
| --- | --- |
| 小组件定义 | `CalendarWidget`：只支持 `.systemLarge`，`.contentMarginsDisabled()`，背景为 `CalendarStyle.background` |
| 时间线 | `CalendarTimelineProvider.getTimeline`：当前时刻加之后 7 个零点，策略 `.atEnd` |
| 公历日期 | `SolarDate`（`WeekCalendar.swift`）：用儒略日数计算；`weekday` 0 为周日；`weekOfYear` 为 ISO 8601 周数；`zodiacSign` 为星座 |
| 五周排布 | `WeekCalendar`：周日开头共 5 行，本周固定在第 3 行（`surroundingWeeks = 2`）；`CalendarDay` 只有 `date` 和 `isToday` |
| 界面 | `CalendarWidgetView`：`header`、`weekdayRow`、`DayGrid`、`DayCell`、`MoonPhaseIcon` |
| 尺寸与配色 | `Metrics`：取自参考图，参考行高 53.6pt，按实际行高等比缩放；另加 `topPadding` 9pt，实际行高约 51.8pt。`CalendarStyle`：所有颜色 |
| 农历数据接口 | `ChineseCalendarSource` 协议：`lunarDay(for:)`、`ganZhi(for:)`，超出范围返回 nil |
| 农历数据 | `BundledChineseCalendar`：读取扩展包内 `Calendar/chinese-calendar.json`，按 `SolarDate` 建索引；`shared` 在首次使用时加载，失败时为空（不显示农历行和干支行）。数据见 2.4 |
| 字体注册 | `OrderlyWidgetBundle.init()` 调用 `BundledFont.register()`，从扩展包内的 `Resources/Fonts` 注册思源宋体半粗 |

小组件扩展**必须启用沙盒**（`Resources/OrderlyWidget.entitlements`），否则系统不会加载。

实机尺寸是 344×344pt、圆角 20，chronod 日志中记为 `systemLarge::344.00/344.00/20.00`。

### 2.4 离线农历数据

`Resources/Calendar/chinese-calendar.json` 由 `Scripts/generate-chinese-calendar.swift` 生成，覆盖公历 2026-01-01 至 2027-12-31。重新生成：

```bash
make calendar-data
make calendar-data CALENDAR_FROM=2026-01-01 CALENDAR_TO=2028-12-31
```

- 生成脚本只用 Foundation，不依赖系统农历。输出固定，重复生成结果逐字节相同
- 文件结构：
  - `solarTerms`：范围内的节气，北京时间到分钟
  - `moonPhases`：范围内的朔、上弦、望、下弦，北京时间到分钟
  - `days`：每天一行。字段为 `date`、`lunarYear`（以正月初一为界）、`lunarMonth`、`isLeapMonth`、`lunarMonthName`、`lunarMonthDays`、`lunarDay`、`lunarDayName`、`ganZhiYear`、`ganZhiMonth`、`ganZhiDay`、`zodiac`，当天有节气、月相时才带 `solarTerm`、`moonPhase`
- 算法：
  - 节气：VSOP87 地球日心坐标截断项求太阳视黄经，加 FK5 修正、章动、光行差，误差约半分钟
  - 月相：Meeus《天文算法》第 49 章，误差在 1 分钟以内
  - 时间换算：力学时减 ΔT（69 秒）为世界时，再加 8 小时为北京时间
  - 农历编排：按 GB/T 33661-2017。朔所在日为初一，含冬至的月为十一月；两个十一月之间有 13 个月时，第一个无中气的月置闰
- 约定：干支纪年和生肖以立春为界，干支纪月以「节」为界，日干支为 (儒略日数 + 49) mod 60；月名用正月 … 十月、冬月、腊月
- 节气或朔离北京时间零点不足 10 分钟时，脚本会打印警告，需人工核对日期。2026–2027 年有三处：雨水 2026-02-18 23:52、朔 2026-10-10 23:50、朔 2027-02-06 23:56，均已核对无误
- 已做的核对：
  - 2026、2027 年数据与香港天文台公历与农历日期对照表逐日一致，包括农历月日和节气日期
  - 测试 `matchesFoundationChineseCalendar` 与系统农历（ICU）逐日比对
  - 用 2025 年数据核对置闰：闰六月 2025-07-25 至 2025-08-22
- 星座、当年第几天、第几周由 `SolarDate` 计算，不进数据文件
- 生成其他年份时，按 IERS 公布值调整脚本里的 `deltaTSeconds`

### 2.5 字体

App 和小组件的全部文字只用一份字体：**思源宋体半粗**（Noto Serif SC SemiBold）。

| 文件 | PostScript 名 | 代码入口 |
| --- | --- | --- |
| `Resources/Fonts/NotoSerifSC-SemiBold.otf`（11.8 MB） | `NotoSerifSC-SemiBold` | 主 App：`Font.app(_:)`、`Font.app(size:)`（`Sources/Orderly/Support/BundledFont.swift`）；小组件：`CalendarWidgetView.swift` 里的 `Font.app(size:)` |

- 覆盖小组件和界面用到的全部字符，包括原来缺的“第、蝎、腊、处、惊、种、蛰”、空格、箭头和 `^`、`` ` ``、`\|`，不需要字体级联
- 度量：ascent 1.151 em，descent 0.286 em，行高约 1.44 em，大写字母高 0.729 em
- 字体都在进程内注册：`CTFontManagerRegisterFontsForURL(..., .process, ...)`，不安装、不联网
- `Scripts/build-app.sh` 把 `Resources/Fonts` 下全部文件（字体和 `NotoSerifSC-OFL.txt`）复制进 App 和扩展各一份。OFL 要求随字体附上许可证
- 用 `swift run` 直接运行可执行文件时找不到字体，会退回系统字体

### 2.6 App 图标

`Resources/AppIcon.icns` 由 `Scripts/generate-app-icon.swift` 用 CoreGraphics 绘制，不依赖设计稿：

- 画面：macOS 风格的连续圆角方底（超椭圆近似），青绿到蓝的对角渐变，与 `Theme.heroGradient` 同色；中间是带金属光泽和磁道的磁盘盘片、蓝色主轴，右上角三颗闪光表示“清理”。不含日历元素
- 画布与 macOS 模板一致：1024 画布，主体 824×824 居中，四周留白给阴影
- 16 到 1024 每个尺寸都按矢量重新绘制，再用 `iconutil` 合成 icns。调整图形时改脚本并运行 `make app-icon`，不要手改 icns
- 预览：`Scripts/swift.sh Scripts/generate-app-icon.swift <输出.icns> <预览.png>` 额外输出 1024 的 PNG
- `Resources/Info.plist` 的 `CFBundleIconFile` 为 `AppIcon`，`build-app.sh` 把它复制到 `Contents/Resources/`；小组件扩展不需要单独的图标

---

## 3. 构建、测试、安装

### 3.1 命令

```bash
make test                                    # 全部测试（Swift Testing）
make calendar-data                           # 重新生成离线农历数据（见 2.4）
make app-icon                                # 重新绘制 App 图标（见 2.6）
# release 版 build/Orderly.app 和 build/Orderly-<版本>.dmg，证书从 1Password 取（见 3.2）
make app-1password
# debug 版并启动，证书同样从 1Password 取
Scripts/sign-with-1password.sh make run
```

- **打包只允许从 1Password 取签名证书，一律用上面的 `make app-1password`，同时产出 `build/Orderly.app` 和 `build/Orderly-<版本>.dmg`。** 不要再用 `SIGN_IDENTITY=… make app`、`make debug-app`、`make run` 直接读登录钥匙串里的证书，也不要用 ad-hoc 签名（不设 `SIGN_IDENTITY`）打包。不签名的 `make build`、`make test` 不受影响
- dmg 一律输出到 `build/`，不要放到 `dist/` 或其他目录；交付时给出 dmg 路径。`make clean` 会连同 dmg 一起删除
- **一律通过 `Scripts/swift.sh` 调用 swift，不要直接运行 `swift`。** 本机的 Command Line Tools 有残留旧文件，直接运行时 Package.swift 无法链接，Foundation 也无法构建。脚本会生成 `.build/swiftpm-fix` 来绕过
- 运行单个 `.swift` 脚本时也通过它：`Scripts/swift.sh 脚本.swift 参数…`。脚本会自动把 overlay 选项放在脚本路径之前
- 本机只有 Command Line Tools，没有 Xcode：没有 `xcodebuild`、小组件预览和模拟器

### 3.2 签名

- **签名证书只从 1Password 取**（`make app-1password`，脚本 `Scripts/sign-with-1password.sh`）。`SIGN_IDENTITY`、`SIGN_KEYCHAIN` 只由这个脚本设置，不要手动指定：
  - 证书存放在用户的 1Password 文档条目或附件中，包含一个 `.p12` 文件和保存导出密码的隐藏字段。真实保险库与条目 ID 仅保存在仓库根目录的 `.signing.local.json`（Git 忽略、权限 `600`），分别使用 `OP_SIGN_VAULT`、`OP_SIGN_ITEM` 字段；文档与示例不记录实际 ID 或私人条目标题
  - 新检出首次配置：复制 `.signing.example.json` 为 `.signing.local.json`，填写两个实际的 26 位 ID，执行 `chmod 600 .signing.local.json`。脚本按自身位置定位仓库根目录并自动加载配置；本机已迁移完成，后续直接 `make app-1password`
  - 环境变量 `OP_SIGN_VAULT`、`OP_SIGN_ITEM` 非空时优先使用，缺少的值从 JSON 补齐；两个环境变量齐全时不读取本地文件。`OP_SIGN_CONFIG` 可指定其他 JSON 配置路径。配置只作为数据解析，不通过 `source` 或 `eval` 执行
  - `Scripts/sign-with-1password.sh --check-config` 只验证 ID 配置格式，不访问 1Password、不显示实际 ID。配置缺失、占位符、格式错误时在请求授权前失败；实际访问权限及 p12 内容仍需打包时验证
  - 流程：`op` 读条目结构（只取字段名和文件名）→ 取出 p12 → 导入随机密码的临时钥匙串 → 设置 `SIGN_IDENTITY`（SHA-1）和 `SIGN_KEYCHAIN` 后执行给定命令 → 退出时删除临时钥匙串和文件。`codesign --keychain` 只在临时钥匙串里找证书，不会和登录钥匙串里的同名证书混淆
  - 需要 1Password CLI（`op`，本机 2.40.0）和用户在 1Password 里的授权。脚本不打印 p12 密码；不要为了排查而输出字段值
  - **取不到证书时停下来告诉用户**（`op` 未安装或未登录、用户拒绝授权、条目里缺 p12 或密码字段等）。不要退回登录钥匙串的证书或 ad-hoc 签名，也不要为了绕过而改脚本
  - 浏览器里的 1Password 自动填写（Claude in Chrome 的凭据工具）只能往网页里填，不能用于签名
- 1Password 里的 p12 就是 `Orderly Dev 2036`，与 `/Applications` 现装版本的证书相同，签名要求不变，装上不需要重新授权
- 本机登录钥匙串里还有以下自签名证书，**只用于核对，不用于打包**。用户可以自行删掉其中的私钥，打包不受影响：

  | 名称 | SHA-1 | 有效期至 | 说明 |
  | --- | --- | --- | --- |
  | `Orderly Dev 2036` | `67675CAE…C480` | 2036-10-31 | 与 1Password 里的 p12 是同一张。没有设为「始终信任」，`security find-identity -v` 不列出它，但签名和 `codesign --verify` 正常 |
  | `Orderly Dev` | `7DC1DF04…5921` | 2027-11-02 | 旧证书，2026-11-03 12:02 换证书之前的版本用它签名；不再使用 |
  | `Orderly Dev 2026` | `B2A4D211…F8F3` | — | 用户创建证书时多出的一张，未使用 |

- 签名要求按“标识符 + 证书 SHA-1”记录（`certificate leaf = H"…"`）。换证书后系统当成新 App：要重新授予完全磁盘访问权限，小组件可能要重新添加
- 用 ad-hoc 签名时，每次构建签名都会变化：会丢失「完全磁盘访问权限」，小组件也可能不出现或不刷新。这也是不允许 ad-hoc 打包的原因
- 打包脚本先签扩展、再签 App，**不能用 `--deep`**：`--deep` 会给扩展套上 App 的 entitlements，扩展没有沙盒就不会被加载

### 3.3 替换已安装的 App

```bash
osascript -e 'tell application id "com.orderly.Orderly" to quit'
mv /Applications/Orderly.app ~/.Trash/Orderly-0.1.0-$(date +%Y%m%d-%H%M%S).app
ditto build/Orderly.app /Applications/Orderly.app
codesign --verify --strict /Applications/Orderly.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R /Applications/Orderly.app
pluginkit -a /Applications/Orderly.app/Contents/PlugIns/OrderlyWidget.appex
pkill -f "OrderlyWidget.appex/Contents/MacOS/OrderlyWidget$"
open /Applications/Orderly.app
```

- 只在用户要求时替换。旧版本移到废纸篓，不要直接删除
- 检查系统登记的是哪一份小组件：

  ```bash
  pluginkit -mAvvv -i com.orderly.Orderly.Widget
  ```

  如果出现 `build/` 下那一份，用 `pluginkit -r <路径>` 移除
- 桌面小组件仍显示旧画面时，让用户把小组件从桌面删掉再重新添加

### 3.4 小组件排查

- 系统缓存的时间线在：

  ```
  ~/Library/Containers/com.orderly.Orderly.Widget/Data/SystemData/com.apple.chrono/timelines/
  ```

  文件里有 UTF-8 明文，可以用 `strings` 或 Python 检查文案是否已更新
- 时间线文件按文件 URL 和 PostScript 名引用字体，**不含 `CTFont` 的级联列表**。字体缺的字在桌面上会由系统字体补；换字体时要选覆盖全部用字的字体，不要依赖级联
- 日志要用 `/usr/bin/log show`。zsh 有同名的 `log` 内建命令

### 3.5 界面核对方法

**换字体前先用预览页比较。** `Tools/widget-font-preview.html` 按 `Metrics`、`CalendarStyle` 和离线农历数据，用 HTML 模拟 344×344pt 的小组件：

- 可以分别选日历文字和其他文字的字体（默认都是现用的思源宋体半粗，读本地文件），也能载入本机字体文件；缺字与桌面一样由系统字体补
- 页面会检查每款字体缺哪些字，并把所有候选字体并排对比
- 候选字体有：现用的思源宋体半粗，开源的霞鹜文楷（含屏幕版）、思源宋体常规、霞鹜新致宋、朱雀仿宋、站酷小薇、马善政，系统的宋体-简、苹方
- 开源字体从 Google Fonts、jsDelivr 加载，需要联网
- 头部按 `Metrics.headerBaseline` 用脚本量出基线后定位，与 SwiftUI 的做法一致
- 页面要读 `../Resources` 下的字体和农历数据，必须通过本地服务打开。在仓库根目录运行：

  ```bash
  python3 -m http.server 8765 --bind 127.0.0.1
  ```

  然后访问 `http://localhost:8765/Tools/widget-font-preview.html`。直接双击打开时，浏览器不允许读取本地文件
- 应用内浏览器窗格的 `preview_start` 起不了这个服务：它的进程读不了「文稿」目录。需要在终端（或 Bash 后台任务）里启动
- 预览页是 HTML 近似，字形和行高与 SwiftUI 略有差别。定稿仍以下面的 `ImageRenderer` 渲染为准


本机不能截屏。需要看效果时，在 `Tests/OrderlyWidgetTests/` 临时加一个测试（主界面放在 `Tests/OrderlyTests/`，渲染 `HomeView()` 时注入 `.environment(AppModel())`），用 `ImageRenderer` 输出 PNG，看完**删除这个测试文件**：

```swift
// 临时：把小组件渲染成 PNG 供目测，验收后删除
@MainActor
struct RenderPreviewTmp {
    @Test func renderWidget() throws {
        guard let out = ProcessInfo.processInfo.environment["RENDER_OUT"] else { return }
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        CTFontManagerRegisterFontsForURL(root.appending(path: "Resources/Fonts/NotoSerifSC-SemiBold.otf") as CFURL, .process, nil)
        // 测试进程的 Bundle.main 里没有农历数据，要从仓库读取
        let source = try BundledChineseCalendar(data: Data(contentsOf: root.appending(path: "Resources/Calendar/chinese-calendar.json")))
        let view = CalendarWidgetView(today: SolarDate(year: 2026, month: 11, day: 2), source: source)
            .frame(width: 344, height: 344)
            .background(CalendarStyle.background)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let rep = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        try #require(rep.representation(using: .png, properties: [:])).write(to: URL(filePath: out))
    }
}
```

文件头还需要 `import AppKit`、`import SwiftUI`、`import Testing`、`@testable import OrderlyWidget`。

运行：

```bash
RENDER_OUT=<草稿目录>/widget.png Scripts/swift.sh test --filter RenderPreviewTmp
```

缺了 `RENDER_OUT` 时直接返回，所以即使忘了删除，也不会让全量测试崩溃。但仍然要删除。

---

## 4. 代码规范

### 4.1 通用

- Swift 6 语言模式，严格并发检查：
  - 模型和值类型标 `Sendable`
  - 界面状态用 `@MainActor @Observable final class`（`AppModel`、`ScanResultsModel`）
  - 跨线程的可变状态用 `Synchronization.Mutex`（`ScanProgressReporter`）
- 错误类型明确时用 typed throws，如 `SafetyGuard.validate(_:) throws(CleanError)`；错误文案放在 `LocalizedError.errorDescription`，中文
- 路径用 `URL.homeDirectory` 和 `appending(path:)`，不要拼接字符串
- 日志用 `os.Logger`，subsystem 为 `com.orderly.Orderly` 或 `com.orderly.Orderly.Widget`，按功能取 category（如 `fonts`）；只在失败时记录
- 注释用中文，说明“为什么”而不是“做了什么”。类型和关键成员用 `///`，与周围代码的注释密度保持一致
- 界面文案只有中文；`RootView` 把 locale 固定为 `zh_Hans_CN`
- 测试用 Swift Testing（`import Testing`、`@Test`、`#expect`、`#require`、参数化 `@Test(arguments:)`），不用 XCTest。涉及文件删除的测试在临时目录里模拟个人目录（见 `CleanerTests`）
- 在 `#expect` 里写 `allSatisfy(\.x)` 会报 “call can throw” 编译错误，改写成 `allSatisfy { $0.x }`

### 4.2 主 App 界面

- 文字字体一律用 `.font(.app(.title2))` 或 `.font(.app(size: 34))`。只有 SF Symbols 图标保留 `.font(.system(...))`
- 只打包了思源宋体半粗一个字重，`.bold()`、`.weight()` 不起作用，层级靠字号区分。原来的 `.headline` 改用 `.app(.title3)`
- `ContentUnavailableView`、`List` 的分组标题会套用自己的系统字体，需要直接在 `Text` 上指定 `.font(.app(...))`
- 菜单栏、窗口标题、工具栏分段控件、确认对话框和右键菜单由系统绘制，保持系统字体，不要尝试修改

### 4.3 小组件

- 文字用 `Text(verbatim:)`。**不要用 Text 插值拼接 Text**：插值进来的 Text 在小组件里不显示
- 文字一律用 `.app(size:)`（`CalendarWidgetView.swift` 里的 `private extension Font`）
- 颜色只在 `CalendarStyle` 里定义，尺寸只在 `Metrics` 里定义。不要在视图里写颜色值或魔法数
- 头部排版用基线对齐（`.lastTextBaseline`、`.firstTextBaseline`），位置用 `Metrics.headerBaseline` 等常量定，不要用 `.offset` 硬调
- 换字体时注意行高：不同字体的 ascent、descent 差别很大（classic 1.0 em、江西拙楷 1.31 em、思源宋体 1.44 em），要重新调 `dateLineSpacing`、`infoLineSpacing` 并渲染核对
- 修改 `Metrics`、`CalendarStyle` 或布局时，同步更新 `Tools/widget-font-preview.html` 里对应的 CSS 数值
- 新的农历数据实现 `ChineseCalendarSource`，通过 `CalendarWidgetView(today:source:)` 注入（默认为 `BundledChineseCalendar.shared`），不要改动视图来适配数据。修改数据格式时，生成脚本、`BundledChineseCalendar.Day` 和测试三处要一起改；不要手改 JSON，改脚本后重新生成

### 4.4 扫描与清理

- 新增扫描能力：实现 `ScanRule`，注册到 `ScanEngine.standard`，并补充测试
- 需要「下载」「文稿」或其他 App 容器时，声明 `requiresFullDiskAccess = true`
- 用户自己的文件（大文件、安装包）只能用 `.moveToTrash`；永久删除只用于缓存、日志等可重建的数据
- 所有删除都必须经过 `Cleaner`，也就是 `SafetyGuard`，不要在别处直接调用 `FileManager.removeItem`
- 所属 App 正在运行的项目默认不勾选

### 4.5 文档与 Git

- 行为或结构变化时同步更新 README（目录结构、字体、桌面小组件、扫描规则表）和本文件
- 只在用户明确要求时提交、推送：
  - 在 `main` 上时先建分支再提交；用户要求合并时，用 `git merge --ff-only` 快进合并回 `main`
  - 提交信息用中文：第一行是摘要，空一行后用 `- ` 列出要点，行宽约 80
  - 末尾加 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`（以当时系统给出的署名为准）
- 暂存时按文件列出，不要 `git add -A`，以免带入别人未完成的改动或构建产物
- 推送只推具体分支（`git push origin main`），不要用 `--all`、`--mirror`（见 1.1）

---

## 5. 协作约定

1. 开始前读本文件，运行 `git status`、`git log --oneline -5`，确认哪些改动属于别人
2. 同一组文件同一时间只有一个写入者。修改小组件头部、`BundledFont`、`build-app.sh` 前，先确认没有其他进程在改
3. 临时文件（渲染图、脚本）放在会话的草稿目录，不要放进仓库。临时测试用完即删
4. 用户说“打包”“build 一个包”时，执行 `make app-1password`（完整命令见 3.1），交付 `build/Orderly-<版本>.dmg`。证书只从 1Password 取；取不到时停下来问用户，不要换别的签名方式（见 3.2）
5. 替换 `/Applications/Orderly.app`、提交、推送、删除分支：都需要用户在对话中明确要求
6. 结束时更新「1. 当前进度」：改了什么、验证到哪一步、还有什么没做

---

## 6. 引用资源

### 6.1 字体

| 文件 | 来源 | 授权 |
| --- | --- | --- |
| `Resources/Fonts/NotoSerifSC-SemiBold.otf` | [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk) 的 `Serif/SubsetOTF/SC/NotoSerifSC-SemiBold.otf`，2026-11-03 下载，SHA-256 前缀 `517d9736` | SIL OFL 1.1，可随 App 分发；许可证 `Resources/Fonts/NotoSerifSC-OFL.txt`（同仓库 `Serif/LICENSE`）必须一起打包 |

已经不用的字体：

- **江西拙楷 2.0**（黄煜臣）：授权未确认。已从工作区删除，并已从提交历史中去掉（见 1.1），任何分支都不再包含它
- **classic**（`imoon_tab.ttf`，从「每日万年历」提取）：从未提交，已移到废纸篓

### 6.2 其他

- 预览页的开源候选字体：Google Fonts（Noto Serif SC、ZCOOL XiaoWei、Ma Shan Zheng），jsDelivr（lxgw-wenkai-webfont、lxgw-wenkai-screen-webfont、lxgw-neo-zhisong-webfont、@chinese-fonts/zqfs）
- 农历与天文算法：
  - GB/T 33661-2017《农历的编算和颁行》：编排规则
  - Jean Meeus《天文算法》：第 22 章章动、第 25 章太阳位置、第 49 章月相，附录 III 的 VSOP87 截断项
  - 香港天文台公历与农历日期对照表：只用于核对，不在仓库中
- 小组件的视觉参考图：`Metrics` 的尺寸、`CalendarStyle` 的颜色都取自用户提供的参考图。参考图**不在仓库中**
- Apple 框架：
  - SwiftUI、WidgetKit
  - CoreText：字体注册
  - AppKit：`NSWorkspace`、`NSPasteboard`
  - Synchronization：`Mutex`
  - os：`Logger`
- 系统工具：
  - `codesign`、`lipo`、`PlistBuddy`、`plutil`：打包
  - `hdiutil`：生成 dmg
  - `lsregister`、`pluginkit`：登记小组件
  - `/usr/bin/log`：日志
- 许可证：MIT（`LICENSE`），README 末尾有中英文免责声明。本软件会永久删除文件，修改清理逻辑时保持谨慎

---

## 7. 已知问题与限制

- 离线农历数据只覆盖 2026-01-01 至 2027-12-31，超出后不显示农历行和干支行，需要重新生成
- 思源宋体版本主界面各页和桌面小组件的实际效果待用户核对（见 1.3）
- App 包里字体各放一份，字体约占 23.5 MB
- 只扫描当前用户的个人目录，不处理 `/Library`、`/private/var` 等需要管理员权限的位置
- 还没有多语言和设置页；大文件阈值写在 `ScanConfiguration` 里
