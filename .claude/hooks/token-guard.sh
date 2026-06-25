#!/usr/bin/env bash
# token-guard.sh —— 预算守卫 (PreToolUse hook)
# 作用：每次工具调用前计数，超过单圈/每日上限即阻断，防空转 bug 烧光额度。
# 配置来自 .claude/loop.env；计数落在 .claude/memory/budget.json。
#
# 退出码：0 = 放行；2 = 阻断（超预算）。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../loop.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

BUDGET_FILE="$SCRIPT_DIR/../memory/budget.json"
TODAY="$(date +%F)"

# 占位符/空值 → 不阻断，但提醒
case "${PER_LOOP_BUDGET:-}${DAILY_BUDGET:-}" in
  *"<"*">"*|"") echo "[token-guard] loop.env 预算未填，跳过守卫。请编辑 .claude/loop.env。" >&2; exit 0 ;;
esac

# 无 jq 则降级为不阻断（提醒）
if ! command -v jq >/dev/null 2>&1; then
  echo "[token-guard] 未找到 jq，无法计数，跳过。建议安装 jq 以启用预算守卫。" >&2
  exit 0
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
