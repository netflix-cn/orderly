#!/usr/bin/env bash
# 构建 Orderly.app（仅 Apple 芯片 arm64）
#
# 用法：
#   Scripts/build-app.sh                 # release 构建，ad-hoc 签名
#   CONFIG=debug Scripts/build-app.sh    # debug 构建
#   SIGN_IDENTITY="Apple Development: Name (TEAMID)" Scripts/build-app.sh
#
# 注意：ad-hoc 签名的 App 每次重新构建后签名都会变化，
# 系统会把它当成新 App，需要重新授予「完全磁盘访问权限」。
# 日常开发建议设置 SIGN_IDENTITY 使用固定的开发者证书。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP_NAME="Orderly"
WIDGET_NAME="OrderlyWidget"
APP="$ROOT/build/$APP_NAME.app"
APPEX="$APP/Contents/PlugIns/$WIDGET_NAME.appex"

cd "$ROOT"

echo "▸ swift build ($CONFIG, arm64)"
"$ROOT/Scripts/swift.sh" build -c "$CONFIG" --arch arm64
BIN_DIR="$("$ROOT/Scripts/swift.sh" build -c "$CONFIG" --arch arm64 --show-bin-path)"

for product in "$APP_NAME" "$WIDGET_NAME"; do
    ARCHS="$(lipo -archs "$BIN_DIR/$product")"
    if [[ "$ARCHS" != "arm64" ]]; then
        echo "✗ $product 期望仅包含 arm64，实际为：$ARCHS" >&2
        exit 1
    fi
done

echo "▸ 组装 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# 小组件扩展
mkdir -p "$APPEX/Contents/MacOS"
cp "$BIN_DIR/$WIDGET_NAME" "$APPEX/Contents/MacOS/$WIDGET_NAME"
cp "$ROOT/Resources/$WIDGET_NAME-Info.plist" "$APPEX/Contents/Info.plist"
# 扩展的版本号必须与宿主 App 一致
for key in CFBundleShortVersionString CFBundleVersion; do
    value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$ROOT/Resources/Info.plist")"
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$APPEX/Contents/Info.plist"
done

# SwiftPM 生成的资源包（目前没有，预留）
for bundle in "$BIN_DIR"/*.bundle; do
    [[ -e "$bundle" ]] && cp -R "$bundle" "$APP/Contents/Resources/"
done

echo "▸ 签名（identity: ${SIGN_IDENTITY}）"
# 先签扩展再签 App。不能用 --deep：它会给扩展套上 App 的 entitlements，扩展没有沙盒就不会被加载
codesign --force --options runtime --timestamp=none \
    --entitlements "$ROOT/Resources/$WIDGET_NAME.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APPEX"
codesign --force --options runtime --timestamp=none \
    --entitlements "$ROOT/Resources/Orderly.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APP"

echo "✓ 已生成 $APP"
