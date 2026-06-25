#!/usr/bin/env bash
# gate-stop.sh —— 全绿硬门 (Stop hook)
# 作用：循环试图收尾时，强制复核 test/lint/build 全绿。任一非 0 → 阻断收尾。
# 配置全部来自 .claude/loop.env（不要在本文件里改命令）。
#
# 退出码：0 = 放行；2 = 阻断并把 stderr 反馈给模型，让它继续修。

set -u

# 解析脚本所在目录，定位 loop.env（与 cwd 无关，跨平台稳妥）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../loop.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

fail() {
  echo "[gate-stop] 阻断收尾：$1 未通过。请修复后再收尾，不要绕过本门。" >&2
  exit 2
}

# 占位符未替换则提醒（避免静默放行）
case "${TEST_CMD:-}${LINT_CMD:-}${BUILD_CMD:-}" in
  *"<"*">"*|"") echo "[gate-stop] loop.env 命令未填，跳过门禁（不安全）。请编辑 .claude/loop.env。" >&2; exit 0 ;;
esac

echo "[gate-stop] 运行全绿门..." >&2
eval "$TEST_CMD"  || fail "测试($TEST_CMD)"
eval "$LINT_CMD"  || fail "Lint($LINT_CMD)"
eval "$BUILD_CMD" || fail "构建($BUILD_CMD)"

echo "[gate-stop] 全绿，放行。" >&2
exit 0
