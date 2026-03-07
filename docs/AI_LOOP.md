# FastAndroid AI 自动优化循环

这个机制把你要的流程串起来：

`AI发现问题 -> AI修复 -> AI写文档/测试/代码 -> AI重构 -> 再测试 -> 再修复 -> 通过后自动提交(可自动推送)`

核心脚本：`tools/ai_optimize_loop.sh`

## 1) 准备

- 本机已安装一个 AI CLI：`codex` / `claude` / `opencode`
- 项目根目录可执行 `gradlew`
- 你有仓库 push 权限（如果要开 `--auto-push`）

## 2) 一条命令启动循环

```bash
cd FastAndroid
chmod +x tools/ai_optimize_loop.sh

tools/ai_optimize_loop.sh \
  --agent codex \
  --iterations 20 \
  --check-cmd "./gradlew :app:assembleDebug -x lint -x test --no-daemon" \
  --agent-timeout 90 \
  --check-timeout 90 \
  --sleep 5 \
  --auto-push
```

## 3) 每一轮具体做什么

1. 先跑一次 `--check-cmd`，拿失败日志（发现问题）
2. 把日志喂给 AI，让 AI 做最小修复/改进（修复、写代码、写文档、重构）
3. 再跑一次 `--check-cmd`（自动测试）
4. 若通过并且有改动：自动 `git commit`
5. 如果加了 `--auto-push`：自动 `git push`
6. 进入下一轮

## 4) 为什么每轮能控制在 1-2 分钟

关键不是模型，而是 `--check-cmd` 的体量。建议分层：

- 快速轮（1-2分钟目标）：
  - `./gradlew :app:assembleDebug -x lint -x test --no-daemon`
  - 或更小的模块命令
- 慢速轮（质量兜底，单独跑）：
  - 全量单测
  - 全量 lint

你可以先跑 10~20 轮快速循环，再单独跑一次慢速校验。

## 5) 推荐参数模板

### 模板 A：高频小步快跑

```bash
tools/ai_optimize_loop.sh \
  --agent codex \
  --iterations 30 \
  --check-cmd "./gradlew :app:assembleDebug -x lint -x test --no-daemon" \
  --agent-timeout 75 \
  --check-timeout 75 \
  --sleep 3 \
  --auto-push
```

### 模板 B：通过即停（适合修一个明确问题）

```bash
tools/ai_optimize_loop.sh \
  --agent codex \
  --iterations 10 \
  --stop-on-pass \
  --check-cmd "./gradlew :app:testDebugUnitTest --no-daemon"
```

## 6) 安全边界

- 脚本在临时 worktree 中执行，不污染你当前工作目录
- 默认不 push，只有 `--auto-push` 才会推远端
- 默认每轮只在测试通过时提交，失败轮不提交

## 7) 常见问题

- **Q: 轮次里没改动怎么办？**
  - A: 脚本会继续下一轮，直到有有效改动或轮次结束。

- **Q: 我想看每轮日志？**
  - A: 在 worktree 的 `.ai-loop/` 下有 `precheck-*.log` 和 `postcheck-*.log`。

- **Q: 想复盘某轮 AI 提示词？**
  - A: 同目录有 `prompt-*.txt`。
