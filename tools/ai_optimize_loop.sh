#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
AI optimize loop for FastAndroid (or any git repo).

Usage:
  tools/ai_optimize_loop.sh [options]

Options:
  --repo <path>               Source repo path (default: current dir)
  --agent <codex|claude|opencode>  AI CLI (default: codex)
  --base-branch <name>        Base branch to start from (default: current branch)
  --work-branch <name>        Work branch name (default: ai/optimize-YYYYmmdd-HHMMSS)
  --iterations <n>            Loop count (default: 10)
  --check-cmd <cmd>           Validation command (default: ./gradlew :app:assembleDebug -x lint -x test --no-daemon)
  --agent-timeout <sec>       Per-agent timeout seconds (default: 90)
  --check-timeout <sec>       Per-check timeout seconds (default: 90)
  --sleep <sec>               Sleep between rounds (default: 5)
  --auto-push                 Push commit after each successful round
  --no-auto-push              Disable auto push (default)
  --stop-on-pass              Stop when a round passes checks and commits
  --keep-worktree             Keep temp worktree (default removes it)
  --dry-run                   Print commands without executing AI step
  -h, --help                  Show this help

Examples:
  tools/ai_optimize_loop.sh \
    --iterations 20 \
    --agent codex \
    --check-cmd "./gradlew :app:assembleDebug -x lint -x test --no-daemon" \
    --auto-push

  tools/ai_optimize_loop.sh \
    --agent claude \
    --check-cmd "./gradlew :app:testDebugUnitTest --no-daemon" \
    --stop-on-pass
EOF
}

REPO="$(pwd)"
AGENT="codex"
BASE_BRANCH=""
WORK_BRANCH=""
ITERATIONS=10
CHECK_CMD="./gradlew :app:assembleDebug -x lint -x test --no-daemon"
AGENT_TIMEOUT=90
CHECK_TIMEOUT=90
SLEEP_SEC=5
AUTO_PUSH=0
STOP_ON_PASS=0
KEEP_WORKTREE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --base-branch) BASE_BRANCH="$2"; shift 2 ;;
    --work-branch) WORK_BRANCH="$2"; shift 2 ;;
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --check-cmd) CHECK_CMD="$2"; shift 2 ;;
    --agent-timeout) AGENT_TIMEOUT="$2"; shift 2 ;;
    --check-timeout) CHECK_TIMEOUT="$2"; shift 2 ;;
    --sleep) SLEEP_SEC="$2"; shift 2 ;;
    --auto-push) AUTO_PUSH=1; shift ;;
    --no-auto-push) AUTO_PUSH=0; shift ;;
    --stop-on-pass) STOP_ON_PASS=1; shift ;;
    --keep-worktree) KEEP_WORKTREE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

REPO="$(cd "$REPO" && pwd)"
if ! git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[ERROR] --repo is not a git repository: $REPO"
  exit 1
fi

if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
fi
if [[ -z "$WORK_BRANCH" ]]; then
  WORK_BRANCH="ai/optimize-$(date +%Y%m%d-%H%M%S)"
fi

WORKTREE="/tmp/fastandroid-ai-loop-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$(dirname "$WORKTREE")"

echo "[INFO] Repo        : $REPO"
echo "[INFO] Agent       : $AGENT"
echo "[INFO] Base branch : $BASE_BRANCH"
echo "[INFO] Work branch : $WORK_BRANCH"
echo "[INFO] Worktree    : $WORKTREE"
echo "[INFO] Check cmd   : $CHECK_CMD"

if git -C "$REPO" worktree list | awk '{print $1}' | grep -q "^$WORKTREE$"; then
  echo "[WARN] Worktree already exists: $WORKTREE"
else
  git -C "$REPO" fetch --all --prune || true
  git -C "$REPO" worktree add -B "$WORK_BRANCH" "$WORKTREE" "$BASE_BRANCH"
fi

cleanup() {
  if [[ "$KEEP_WORKTREE" -eq 0 ]]; then
    git -C "$REPO" worktree remove "$WORKTREE" --force >/dev/null 2>&1 || true
  else
    echo "[INFO] keep-worktree enabled: $WORKTREE"
  fi
}
trap cleanup EXIT

run_with_timeout() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    python3 - "$secs" "$@" <<'PY'
import subprocess
import sys

timeout_sec = int(float(sys.argv[1]))
cmd = sys.argv[2:]
try:
    result = subprocess.run(cmd, timeout=timeout_sec)
    raise SystemExit(result.returncode)
except subprocess.TimeoutExpired:
    raise SystemExit(124)
PY
  fi
}

run_agent() {
  local prompt_file="$1"
  case "$AGENT" in
    codex)
      run_with_timeout "$AGENT_TIMEOUT" codex exec --full-auto "$(cat "$prompt_file")"
      ;;
    claude)
      run_with_timeout "$AGENT_TIMEOUT" claude "$(cat "$prompt_file")"
      ;;
    opencode)
      run_with_timeout "$AGENT_TIMEOUT" opencode run "$(cat "$prompt_file")"
      ;;
    *)
      echo "[ERROR] Unsupported agent: $AGENT"
      return 2
      ;;
  esac
}

cd "$WORKTREE"
mkdir -p .ai-loop

EXCLUDE_FILE="$(git rev-parse --git-path info/exclude)"
touch "$EXCLUDE_FILE"
for pattern in ".ai-loop/" ".gradle-home/" ".gradle-user/"; do
  if ! grep -qxF "$pattern" "$EXCLUDE_FILE"; then
    echo "$pattern" >> "$EXCLUDE_FILE"
  fi
done

for ((i=1; i<=ITERATIONS; i++)); do
  echo ""
  echo "================ ROUND $i/$ITERATIONS ================"

  PRE_LOG=".ai-loop/precheck-${i}.log"
  POST_LOG=".ai-loop/postcheck-${i}.log"
  PROMPT=".ai-loop/prompt-${i}.txt"

  set +e
  run_with_timeout "$CHECK_TIMEOUT" bash -lc "$CHECK_CMD" >"$PRE_LOG" 2>&1
  PRE_STATUS=$?
  set -e

  {
    echo "You are optimizing an Android repository in iterative mode."
    echo ""
    echo "Hard requirements for this round:"
    echo "1) Discover the most important current issue from check output."
    echo "2) Apply minimal code/doc/test/refactor changes to improve quality."
    echo "3) Keep changes small and safe."
    echo "4) If there is no failing check, still do one small improvement (docs/refactor/test)."
    echo "5) Do NOT edit unrelated files."
    echo ""
    echo "Repository: $(pwd)"
    echo "Round: $i"
    echo "Current branch: $(git rev-parse --abbrev-ref HEAD)"
    echo ""
    echo "Pre-check command: $CHECK_CMD"
    echo "Pre-check exit code: $PRE_STATUS"
    echo ""
    echo "Pre-check output (tail 120 lines):"
    tail -n 120 "$PRE_LOG" || true
    echo ""
    echo "After edits, stop. Do not run git commit/push yourself."
  } > "$PROMPT"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY] Skip AI run. Prompt file: $PROMPT"
  else
    set +e
    run_agent "$PROMPT"
    AGENT_STATUS=$?
    set -e
    echo "[INFO] Agent exit code: $AGENT_STATUS"
  fi

  set +e
  run_with_timeout "$CHECK_TIMEOUT" bash -lc "$CHECK_CMD" >"$POST_LOG" 2>&1
  POST_STATUS=$?
  set -e

  echo "[INFO] Pre-check status : $PRE_STATUS"
  echo "[INFO] Post-check status: $POST_STATUS"

  if ! git diff --quiet || ! git diff --cached --quiet; then
    if [[ "$POST_STATUS" -eq 0 ]]; then
      git add -A
      git commit -m "chore(ai-loop): round $i pass checks"
      echo "[INFO] Committed round $i"
      if [[ "$AUTO_PUSH" -eq 1 ]]; then
        git push -u origin "$WORK_BRANCH"
        echo "[INFO] Pushed: $WORK_BRANCH"
      fi
      if [[ "$STOP_ON_PASS" -eq 1 ]]; then
        echo "[INFO] stop-on-pass enabled, exiting."
        break
      fi
    else
      echo "[WARN] Checks failed after round $i, skip commit."
      echo "[WARN] Tail post-check log:"
      tail -n 40 "$POST_LOG" || true
    fi
  else
    echo "[INFO] No file changes in round $i"
  fi

  sleep "$SLEEP_SEC"
done

echo ""
echo "[DONE] Loop completed."
echo "[DONE] Branch: $WORK_BRANCH"
if [[ "$KEEP_WORKTREE" -eq 1 ]]; then
  echo "[DONE] Worktree kept at: $WORKTREE"
fi
