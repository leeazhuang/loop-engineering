#!/usr/bin/env bash
# merge-guard.sh —— 合并守卫 (PreToolUse hook, matcher: Bash)
# 作用：拦截 `gh pr merge` 自动合并前，确定性校验 PROJECT_MODE 声明的每一侧
#       *_TEST/*_LINT/*_BUILD 命令都已真实配置（非占位符 <...>、非空）。
#       任一应配置侧仍是占位符 → 阻断自动合并。
#
# 为什么需要本守卫：gate-stop.sh 对「未配置侧」是 return 0（放行，因为可能确实不用那侧），
# 真正阻止「零验证就自动合并」的原本只是 loop-persist 写给模型的一段文字指令。
# 这违背主轴原则「能写死规则的判断绝不交给模型」。本 hook 把这道判断从模型手里
# 收回成确定性脚本：gh pr merge 这条命令一旦出现，未配齐就 exit 2，LLM 跳不过。
#
# 退出码：0 = 放行；2 = 阻断（未配置侧禁止自动合并）。

set -u

INPUT="$(cat 2>/dev/null || true)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../loop.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

# 取出将要执行的命令文本（有 jq 用 jq，否则退化为整段 JSON 匹配）
if command -v jq >/dev/null 2>&1; then
  CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  CMD="$INPUT"
fi
[ -z "$CMD" ] && exit 0

# 只管「真正调用」gh pr merge（自动合并）。其它命令一律放行。
# 收紧匹配（不是裸子串）：仅当 `gh pr merge` 出现在「命令起始位」——字符串开头或命令分隔符
# （; & | ( { 反引号 换行）之后，允许其间有空白——才算一次真实调用。这样 commit message、
# `echo "gh pr merge"`、`grep gh pr merge` 等只是「提及」该短语的命令不会被误拦。
# 注：用变量承载正则（bash 中 =~ 右侧用变量才按正则解析），$'...' 让 \n 成为真实换行。
# 中间允许多个空白，兼容 `gh  pr  merge`。
_MG_RE=$'(^|[;&|({`\n])[[:space:]]*gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$|[;&|`])'
if [[ ! "$CMD" =~ $_MG_RE ]]; then
  exit 0
fi

# 占位符判定：空 或 含 <...> → 视为未配置。
is_placeholder() {
  case "$1" in
    "") return 0 ;;
    *"<"*">"*) return 0 ;;
    *) return 1 ;;
  esac
}

check_side() {
  local name="$1" t="$2" l="$3" b="$4"
  if is_placeholder "$t" || is_placeholder "$l" || is_placeholder "$b"; then
    echo "[merge-guard] 阻断自动合并：$name 侧的 test/lint/build 命令在 .claude/loop.env 里仍是占位符/空 —— 未配置=未验证，禁止把没跑过测试的改动自动并入主分支。请先配齐该侧命令，或把 AUTO_MERGE 设为 false 走 B 档人工合并。" >&2
    exit 2
  fi
}

case "${PROJECT_MODE:-fullstack}" in
  frontend)
    check_side 前端 "${FE_TEST_CMD:-}" "${FE_LINT_CMD:-}" "${FE_BUILD_CMD:-}"
    ;;
  backend)
    check_side 后端 "${BE_TEST_CMD:-}" "${BE_LINT_CMD:-}" "${BE_BUILD_CMD:-}"
    ;;
  fullstack)
    check_side 前端 "${FE_TEST_CMD:-}" "${FE_LINT_CMD:-}" "${FE_BUILD_CMD:-}"
    check_side 后端 "${BE_TEST_CMD:-}" "${BE_LINT_CMD:-}" "${BE_BUILD_CMD:-}"
    ;;
  *)
    echo "[merge-guard] ⚠ PROJECT_MODE='${PROJECT_MODE:-}' 无效（应为 frontend/backend/fullstack）。保守起见阻断自动合并，请先修正 loop.env。" >&2
    exit 2
    ;;
esac

exit 0
