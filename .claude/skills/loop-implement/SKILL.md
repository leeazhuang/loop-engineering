---
name: loop-implement
description: 循环第二步「交付」。为单个任务开隔离 worktree，派 generator 子 agent 实现并自测。
---

# loop-implement · 交付 + 生成

职责：把**一个**任务隔离起来，交给生成者实现。

## 步骤
1. **开隔离 worktree（原生 git worktree）**：先读 `.claude/loop.env` 取 `MAIN_BRANCH`，从最新主分支切出独立工作目录，互不踩脚。
   ```bash
   git fetch --quiet
   git worktree add "../loop-<任务短名>" -b "loop/<任务短名>" "$MAIN_BRANCH"
   # 记录 worktree 绝对路径，供 gate-stop 全绿门进这棵树验本圈改动（而非主仓库旧树）。
   # 必须写主仓库的 .claude/memory（执行本步时 cwd 在主仓库根，相对路径即指向它）。
   ( cd "../loop-<任务短名>" && pwd ) > .claude/memory/current-worktree
   ```
   - 分支名固定前缀 `loop/`，目录放在仓库同级（`../loop-<任务短名>`）。
   - 若你的 Claude Code 环境提供原生 worktree 工具，用它等价创建亦可——本质都是 `git worktree`，不要用 `claude --worktree` 这种臆测命令。
   - 后续 generator 在这个 worktree 目录里工作；一圈一个，用完即弃（cattle not pets），由 `loop-persist` 用 `git worktree remove` 清理。
2. **按层定位命令与目录**：读任务的层标签（`[fe]`/`[be]`/`[both]`）和 `.claude/loop.env`：
   - `[fe]` → 在 `FE_DIR` 工作，自测用 `FE_TEST_CMD`/`FE_LINT_CMD`。
   - `[be]` → 在 `BE_DIR` 工作，自测用 `BE_TEST_CMD`/`BE_LINT_CMD`。
   - `[both]` → 两侧目录都涉及，两套命令都要自测通过。
3. **派给生成者**：调用 `generator` 子 agent，传入：
   - 任务标题 + 层标签 + 完成标准（来自 `loop-state.md`「进行中」）
   - 项目规约：见 `CLAUDE.md`
   - 自测要求：实现后必须自己跑对应侧的测试，确保本地通过。
4. **不要在这一步做评判**。实现的好坏由下一步 `loop-review` 的独立评判者说了算，generator 不能给自己打分。

## 约束
- **一圈只实现一个任务**。
- 改动范围限制在该任务内，不顺手改无关代码（最小变更）。
- 禁止删测试 / 跳过测试来让结果"看起来通过"。
