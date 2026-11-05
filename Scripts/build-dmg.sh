#!/usr/bin/env bash
# 把 build/Orderly.app 做成 build/Orderly-<版本>.dmg：卷内放 App 和「应用程序」快捷方式，拖进去即可安装。
#
# make app 会在 Scripts/build-app.sh 之后自动调用；单独使用时先打好 App：
#   Scripts/build-dmg.sh
#   Scripts/sign-with-1password.sh Scripts/build-dmg.sh   # dmg 本身也从 1Password 取证书签名
#
# dmg 没有公证：在别的 Mac 上打开时 Gatekeeper 会拦截，需要在「隐私与安全性」里允许。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
KEYCHAIN_ARGS=()
[[ -n "${SIGN_KEYCHAIN:-}" ]] && KEYCHAIN_ARGS=(--keychain "$SIGN_KEYCHAIN")
APP="$ROOT/build/Orderly.app"

if [[ ! -d "$APP" ]]; then
    echo "✗ 没有 $APP，先运行 Scripts/build-app.sh" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
DMG="$ROOT/build/Orderly-$VERSION.dmg"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Orderly.app"
ln -s /Applications "$STAGING/Applications"

echo "▸ 生成 $DMG"
hdiutil create -quiet -ov -volname "Orderly $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO "$DMG"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    echo "▸ 签名 dmg（identity: ${SIGN_IDENTITY}）"
    codesign --force --timestamp=none --sign "$SIGN_IDENTITY" ${KEYCHAIN_ARGS[@]+"${KEYCHAIN_ARGS[@]}"} "$DMG"
fi

echo "✓ 已生成 $DMG"
