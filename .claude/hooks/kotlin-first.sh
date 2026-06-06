#!/usr/bin/env bash
# PreToolUse(Write) Hook：新建 .java 文件时提示改用 Kotlin（Android 项目规则）。
# 依据：全局规则「Android 项目一律用 Kotlin 写新代码；现有 Java 除非明确要求不主动改写」。
# 机制：仅对「新建」.java 返回 permissionDecision=ask（交你确认）；修改已存在的 .java 放行。
set -euo pipefail

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

# 只关心 .java
case "$file_path" in
  *.java) ;;
  *) exit 0 ;;
esac

# 已存在 = 修改现有 Java，放行（符合「现有 Java 不主动改写但配套修改可用 Kotlin/Java」）。
[ -f "$file_path" ] && exit 0

reason="本项目规则：新增 Android 代码一律用 Kotlin，不写 Java（见 CLAUDE.md 与全局规则）。建议改为创建对应的 .kt 文件。如确有理由必须用 Java，请确认放行。"
jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: $r
  }
}'
exit 0
