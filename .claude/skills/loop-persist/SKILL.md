---
name: loop-persist
description: 循环第四步「持久化」。开 PR，C 档下自动合并 main，更新状态文件。
---

# loop-persist · 持久化

职责：把通过验证的改动落到对话之外的地方，并推进状态。

> 先读 `.claude/loop.env` 取 `MAIN_BRANCH`、`AUTO_MERGE`、`MCP_CONFIG`。

## 步骤
1. **开 PR**：把 worktree 分支推上去，开一个 PR（`MCP_CONFIG` 非空接 GitHub 则用 MCP；否则用 `gh pr create`）。PR 描述写清：做了什么、为什么、对应任务、验证结果。
2. **合并（由 `AUTO_MERGE` 决定档位）**：
   - 前置条件（缺一不可）：`evaluator` 通过 **且** `gate-stop.sh` 全绿门通过 **且** 本任务涉及的那一侧命令在 `loop.env` 里已真实填好。
   - **防零验证合并（硬卡）**：合并前检查本任务层标签对应侧的 `*_TEST_CMD`/`*_LINT_CMD`/`*_BUILD_CMD`——若仍是占位符 `<...>` 或空，说明 `gate-stop` 当时是"跳过该侧"而非真跑了测试，**绝不自动合并**。写进 `inbox.md`（"loop.env 未配置该侧、无法验证，拒绝自动合并"）并转人工。这是 gate-stop 占位符跳过的兜底，确保"未配置≠通过"。
   - `AUTO_MERGE="true"`（C 档）→ 自动合并到 `$MAIN_BRANCH`：`gh pr merge --squash --auto`。
   - `AUTO_MERGE="false"`（B 档，更安全）→ **不合并**，只留 PR，把"待人工 review+merge"记进 `loop-state.md`，结束本任务。
   - 切换档位只需改 loop.env 里的 `AUTO_MERGE`，不用动这个文件。
3. **更新状态**：
   - `loop-state.md`：把任务从「进行中」移到「## 已完成」，记录 PR 链接 / 合并 commit / 时间。
   - 清理用完的 worktree（cattle not pets）：`git worktree remove "../loop-<任务短名>"`（合并后分支可一并删除）。
   - 删掉 gate-stop 用的定位文件，避免下一圈用到过期路径：`rm -f .claude/memory/current-worktree`。

## 约束
- 绝不 `--no-verify`、绝不 `push --force` 到 `$MAIN_BRANCH`（`danger-guard.sh` 会拦）。
- 合并失败（冲突等）→ 不强推，写 `inbox.md` 转人工。
