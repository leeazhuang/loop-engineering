---
name: loop-review
description: 循环第三步「验证」。派 evaluator 子 agent 怀疑论审查并动手验证，决定通过或打回。
---

# loop-review · 验证

职责：调用一个**独立的**评判者，给本圈产出一个真正的"能说不的东西"。

> 先读 `.claude/loop.env` 取验证命令与 `MAX_FIX_ATTEMPTS`。

## 步骤
1. **派给评判者**：调用 `evaluator` 子 agent（它的指令与 generator 完全不同，模型可不同）。传入：
   - 本任务的完成标准
   - generator 的改动
   - 验证命令：`$TEST_CMD` / `$LINT_CMD` / `$RUN_CMD`（均来自 loop.env）
2. **评判者必须会动手**，不能只读代码：
   - 实际跑 `$TEST_CMD`、`$LINT_CMD`
   - 涉及可运行行为的，用 `$RUN_CMD` 或 MCP（如 Playwright）真去用一遍
   - 默认立场：**这段代码是坏的，除非被证明能跑**。
3. **裁决**：
   - 通过 → 进入 `loop-persist`。
   - 不通过 → 把具体问题退回 `generator` 修改，重新走 implement→review，最多 `$MAX_FIX_ATTEMPTS` 次（见 loop.env）。
   - 达到上限仍不过 → **不推进**，把任务 + 失败原因写进 `.claude/memory/inbox.md`，本圈到此为止。

## 重要
- 评判者和生成者**绝不能是同一个 agent**。写代码的那个给自己打分太手软。
- 这一步过了，不代表能合并——合并前还有 `gate-stop.sh` 硬门复核 test/lint/build 全绿，那是确定性的、LLM 跳不过的最后一道闸。
