#!/usr/bin/env bash
# Hook 回归自测：对四个 Hook 做断言式验证。
# 用法：bash .claude/hooks/test.sh   （需要 jq；任一断言失败则整体非零退出）
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CLAUDE_PROJECT_DIR="$(cd "$HOOK_DIR/../.." && pwd)"

fail=0
pass(){ printf '  ✅ %s\n' "$1"; }
bad(){ printf '  ❌ %s\n' "$1"; fail=1; }

# 断言某 Hook 对给定输入「拦截」(deny) 或「放行」(空/非 deny)。
# $1 脚本 $2 stdin-json $3 expect(deny|allow|ask) $4 说明
expect(){
  local out; out=$(printf '%s' "$2" | "$HOOK_DIR/$1")
  case "$3" in
    deny)  echo "$out" | grep -q '"permissionDecision": "deny"'  && pass "$4" || bad "$4 → 期望 deny，得：${out:-<空>}" ;;
    ask)   echo "$out" | grep -q '"permissionDecision": "ask"'   && pass "$4" || bad "$4 → 期望 ask，得：${out:-<空>}" ;;
    allow) [ -z "$out" ] && pass "$4" || bad "$4 → 期望放行，得：$out" ;;
  esac
}
bash_json(){ jq -nc --arg c "$1" '{tool_input:{command:$c}}'; }
file_json(){ jq -nc --arg f "$1" '{tool_input:{file_path:$f}}'; }

echo "== guard-git：破坏性操作应 deny =="
expect guard-git.sh "$(bash_json 'git reset --hard HEAD~1')"                deny "reset --hard"
expect guard-git.sh "$(bash_json 'git clean -fd')"                          deny "clean -fd"
expect guard-git.sh "$(bash_json 'git push -f origin master')"              deny "push -f"
expect guard-git.sh "$(bash_json 'git push --force-with-lease')"            deny "push --force-with-lease"
expect guard-git.sh "$(bash_json 'git branch -D feat')"                     deny "branch -D"
expect guard-git.sh "$(bash_json 'git tag -d v1')"                          deny "tag -d"
expect guard-git.sh "$(bash_json 'git push origin --delete feat')"          deny "push --delete"
expect guard-git.sh "$(bash_json 'git add prod.properties')"                deny "add 敏感文件"

echo "== guard-git：全局选项绕过回归（不得放行）=="
expect guard-git.sh "$(bash_json 'git -C /tmp/repo reset --hard')"                       deny "git -C <path> reset --hard"
expect guard-git.sh "$(bash_json 'git --git-dir=.git --work-tree=. reset --hard')"       deny "git --git-dir/--work-tree reset --hard"
expect guard-git.sh "$(bash_json 'git -c core.editor=vim clean -fdx')"                    deny "git -c k=v clean -fdx"
expect guard-git.sh "$(bash_json 'git --no-pager branch -D feat')"                        deny "git --no-pager branch -D"

echo "== guard-git：正常操作应放行 =="
expect guard-git.sh "$(bash_json 'git status')"                             allow "status"
expect guard-git.sh "$(bash_json 'git add .')"                              allow "add ."
expect guard-git.sh "$(bash_json 'git commit -m x')"                        allow "commit"
expect guard-git.sh "$(bash_json 'git push origin feature_x')"             allow "普通 push"
expect guard-git.sh "$(bash_json 'git reset HEAD foo')"                     allow "reset（非 --hard）"
expect guard-git.sh "$(bash_json 'git -C /tmp/repo status')"               allow "git -C <path> status"

echo "== protect-sensitive-files：敏感文件应 deny =="
expect protect-sensitive-files.sh "$(file_json '/x/sign/repo.keystore')"   deny "sign/repo.keystore"
expect protect-sensitive-files.sh "$(file_json '/x/prod.properties')"      deny "prod.properties"
expect protect-sensitive-files.sh "$(file_json 'SIGN/Repo.KEYSTORE')"      deny "大小写变体"
expect protect-sensitive-files.sh "$(file_json '/x/app/../sign/a')"        deny "相对路径穿越到 sign/"
echo "== protect-sensitive-files：普通文件应放行 =="
expect protect-sensitive-files.sh "$(file_json '/x/app/Foo.kt')"           allow "普通 .kt"
expect protect-sensitive-files.sh "$(file_json '/x/gradle.properties')"    allow "gradle.properties"

echo "== kotlin-first：新建 .java → ask；现有 .java/.kt → 放行 =="
expect kotlin-first.sh "$(file_json '/no/such/dir/NewThing.java')"          ask   "新建 .java"
expect kotlin-first.sh "$(file_json '/no/such/dir/NewThing.kt')"            allow "新建 .kt"
existing=$(git -C "$CLAUDE_PROJECT_DIR" ls-files '*.java' 2>/dev/null | head -1 || true)
if [ -n "${existing:-}" ]; then
  abs="$CLAUDE_PROJECT_DIR/$existing"
  expect kotlin-first.sh "$(file_json "$abs")" allow "modify existing .java: $existing"
fi

echo "== session-context：输出合法 JSON 且含 additionalContext =="
out=$("$HOOK_DIR/session-context.sh" </dev/null)
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1 \
  && pass "additionalContext 存在且 JSON 合法" || bad "session-context 输出异常：$out"

echo ""
[ "$fail" = 0 ] && echo "全部通过 ✅" || echo "存在失败用例 ❌"
exit "$fail"
