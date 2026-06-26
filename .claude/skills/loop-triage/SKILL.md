---
name: loop-triage
description: 循环第一步「发现」。读 CI 失败、open issue、代码 TODO/FIXME，判断哪些值得做，写进状态文件待办区。
---

# loop-triage · 发现

你的唯一职责是**找出这一圈值得做的事**，不要动手改任何代码。

## 输入源（按可用性读取）
1. **CI 状态**：最近一次 CI 失败的测试/作业（`MCP_CONFIG` 非空接 GitHub 则用 MCP 读，否则读本地 CI 日志 / `$TEST_CMD` 输出；命令见 `.claude/loop.env`）。
2. **open issues**：未关闭的 issue（经 MCP / issue tracker）。
3. **代码标记**：仓库里的 `TODO` / `FIXME` / `HACK`。

## 判断规则
对每个发现，判断它是否值得这一圈做：
- **值得做**：边界清晰、能在一个 worktree 里独立完成、有明确的"完成"标准。
- **做不了/需要人**：需求模糊、涉及架构决策、跨多个模块、需要产品判断。

## 层标签（按 PROJECT_MODE）
读 `.claude/loop.env` 的 `PROJECT_MODE`：
- `frontend` → 所有任务标 `[fe]`。
- `backend` → 所有任务标 `[be]`。
- `fullstack` → 给每个任务判断它动的是哪侧，标 `[fe]` / `[be]` / `[both]`。判断依据：改动落在 `FE_DIR` 还是 `BE_DIR`、是 UI 还是接口/数据层。
层标签决定后续 generator 进哪个目录、evaluator 用哪种验证方式。

## 输出
- 值得做的 → 追加到 `.claude/memory/loop-state.md` 的「## 待办」区，每条含：**层标签**、标题、来源、优先级(P0/P1/P2)、完成标准。
- 做不了的 → 追加到 `.claude/memory/inbox.md`，写清为什么需要人。
- 去重：已在「待办/进行中/已完成」里的不要重复添加。

## 重要
- 发现质量决定整圈上限。找出来的活没价值，后面做得再漂亮也是认真地做无用功。
- 找不到值得做的事就如实写"无新任务"，不要硬凑。
