#!/usr/bin/env bash
# gate-stop.sh —— 全绿硬门 (Stop hook)
# 作用：循环试图收尾时，强制复核 test/lint/build 全绿。任一非 0 → 阻断收尾。
# 这是确定性 gate，LLM 跳不过。是 C 档自动合并前最后一道闸。
#
# 退出码约定（Claude Code hooks）：
#   0 = 放行；2 = 阻断并把 stderr 反馈给模型，让它继续修。

set -u

# ↓↓↓ 把下面三个命令换成你项目的真实命令（占位符） ↓↓↓
TEST_CMD="<test_command>"
LINT_CMD="<lint_command>"
BUILD_CMD="<build_command>"
# ↑↑↑ 例如：TEST_CMD="npm test"  LINT_CMD="npm run lint"  BUILD_CMD="npm run build"

fail() {
  echo "[gate-stop] 阻断收尾：$1 未通过。请修复后再收尾，不要绕过本门。" >&2
  exit 2
}

# 占位符未替换则提醒（避免静默放行）
case "$TEST_CMD$LINT_CMD$BUILD_CMD" in
  *"<"*">"*) echo "[gate-stop] 占位符未替换，跳过门禁（不安全）。请在 gate-stop.sh 填入真实命令。" >&2; exit 0 ;;
esac

echo "[gate-stop] 运行全绿门..." >&2
eval "$TEST_CMD"  || fail "测试($TEST_CMD)"
eval "$LINT_CMD"  || fail "Lint($LINT_CMD)"
eval "$BUILD_CMD" || fail "构建($BUILD_CMD)"

echo "[gate-stop] 全绿，放行。" >&2
exit 0
