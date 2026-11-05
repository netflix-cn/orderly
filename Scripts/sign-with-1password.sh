#!/usr/bin/env bash
# 用 1Password 里保存的 p12 签名：取出证书导入临时钥匙串，设置 SIGN_IDENTITY、SIGN_KEYCHAIN 后执行给定命令，
# 结束（包括失败）时删除临时钥匙串和临时文件。私钥不需要常驻登录钥匙串。
#
# 用法：
#   复制 .signing.example.json 为 .signing.local.json，填入实际 ID（本地文件不提交）
#   make app-1password
#   Scripts/sign-with-1password.sh --check-config
#   OP_SIGN_VAULT=<保险库 ID> OP_SIGN_ITEM=<条目 ID> Scripts/sign-with-1password.sh make app
#
# 条目里需要一个 .p12 文件（「文档」条目本身或附件）和一个隐藏字段保存 p12 的密码。
# 需要 1Password CLI（op）及有效授权；授权可能在会话内复用。p12 密码只在 op 与 security 之间传递，不打印。
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "用法：$0 <命令…> 或 $0 --check-config（配置见 .signing.example.json）" >&2
    exit 2
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGN_CONFIG="${OP_SIGN_CONFIG:-$ROOT/.signing.local.json}"
# JSON 仅作为数据读取；环境变量优先，不执行配置中的任何代码，也不回显实际 ID。
SIGN_CONFIG_VALUES="$(python3 -I - "$SIGN_CONFIG" <<'PY'
import json
import os
import re
import sys

keys = ("OP_SIGN_VAULT", "OP_SIGN_ITEM")
config = {}
if not all(os.environ.get(key) for key in keys):
    try:
        with open(sys.argv[1], encoding="utf-8") as file:
            config = json.load(file)
    except FileNotFoundError:
        sys.exit("✗ 缺少本地签名配置：请复制 .signing.example.json 为 .signing.local.json 并填写 ID，或设置 OP_SIGN_VAULT、OP_SIGN_ITEM")
    except (OSError, ValueError):
        sys.exit("✗ 无法读取本地签名配置，请检查文件权限与 JSON 格式")
    if not isinstance(config, dict):
        sys.exit("✗ 本地签名配置必须是 JSON 对象")

values = []
for key in keys:
    value = os.environ.get(key) or config.get(key)
    if not isinstance(value, str) or not re.fullmatch(r"[a-z0-9]{26}", value):
        sys.exit(f"✗ {key} 必须填写实际的 26 位 1Password ID（不能使用模板占位符）")
    values.append(value)
print("\n".join(values))
PY
)"
export OP_SIGN_VAULT="${SIGN_CONFIG_VALUES%%$'\n'*}"
export OP_SIGN_ITEM="${SIGN_CONFIG_VALUES#*$'\n'}"
unset SIGN_CONFIG_VALUES

if [[ "$1" == "--check-config" ]]; then
    [[ $# -eq 1 ]] || { echo "✗ --check-config 不接受其他参数" >&2; exit 2; }
    echo "✓ 1Password 签名配置有效（未访问 1Password）"
    exit 0
fi
command -v op >/dev/null || { echo "✗ 需要 1Password CLI（op）" >&2; exit 1; }

WORK="$(mktemp -d)"
KEYCHAIN="$WORK/signing.keychain-db"
cleanup() {
    security delete-keychain "$KEYCHAIN" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

# 从条目结构里找出 p12 的取法和密码字段：只输出名称和 ID，不输出任何字段值
META="$(
    op item get "$OP_SIGN_ITEM" --vault "$OP_SIGN_VAULT" --format json | python3 -I -c '
import json, sys
item = json.load(sys.stdin)
p12 = next((f["name"] for f in item.get("files", []) if f.get("name", "").lower().endswith(".p12")), "")
password = next((f["id"] for f in item.get("fields", [])
                 if f.get("type") == "CONCEALED" and (f.get("purpose") == "PASSWORD" or f.get("label", "").lower() in ("password", "密码"))), "")
if not p12 or not password:
    sys.exit("条目里没有 .p12 文件或密码字段")
print(item.get("category", ""), p12.replace(" ", "%20"), password)
'
)"
read -r CATEGORY P12_NAME PASSWORD_FIELD <<< "$META"
P12_NAME="${P12_NAME//%20/ }"

echo "▸ 从 1Password 取出 $P12_NAME"
if [[ "$CATEGORY" == "DOCUMENT" ]]; then
    op document get "$OP_SIGN_ITEM" --vault "$OP_SIGN_VAULT" --out-file "$WORK/identity.p12" >/dev/null
else
    op read --out-file "$WORK/identity.p12" "op://$OP_SIGN_VAULT/$OP_SIGN_ITEM/$P12_NAME" >/dev/null
fi

# 临时钥匙串的密码随机生成，只在本次运行中使用
KEYCHAIN_PASSWORD="$(openssl rand -hex 24)"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 900 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$WORK/identity.p12" -k "$KEYCHAIN" -f pkcs12 -T /usr/bin/codesign \
    -P "$(op read "op://$OP_SIGN_VAULT/$OP_SIGN_ITEM/$PASSWORD_FIELD")" >/dev/null
rm -f "$WORK/identity.p12"
# 允许 codesign 使用私钥而不弹窗
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null

# 自签名证书未被信任，不能用 -v；按 SHA-1 指定证书，避免与登录钥匙串里的同名证书混淆
IDENTITY="$(security find-identity -p codesigning "$KEYCHAIN" | awk '/^ *1\) [0-9A-F]{40}/ { print $2; exit }')"
if [[ -z "$IDENTITY" ]]; then
    echo "✗ p12 里没有可用于代码签名的证书" >&2
    exit 1
fi
echo "▸ 临时钥匙串中的签名证书：$IDENTITY"

SIGN_IDENTITY="$IDENTITY" SIGN_KEYCHAIN="$KEYCHAIN" "$@"
