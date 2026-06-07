#!/usr/bin/env bash
# SessionStart Hook：会话开始时注入项目专属提醒（分支、规则红线、耦合链、敏感文件跟踪检查）。
# 机制：返回 additionalContext，作为上下文提供给 Claude；不阻断、不修改任何文件。
set -euo pipefail

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0
command -v jq >/dev/null 2>&1 || exit 0

branch=$(git branch --show-current 2>/dev/null || echo '?')

# 检查本应「勿提交」的敏感文件是否已被 git 跟踪（.gitignore 未覆盖时的隐患）。
warn=""
for f in sign/repo.keystore prod.properties keystore.properties; do
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    warn="${warn}\n    ⚠️ ${f} 已被 git 跟踪——属敏感文件，建议从版本库移除并加入 .gitignore"
  fi
done

ctx="FastAndroid 会话提醒（来自项目 Hook，自动注入）：
- 当前分支：${branch}。分支由用户掌控，Claude 不自动新建/切换；commit/push 前需明确授权。
- 破坏性操作已被 Hook 拦截：reset --hard / clean -f / 强推 / 删分支删标签 / add 敏感文件。
- 耦合链改动需同步：home/HomeViewModel ↔ home/ArticleAdapter ↔ network/model/Article；改 libnetwork 的 model 通常要同步 calladapter + api。
- network/model/Article 是 Serializable，勿往里塞 lambda/回调（交互回调走 Adapter listener）。
- 新增代码用 Kotlin，不写 Java；改动保持最小范围，不借机重构或动公共主流程。
- 快速编译校验：./gradlew :app:assembleDebug -x lint -x test --no-daemon"

if [ -n "$warn" ]; then
  ctx="${ctx}
- 敏感文件跟踪检查：$(printf '%b' "$warn")"
fi

jq -n --arg c "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $c
  }
}'
exit 0
