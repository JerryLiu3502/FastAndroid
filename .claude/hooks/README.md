# Claude Code Hooks（FastAndroid 项目级）

本目录下的 Hook 由 `.claude/settings.json` 装配，随仓库入库、团队共享。
所有脚本依赖 `jq`；缺少 `jq` 时一律「放行」（fail-open），不会卡死正常操作。

## 已装配的 Hook

| 脚本 | 事件 / 匹配 | 行为 | 依据 |
|------|------------|------|------|
| `protect-sensitive-files.sh` | PreToolUse · `Edit\|Write` | 命中签名/密钥/本地配置 → **deny** | CLAUDE.md「sign/、prod.properties、keystore 勿改勿提交」 |
| `guard-git.sh` | PreToolUse · `Bash` | 破坏性 git / add 敏感文件 → **deny** | 全局规则「禁止 reset --hard / clean -fd / 强推 / 删分支删标签」 |
| `kotlin-first.sh` | PreToolUse · `Write` | **新建** `.java` → **ask**（改现有 Java 放行） | 全局规则「Android 新代码用 Kotlin」 |
| `session-context.sh` | SessionStart | 注入分支/红线/耦合链/敏感文件跟踪检查 | 降低跑偏与误操作 |

### 匹配的敏感文件
`*/sign/*`、`*.jks` `*.keystore` `*.p12` `*.pfx` `*.pem` `*.key`、
`prod.properties` `local.properties` `keystore.properties`、`.env*`。
（普通 `gradle.properties` 等不拦。）

### guard-git 拦截清单
`git reset --hard`、`git clean -f*`、`git push --force/-f/--force-with-lease`、
refspec 强推（`push +src:dst`）、`git branch -D/-d/--delete`、`git tag -d`、
`git push --delete`、以及 `git add` 显式敏感路径。
正常的 `git add .` / `commit` / 普通 `push` / `reset HEAD <file>` 不受影响。

## 阻断机制
统一走 `permissionDecision`（stdout JSON），而非 `exit 2`：
```json
{ "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",        // 或 "ask"
    "permissionDecisionReason": "..." } }
```

## 本机临时关闭
不要改本文件来关。复制需要的键到**不入库**的 `.claude/settings.local.json`
覆盖，或把对应 `hooks` 项留空即可。

## 自测
```bash
export CLAUDE_PROJECT_DIR="$PWD"
echo '{"tool_input":{"file_path":"/x/sign/a.keystore"}}' | .claude/hooks/protect-sensitive-files.sh
echo '{"tool_input":{"command":"git reset --hard"}}'     | .claude/hooks/guard-git.sh
echo '{"tool_input":{"file_path":"/x/New.java"}}'        | .claude/hooks/kotlin-first.sh
.claude/hooks/session-context.sh </dev/null | jq .
```

> 已知联动：`session-context.sh` 启动时若发现 `sign/repo.keystore` 等敏感文件**已被 git 跟踪**会告警——
> 当前 `.gitignore` 仅忽略 `local.properties`，未覆盖 `sign/`、`*.keystore`，建议补全。
