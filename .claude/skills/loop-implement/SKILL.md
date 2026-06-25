---
name: loop-implement
description: 循环第二步「交付」。为单个任务开隔离 worktree，派 generator 子 agent 实现并自测。
---

# loop-implement · 交付 + 生成

职责：把**一个**任务隔离起来，交给生成者实现。

## 步骤
1. **开隔离 worktree**：为本任务创建独立工作目录，互不踩脚。
   ```
   claude --worktree   # 或 -w，给后台 agent 开独立 worktree
   ```
   命名建议：`loop/<任务短名>`。一圈一个，用完即弃（cattle not pets）。
2. **派给生成者**：先读 `.claude/loop.env` 取命令，调用 `generator` 子 agent，传入：
   - 任务标题 + 完成标准（来自 `loop-state.md`「进行中」）
   - 项目规约：见 `CLAUDE.md`
   - 自测要求：实现后必须自己跑 `$TEST_CMD`（来自 loop.env），确保本地通过。
3. **不要在这一步做评判**。实现的好坏由下一步 `loop-review` 的独立评判者说了算，generator 不能给自己打分。

## 约束
- **一圈只实现一个任务**。
- 改动范围限制在该任务内，不顺手改无关代码（最小变更）。
- 禁止删测试 / 跳过测试来让结果"看起来通过"。
