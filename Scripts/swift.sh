#!/usr/bin/env bash
# 包装 `swift` 命令，绕过部分 Command Line Tools 升级后残留旧文件导致的两个问题。
# 不会修改系统文件；正常的 Xcode / Command Line Tools 环境下直接透传给 swift。
#
# 1. ManifestAPI 中残留旧版（Swift 5.10）的 PackageDescription.private.swiftinterface，
#    与新版 libPackageDescription.dylib 不匹配，任何 Package.swift 都无法链接。
#    → 在 .build/swiftpm-fix 中生成去掉该文件的副本，通过 SWIFTPM_CUSTOM_LIBS_DIR 使用。
#
# 2. usr/include/swift 下残留旧版 module.modulemap，与 bridging.modulemap 重复定义
#    SwiftBridging 模块，导致 Foundation 等系统模块无法构建。
#    → 通过 VFS overlay 把旧文件替换为空文件。
#
# 彻底解决：重新安装 Command Line Tools，或安装 Xcode 并执行 xcode-select -s。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT_BIN="$(xcrun --find swift)"
TOOLCHAIN_USR="$(cd "$(dirname "$SWIFT_BIN")/.." && pwd)"
PM_DIR="$TOOLCHAIN_USR/lib/swift/pm"
INCLUDE_DIR="$TOOLCHAIN_USR/include/swift"
FIX_DIR="$ROOT/.build/swiftpm-fix"
INTERFACE_DIR="$PM_DIR/ManifestAPI/PackageDescription.swiftmodule"

compiler_version() {
    sed -n 's|^// swift-compiler-version: ||p' "$1"
}

# 问题 1
if [[ -f "$INTERFACE_DIR/arm64-apple-macos.private.swiftinterface" && -f "$INTERFACE_DIR/arm64-apple-macos.swiftinterface" ]] &&
   [[ "$(compiler_version "$INTERFACE_DIR/arm64-apple-macos.private.swiftinterface")" != "$(compiler_version "$INTERFACE_DIR/arm64-apple-macos.swiftinterface")" ]]; then
    if [[ ! -d "$FIX_DIR/pm/ManifestAPI" ]]; then
        echo "▸ 检测到 Command Line Tools 残留旧版 PackageDescription 接口，使用修复副本" >&2
        mkdir -p "$FIX_DIR/pm"
        cp -R "$PM_DIR"/. "$FIX_DIR/pm"/
        rm -f "$FIX_DIR"/pm/ManifestAPI/PackageDescription.swiftmodule/*.private.swiftinterface
    fi
    export SWIFTPM_CUSTOM_LIBS_DIR="$FIX_DIR/pm"
fi

# 问题 2
EXTRA_ARGS=()
if [[ -f "$INCLUDE_DIR/module.modulemap" && -f "$INCLUDE_DIR/bridging.modulemap" ]]; then
    mkdir -p "$FIX_DIR"
    : > "$FIX_DIR/empty.modulemap"
    cat > "$FIX_DIR/overlay.yaml" <<EOF
{"version": 0, "case-sensitive": "false", "roots": [{"type": "directory", "name": "$INCLUDE_DIR", "contents": [{"type": "file", "name": "module.modulemap", "external-contents": "$FIX_DIR/empty.modulemap"}]}]}
EOF
    case "${1:-}" in
        build | test | run)
            EXTRA_ARGS=(-Xswiftc -vfsoverlay -Xswiftc "$FIX_DIR/overlay.yaml")
            ;;
    esac
fi

exec "$SWIFT_BIN" "$@" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
