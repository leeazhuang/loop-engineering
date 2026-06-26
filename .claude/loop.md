# Loop 编排（由 /loop-cycle 命令执行此文件）

`/loop-cycle`（见 `.claude/commands/loop-cycle.md`）触发时，按顺序执行以下一圈。**严格按步骤，不要跳步。**
定时自动跑用间隔运行器驱动：`/loop 30m /loop-cycle`（间隔运行器来自 superpowers 的 loop skill；没有则用 OS cron / GitHub Actions 定时调 `/loop-cycle`）。

## 第 0 步 · 急停检测 + 重置单圈计数
- 如果 `.claude/memory/STOP` 文件存在 → 立即结束本圈，什么都不做。
- 否则：把 `.claude/memory/budget.json` 的 `loop_calls` 归零（单圈预算重新计）。**必须用带 `LOOP_CYCLE_RESET` 标记的命令**跑这次重置，否则上一圈打满单圈预算后，token-guard 会把这次重置本身也拦下，循环被自己锁死。固定用：
  ```bash
  # LOOP_CYCLE_RESET —— 此标记让 token-guard 豁免本次重置（见 hooks/token-guard.sh）
  TODAY=$(date +%F); DC=$(jq -r '.daily_calls // 0' .claude/memory/budget.json 2>/dev/null || echo 0)
  echo "{\"date\":\"$TODAY\",\"loop_calls\":0,\"daily_calls\":$DC}" > .claude/memory/budget.json
  ```
- 所有命令/参数都从 `.claude/loop.env` 读取（唯一配置文件）。

## 第 1 步 · 发现（discovery）
- 触发技能：`loop-triage`（不要在这里贴大段指令）。
- 它会读**需求文档**（项目根 `需求文档.md` / `需求/*.md` / `BACKLOG.md`，绿地从零造东西的主入口）、CI 失败、open issue、代码里的 `TODO`/`FIXME`，把值得做的拆成任务写进 `.claude/memory/loop-state.md` 的「待办」区；处理不了的写进 `.claude/memory/inbox.md`。
- 如果「待办」为空 → 结束本圈（没有活，不空转）。

## 第 2 步 · 取任务
- 从 `loop-state.md`「待办」里取**优先级最高的 1 个**任务，移到「进行中」。
- **一圈只做一个。** 不要批量。

## 第 3 步 · 交付 + 生成（handoff）
- 触发技能：`loop-implement`。
- 它用原生 `git worktree` 为该任务开一个隔离工作目录，把任务派给 `generator` 子 agent 实现并自测。

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
