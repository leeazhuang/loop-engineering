---
name: loop-review
description: 循环第三步「验证」。派 evaluator 子 agent 怀疑论审查并动手验证，决定通过或打回。
---

# loop-review · 验证

职责：调用一个**独立的**评判者，给本圈产出一个真正的"能说不的东西"。

> 先读 `.claude/loop.env` 取验证命令与 `MAX_FIX_ATTEMPTS`。

## 步骤
1. **派给评判者**：调用 `evaluator` 子 agent（它的指令与 generator 完全不同，模型可不同）。传入：
   - 本任务的**层标签**（`[fe]`/`[be]`/`[both]`）+ 完成标准
   - generator 的改动
   - 对应侧的验证命令（来自 loop.env）：前端 `FE_*`、后端 `BE_*`
2. **评判者必须会动手，且按层切换验证方式**：
   - `[fe]` → 跑 `FE_TEST_CMD`/`FE_LINT_CMD`；用 `FE_RUN_CMD` 起服务，**接 Playwright MCP**：开页面、点按钮、截图、查 DOM，像真人 QA 用一遍。
   - `[be]` → 跑 `BE_TEST_CMD`/`BE_LINT_CMD`；用 `BE_RUN_CMD` 起服务，**真发请求**（curl/HTTP MCP）验接口与数据，而非只读代码。
   - `[both]` → 两侧都验。
   - 默认立场：**这段代码是坏的，除非被证明能跑**。
3. **裁决**：
   - 通过 → 进入 `loop-persist`。
   - 不通过 → 把具体问题退回 `generator` 修改，重新走 implement→review，最多 `$MAX_FIX_ATTEMPTS` 次（见 loop.env）。
   - 达到上限仍不过 → **不推进**：把任务 + 失败原因写进 `.claude/memory/inbox.md`，然后**清理本圈 worktree 并删掉定位文件**再结束本圈：
     ```bash
     git worktree remove "<current-worktree 路径>" --force 2>/dev/null || true
     rm -f .claude/memory/current-worktree
     ```
     这一步不能省：`current-worktree` 若还指向那棵"红"worktree，gate-stop（Stop 钩子）会按红代码拦住 agent 的收尾，导致连"写完 inbox 干净结束本圈"都做不到（被自己的门锁住）。删掉它后门会跳过（无活跃圈），本圈才能正常结束、把这事留给人。

## 重要
- 评判者和生成者**绝不能是同一个 agent**。写代码的那个给自己打分太手软。
- 这一步过了，不代表能合并——合并前还有 `gate-stop.sh` 硬门复核 test/lint/build 全绿，那是确定性的、LLM 跳不过的最后一道闸。
