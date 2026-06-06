#!/usr/bin/env bash
# PreToolUse(Bash) Hook：拦截破坏性 git 操作与误提交敏感文件。
# 依据：全局 common-rules「禁止 reset --hard / clean -fd / 强推 / 删分支删标签 / 重写公共历史」。
# 机制：命中即 permissionDecision=deny；其余命令一律放行。
set -euo pipefail

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# 压平连续空白，便于正则匹配（不改变 token 顺序）。
norm=$(printf '%s' "$cmd" | tr -s '[:space:]' ' ')

# 1) git reset --hard：丢弃工作区改动
printf '%s' "$norm" | grep -qiE 'git +reset +.*--hard' && \
  deny "拦截 git reset --hard：会丢弃工作区/暂存区改动，可能覆盖你未提交的工作。如确需，请人工执行。"

# 2) git clean -f*：删除未跟踪文件
printf '%s' "$norm" | grep -qiE 'git +clean +.*-[a-z]*f' && \
  deny "拦截 git clean -f*：会物理删除未跟踪文件。如确需，请人工执行。"

# 3) 强制推送 / 重写远端历史
printf '%s' "$norm" | grep -qiE 'git +push +.*(--force([^-]|$)|--force-with-lease|-[a-z]*f([ =]|$))' && \
  deny "拦截强制推送：禁止对远端强推或重写公共历史。"
printf '%s' "$norm" | grep -qiE 'git +push +.* \+[^ ]+:' && \
  deny "拦截 refspec 强推（push +src:dst）：会重写远端历史。"

# 4) 删除分支 / 标签 / 远端引用
printf '%s' "$norm" | grep -qiE 'git +branch +.*(-D|-d |--delete)' && \
  deny "拦截删除分支：分支由用户掌控。如确需，请人工执行。"
printf '%s' "$norm" | grep -qiE 'git +tag +(-d|--delete)' && \
  deny "拦截删除标签。如确需，请人工执行。"
printf '%s' "$norm" | grep -qiE 'git +push +.*--delete' && \
  deny "拦截删除远端引用（push --delete）。如确需，请人工执行。"

# 5) 误把敏感文件加入暂存（显式路径）
if printf '%s' "$norm" | grep -qiE 'git +add +'; then
  printf '%s' "$norm" | grep -qiE '(prod\.properties|keystore|\.jks|/sign/|(^| )\.env( |$))' && \
    deny "拦截 git add 敏感文件（keystore / *.properties / sign/ / .env）：勿入版本库。"
fi

exit 0
