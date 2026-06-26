---
description: 执行软件开发 Loop 一圈（发现→交付→验证→持久化→调度）。编排细节见 .claude/loop.md。
---

读取 `.claude/loop.md`，**严格按其中的步骤执行一整圈，不要跳步**。
所有命令与参数从 `.claude/loop.env`（唯一配置文件）读取。

要点（细节以 `.claude/loop.md` 为准）：
- 第 0 步先检测急停文件 `.claude/memory/STOP`，存在则整圈跳过。
- 一圈只推进一个任务。
- 生成者与评判者必须是不同子 agent。
- 任何硬门不过则不推进，写进 `.claude/memory/inbox.md` 等人。

> 定时每 N 分钟自动跑一圈：用间隔运行器驱动本命令，例如 `/loop 30m /loop-cycle`
> （`/loop` 间隔运行器来自 superpowers 的 loop skill；没有它也可用 OS cron / GitHub Actions 定时调用 `/loop-cycle`）。
