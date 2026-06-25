# Loop 编排（裸 /loop 执行此文件）

每次 `/loop` 触发，按顺序执行以下一圈。**严格按步骤，不要跳步。**

## 第 0 步 · 急停检测 + 重置单圈计数
- 如果 `.claude/memory/STOP` 文件存在 → 立即结束本圈，什么都不做。
- 否则：把 `.claude/memory/budget.json` 的 `loop_calls` 归零（单圈预算重新计），继续。
- 所有命令/参数都从 `.claude/loop.env` 读取（唯一配置文件）。

## 第 1 步 · 发现（discovery）
- 触发技能：`loop-triage`（不要在这里贴大段指令）。
- 它会读 CI 失败 / open issue / 代码里的 `TODO`/`FIXME`，把值得做的写进 `.claude/memory/loop-state.md` 的「待办」区；处理不了的写进 `.claude/memory/inbox.md`。
- 如果「待办」为空 → 结束本圈（没有活，不空转）。

## 第 2 步 · 取任务
- 从 `loop-state.md`「待办」里取**优先级最高的 1 个**任务，移到「进行中」。
- **一圈只做一个。** 不要批量。

## 第 3 步 · 交付 + 生成（handoff）
- 触发技能：`loop-implement`。
- 它为该任务开一个隔离 worktree（`claude --worktree`），把任务派给 `generator` 子 agent 实现并自测。

## 第 4 步 · 验证（verification）
- 触发技能：`loop-review`。
- 它派 `evaluator` 子 agent（指令不同、可换模型、默认怀疑、会动手跑命令）审查。
- 评判不过 → 退回 `generator` 修改，最多 `$MAX_FIX_ATTEMPTS` 次（见 loop.env）。
- 仍不过 → **不推进**，把任务连同失败原因写进 `inbox.md`，跳到第 6 步。
- 注意：合并前还有 `gate-stop.sh` 硬门（test/lint/build 全绿），LLM 跳不过。

## 第 5 步 · 持久化（persistence）
- 触发技能：`loop-persist`。
- 开 PR；`AUTO_MERGE=true`（C 档）：全绿 + 评判通过 → 自动合并到 `$MAIN_BRANCH`；`AUTO_MERGE=false`（B 档）：只开 PR 等人（均见 loop.env）。
- 更新 `loop-state.md`：任务移到「已完成」，记录 PR/合并信息。

## 第 6 步 · 调度游标（scheduling）
- 更新 `loop-state.md` 的「游标」：记录本圈处理到哪、下圈从哪继续。
- 结束本圈。下一次 `/loop` 自动从这里接着跑。

---
全程：`token-guard.sh` 在每次工具调用前守预算，超限即停；`danger-guard.sh` 拦截危险命令。
