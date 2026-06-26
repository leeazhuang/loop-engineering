#!/usr/bin/env bash
# gate-stop.sh —— 全绿硬门 (Stop hook)
# 按 PROJECT_MODE 决定跑哪侧：frontend=只前端 / backend=只后端 / fullstack=两侧都跑(都得绿)。
# 配置全部来自 .claude/loop.env（不要在本文件里改命令）。
#
# 退出码：0 = 放行；2 = 阻断并把 stderr 反馈给模型，让它继续修。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$SCRIPT_DIR/../loop.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

# 在哪棵树上跑全绿门？本圈改动在 git worktree 里（见 loop-implement），不在主仓库工作树。
# loop-implement 开 worktree 时会把其绝对路径写进 .claude/memory/current-worktree。
# 有它且指向有效目录 → 进 worktree 验本圈改动（门才守在改动上）；否则退回主仓库根（体检主分支基线）。
WT_FILE="$SCRIPT_DIR/../memory/current-worktree"
PROJECT_ROOT="$MAIN_ROOT"
if [ -f "$WT_FILE" ]; then
  WT="$(head -n1 "$WT_FILE" 2>/dev/null | tr -d '\r')"   # 去 Windows \r，不动路径里的空格
  if [ -n "$WT" ] && [ -d "$WT" ]; then
    PROJECT_ROOT="$WT"
    echo "[gate-stop] 在当前 worktree 上验证本圈改动：$WT" >&2
  else
    echo "[gate-stop] ⚠ current-worktree 记录无效（'$WT'），退回主仓库根验证。" >&2
  fi
fi

fail() {
  echo "[gate-stop] 阻断收尾：$1 未通过。请修复后再收尾，不要绕过本门。" >&2
  exit 2
}

# 跑某一侧的 test/lint/build。参数: 名称 目录 测试 lint 构建
run_side() {
  local name="$1" dir="$2" t="$3" l="$4" b="$5"
  case "$t$l$b" in
    *"<"*">"*|"") echo "[gate-stop] ⚠ $name 命令未填（占位符/空），跳过该侧门禁——未配置=未验证。合并前的硬卡在 loop-persist：未配置侧禁止自动合并。请尽快编辑 .claude/loop.env。" >&2; return 0 ;;
  esac
  local d="$PROJECT_ROOT/$dir"
  echo "[gate-stop] === $name 全绿门 (dir=$dir) ===" >&2
  ( cd "$d" && eval "$t" ) || fail "$name 测试($t)"
  ( cd "$d" && eval "$l" ) || fail "$name Lint($l)"
  ( cd "$d" && eval "$b" ) || fail "$name 构建($b)"
}

case "${PROJECT_MODE:-fullstack}" in
  frontend)
    run_side 前端 "${FE_DIR:-.}" "${FE_TEST_CMD:-}" "${FE_LINT_CMD:-}" "${FE_BUILD_CMD:-}"
    ;;
  backend)
    run_side 后端 "${BE_DIR:-.}" "${BE_TEST_CMD:-}" "${BE_LINT_CMD:-}" "${BE_BUILD_CMD:-}"
    ;;
  fullstack)
    run_side 前端 "${FE_DIR:-.}" "${FE_TEST_CMD:-}" "${FE_LINT_CMD:-}" "${FE_BUILD_CMD:-}"
    run_side 后端 "${BE_DIR:-.}" "${BE_TEST_CMD:-}" "${BE_LINT_CMD:-}" "${BE_BUILD_CMD:-}"
    ;;
  *)
    echo "[gate-stop] PROJECT_MODE='${PROJECT_MODE:-}' 无效（应为 frontend/backend/fullstack），跳过门禁。" >&2
    exit 0
    ;;
esac

echo "[gate-stop] 全绿，放行。" >&2
exit 0
