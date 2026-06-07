#!/usr/bin/env bash
# PreToolUse(Edit|Write) Hook：拒绝改动签名 / 密钥 / 本地配置等敏感文件。
# 依据：项目 CLAUDE.md「sign/、prod.properties、keystore 视为敏感，勿改勿提交」。
# 机制：命中即返回 permissionDecision=deny，阻断本次 Edit/Write。
set -euo pipefail

input=$(cat)

# 无 jq 时退化为「放行」，避免因环境缺工具卡死全部编辑（保护失效会在 SessionStart 另有提示）。
command -v jq >/dev/null 2>&1 || exit 0

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

# 敏感路径模式（大小写不敏感）：
#   *.properties 仅匹配 prod/local/keystore/signing 这几类敏感配置，普通 .properties 不拦；
#   sign/ 目录下任意文件；常见密钥 / 证书后缀；.env 系列。
if printf '%s' "$file_path" | grep -qiE '(^|/)(prod|local|keystore|signing)\.properties$|/sign/|\.(jks|keystore|p12|pfx|pem|key)$|(^|/)\.env(\.|$)'; then
  reason="拒绝改动敏感文件：${file_path}。该文件属签名/密钥/本地配置（见 CLAUDE.md「勿提交/勿改」）。如确需修改，请人工处理，或在 .claude/settings.local.json 临时禁用本 Hook。"
  jq -n --arg r "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
fi

exit 0
