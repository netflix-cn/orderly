.PHONY: build app app-1password debug-app run test calendar-data app-icon clean

# 小组件离线农历数据的公历范围
CALENDAR_FROM ?= 2026-01-01
CALENDAR_TO ?= 2027-12-31

# 仅编译（arm64）
build:
	Scripts/swift.sh build --arch arm64

# 打包 release 版 build/Orderly.app，并生成 build/Orderly-<版本>.dmg
app:
	Scripts/build-app.sh
	Scripts/build-dmg.sh

# 同 app，但签名证书从 1Password 取（自动读取 .signing.local.json，环境变量可覆盖）
app-1password:
	Scripts/sign-with-1password.sh $(MAKE) app

# 打包 debug 版 build/Orderly.app
debug-app:
	CONFIG=debug Scripts/build-app.sh

# 必须通过 .app 启动：用 `swift run` 启动时，权限归属于终端而非 Orderly
run: debug-app
	open build/Orderly.app

test:
	Scripts/swift.sh test

# 按天文算法重新生成小组件的离线农历数据，例如 make calendar-data CALENDAR_TO=2028-12-31
calendar-data:
	Scripts/swift.sh Scripts/generate-chinese-calendar.swift $(CALENDAR_FROM) $(CALENDAR_TO) Resources/Calendar/chinese-calendar.json

# 重新绘制 App 图标 Resources/AppIcon.icns
app-icon:
	Scripts/swift.sh Scripts/generate-app-icon.swift Resources/AppIcon.icns

clean:
	rm -rf .build build
