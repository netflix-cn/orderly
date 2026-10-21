.PHONY: build app debug-app run test clean

# 仅编译（arm64）
build:
	Scripts/swift.sh build --arch arm64

# 打包 release 版 build/Orderly.app
app:
	Scripts/build-app.sh

# 打包 debug 版 build/Orderly.app
debug-app:
	CONFIG=debug Scripts/build-app.sh

# 必须通过 .app 启动：用 `swift run` 启动时，权限归属于终端而非 Orderly
run: debug-app
	open build/Orderly.app

test:
	Scripts/swift.sh test

clean:
	rm -rf .build build
