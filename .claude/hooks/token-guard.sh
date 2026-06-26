#!/usr/bin/env bash
# token-guard.sh —— 预算守卫 (PreToolUse hook)
# 作用：每次工具调用前计数，超过单圈/每日上限即阻断，防空转 bug 烧光额度。
# 配置来自 .claude/loop.env；计数落在 .claude/memory/budget.json。
#
# 退出码：0 = 放行；2 = 阻断（超预算）。

set -u

# 读 hook 的 stdin（含 tool_name），用于按工具类型决定无 jq 时的处置。不依赖 jq 解析（jq 正是要检测的对象）。
INPUT="$(cat 2>/dev/null || true)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../loop.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

BUDGET_FILE="$SCRIPT_DIR/../memory/budget.json"
TODAY="$(date +%F)"

# 占位符/空值 → 不阻断，但提醒
case "${PER_LOOP_BUDGET:-}${DAILY_BUDGET:-}" in
  *"<"*">"*|"") echo "[token-guard] loop.env 预算未填，跳过守卫。请编辑 .claude/loop.env。" >&2; exit 0 ;;
esac

# 无 jq 则无法计数。jq 是预算守卫的硬前提，但不能因此把整个 agent 锁死
# （连 Read/Write 都拦 → 连写 inbox 转人工都做不到，违背"gate 不过就写 inbox 等人"）。
# 折中：fail-closed 只卡住烧钱/空转的主驱动 Bash；其余工具放行但大声告警，让人看见护栏没生效。
if ! command -v jq >/dev/null 2>&1; then
  case "$INPUT" in
    *'"tool_name":"Bash"'*|*'"tool_name": "Bash"'*)
      echo "[token-guard] 未找到 jq —— 预算守卫无法计数。fail-closed：阻断 Bash（防空转烧额度）。jq 是硬前提，请先安装（见 README「前置条件」）。" >&2
      exit 2 ;;
    *)
      echo "[token-guard] ⚠ 未找到 jq —— 预算守卫已失效（无法计数）！非 Bash 工具暂放行以便转人工，但请立刻安装 jq，否则 token 无上限保护。" >&2
      exit 0 ;;
  esac
fi

# 初始化 / 跨天重置
if [ ! -f "$BUDGET_FILE" ] || [ "$(jq -r '.date' "$BUDGET_FILE" 2>/dev/null)" != "$TODAY" ]; then
  mkdir -p "$(dirname "$BUDGET_FILE")"
  echo "{\"date\":\"$TODAY\",\"loop_calls\":0,\"daily_calls\":0}" > "$BUDGET_FILE"
fi

LOOP_CALLS=$(jq -r '.loop_calls' "$BUDGET_FILE")
DAILY_CALLS=$(jq -r '.daily_calls' "$BUDGET_FILE")
LOOP_CALLS=$((LOOP_CALLS + 1))
DAILY_CALLS=$((DAILY_CALLS + 1))

jq ".loop_calls=$LOOP_CALLS | .daily_calls=$DAILY_CALLS" "$BUDGET_FILE" > "$BUDGET_FILE.tmp" && mv "$BUDGET_FILE.tmp" "$BUDGET_FILE"

if [ "$DAILY_CALLS" -gt "$DAILY_BUDGET" ]; then
  echo "[token-guard] 阻断：今日调用 $DAILY_CALLS 已超每日上限 $DAILY_BUDGET。明天再跑或调高预算。" >&2
  exit 2
fi
if [ "$LOOP_CALLS" -gt "$PER_LOOP_BUDGET" ]; then
  echo "[token-guard] 阻断：本圈调用 $LOOP_CALLS 已超单圈上限 $PER_LOOP_BUDGET。疑似空转，请检查。" >&2
  exit 2
fi

exit 0
# 注：每圈开始时应把 loop_calls 归零（loop.md 第 0 步会重置）。
