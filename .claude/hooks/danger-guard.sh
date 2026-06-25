#!/usr/bin/env bash
# danger-guard.sh —— 危险命令拦截 (PreToolUse hook, matcher: Bash)
# 作用：即使全自动也绝不允许的破坏性命令，一律拦截转人工。
# 从 stdin 读取 hook 的 JSON（含将要执行的 bash 命令）。
#
# 退出码：0 = 放行；2 = 阻断。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../loop.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

INPUT="$(cat)"

# 取出将要执行的命令文本（有 jq 用 jq，否则退化为整段匹配）
if command -v jq >/dev/null 2>&1; then
  CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  CMD="$INPUT"
fi
[ -z "$CMD" ] && exit 0

block() {
  echo "[danger-guard] 阻断危险命令：$1。这是红线，请人工处理，不要自动执行。" >&2
  exit 2
}

# 危险模式（按需增减）
case "$CMD" in
  *"rm -rf"*|*"rm -fr"*)                         block "rm -rf 递归删除" ;;
  *"git push"*"--force"*|*"git push"*" -f"*)     block "git push --force 强推" ;;
  *"push --force-with-lease"*)                    block "force-with-lease 强推" ;;
  *"git reset --hard"*)                           block "git reset --hard 丢弃改动" ;;
  *"git clean -f"*|*"git clean -d"*)              block "git clean 强制清理" ;;
  *"git branch -D"*|*"git branch --delete --force"*) block "强制删分支" ;;
  *"git checkout ."*|*"git restore ."*)           block "整目录丢弃改动" ;;
  *"--no-verify"*)                                block "--no-verify 跳过校验钩子" ;;
  *":(){ :|:& };:"*)                              block "fork 炸弹" ;;
  *"mkfs"*|*"dd if="*)                            block "磁盘破坏命令" ;;
esac

# 显式拦截向主分支的直接 push（即使非 force；C档由循环自动合并，人/agent 不应手动直推主分支）
MB="${MAIN_BRANCH:-main}"
case "$CMD" in
  *"git push"*"$MB"*) block "直接 push 到主分支 $MB" ;;
esac

exit 0
