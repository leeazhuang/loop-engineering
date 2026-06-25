---
name: loop-persist
description: 循环第四步「持久化」。开 PR，C 档下自动合并 main，更新状态文件。
---

# loop-persist · 持久化

职责：把通过验证的改动落到对话之外的地方，并推进状态。

## 步骤
1. **开 PR**：把 worktree 分支推上去，开一个 PR（有 `<mcp_config>` 接 GitHub 则用 MCP；否则用 `gh pr create`）。PR 描述写清：做了什么、为什么、对应任务、验证结果。
2. **合并（C 档）**：
   - 前置条件（缺一不可）：`evaluator` 通过 **且** `gate-stop.sh` 全绿门通过。
   - 满足 → 自动合并到 `<main_branch>`。
   - ⚠️ **降级到 B 档**：把下面这步注释掉，改成"停在这里，等人 review + merge"。
     ```
     # C 档（当前）：自动合并
     gh pr merge --squash --auto
     # B 档（更安全）：不自动合并，只留 PR 等人
     # （删掉上面一行即可）
     ```
3. **更新状态**：
   - `loop-state.md`：把任务从「进行中」移到「## 已完成」，记录 PR 链接 / 合并 commit / 时间。
   - 清理用完的 worktree（cattle not pets）。

## 约束
- 绝不 `--no-verify`、绝不 `push --force` 到 `<main_branch>`（`danger-guard.sh` 会拦）。
- 合并失败（冲突等）→ 不强推，写 `inbox.md` 转人工。
