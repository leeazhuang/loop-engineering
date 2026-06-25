# Loop Engineering 循环工程 · 读书笔记

> 来源：《Loop Engineering 橙皮书 v260615》 · 作者：花叔（AI Native Coder） · 2026-06-15
> 一句话主旨：**AI 生成内容不稀缺，稀缺的是判断力。**

---

## 一句话定义

> Loop engineering is replacing yourself as the person who prompts the agent. You design the system that does it instead.
>
> 循环工程，就是把「那个负责 prompt agent 的人」从你自己换成一套系统。你不再亲自一句句喂，而是设计那套替你喂的系统。
> —— Addy Osmani（Google Chrome 工程师，命名者）

重心在「**替换你自己**」：从"循环里干活的人"，变成"循环外造循环的人"。
- 旧世界：你是人肉时钟，每一拍都得你敲。
- 新世界：你设计一套东西，让它自己一拍一拍地敲，你在循环外看着它转。

### 三人同周点火（2026 年 6 月）
| 人物 | 身份 | 原话核心 |
|------|------|----------|
| Peter Steinberger | OpenClaw 作者（引爆，800万+浏览） | You should be designing loops that prompt your agents. |
| Boris Cherny | Anthropic，Claude Code 负责人（同声） | My job is to write loops. |
| Addy Osmani | Google Chrome 工程师（命名 + 成文） | You design the system that does it instead. |

---

## §02 四层栈：从 Prompt 到 Loop

每往上一层，操心的东西大一号。各层叠加，不是替代。

| 层 | 管什么 | 核心问题 |
|----|--------|----------|
| Prompt engineering | 写好一次的提示词 | 我该告诉模型什么 |
| Context engineering | 这一刻窗口里放什么 | 检索什么、摘要什么、清掉什么 |
| Harness engineering | 单次运行的武装 | 给哪些工具、允许哪些动作、什么算完成 |
| **Loop engineering** | 在 harness 之上调度 | 怎么让它自己一遍遍跑起来 |

> Loop engineering sits one floor above the harness.
> 循环工程，坐在 harness 的上一层楼。

**为什么要分清？** 每层失败方式不同，"能说不的检查"要装在不同地方。层次越高，你离现场越远，错误攒得越久 —— loop 会在你睡觉时自己改你没看过的代码，出问题可能几天后才发现。

---

## §03 一个循环的五个动作

以 Addy 的早晨 **triage loop** 为例串起：

| 动作 | 干什么 | 在 triage loop 里 |
|------|--------|-------------------|
| **发现 Discovery** | 自己找出这圈该做的事 | skill 读 CI 失败 / issue / commit |
| **交付 Handoff** | 把任务隔离着交给 agent | 每个发现开一个 worktree |
| **验证 Verification** | 换个 agent 说「不」 | 第二个子 agent 对照测试审查 |
| **持久化 Persistence** | 把状态写到对话之外 | 开 PR + 收件箱 + 状态文件 |
| **调度 Scheduling** | 让它一圈圈自动转 | 早上 automation 自动跑 |

关键细节：
- 发现这步触发的是 **`$skill-name`**，不是贴一大段没人会更新的指令。
- 验证最不能省：写代码的 agent 给自己打分太手软，必须换人审。
- 持久化要点：**agent 会忘，仓库不会**。
- 调度才让"跑过一次"变成"循环"：
  > Automations are what make a loop an actual loop and not just one run you did once.

---

## §04 六个零件（对应五个动作）

| 零件 | 是什么 | 对应动作 | 一句话原话 |
|------|--------|----------|-----------|
| **Automations** | 挂在时间表/触发器上自动跑 | 调度 | make a loop an actual loop |
| **Worktrees** | 隔离并行 agent 的工作目录 | 交付 | same headache as two engineers |
| **Skills** | 用 SKILL.md 固化知识、还"意图债" | 发现 | fire `$skill-name`, not a wall of instructions |
| **Connectors** | MCP 接外部系统（决定 loop 视野半径） | 持久化/发现 | only see the filesystem is a tiny loop |
| **Sub-agents** | 生成者与评判者分离 | 验证 | too nice grading its own homework |
| **Memory** | 磁盘上的持久状态（≠上下文） | 持久化 | the agent forgets, the repo doesn't |

口诀：Automation 让它动，worktree 让它不打架，skill 让它不重复劳动，connector 让它看得见外面，子 agent 让它能自我纠错，memory 让它记得住。

---

## §05 生成器 vs 评判器：为什么 AI 不能给自己打分

**核心现象**（Anthropic 工程师 Prithvi Rajasekaran）：
> 让 agent 评价自己产出的东西，它往往会自信地夸一通，哪怕在人看来质量明显很一般。

原因：写代码的上下文里塞满了"我为什么这么写"的自我说服，它看到的是推导过程，不是结果。

**关键结论（反直觉）**：
> 调一个独立的评判器让它怀疑，比让生成器自我批判要容易得多。

—— 区别在**结构**不在措辞。换个 agent、给完全不同的指令、有时连模型都换掉，它没参与写就没有自我说服包袱。思想来自 **GAN（生成对抗网络）**：一个造，一个挑刺。

**让评判器更狠的四步**：
1. 结构上分开生成与评判（generator / evaluator）
2. 把评判器调成怀疑论者（社区经验：默认"代码是坏的，除非被证明能跑"）
3. 让评判器**会动手**而不只是读（如接 Playwright MCP，真去点页面、截图、查 DOM）
4. 判定权交给一个**没参与干活的 fresh 模型**

**产品化原语 `/goal`**（Claude Code）：
```
/goal all tests in test/auth pass and the lint step is clean
```
> 每跑完一轮，一个又小又快的模型来检查条件成立没有。不成立就再跑一轮。是否完成由全新模型判定，不是干活那个。

本质是把银行的 **maker-checker（生产者-检查者）** 老规矩塞进 agent 循环。
- ⚠️ 区分：`/goal`（跑到条件满足为止）≠ `/loop`（按时间间隔定时重跑）。
- ⚠️ Codex 无 `/goal`，靠 Automations + agents 实现同类能力。

---

## §06 三个真实案例

### 1. Addy 的早晨 —— 个人级 triage loop
一个人、一台机器，每天早上自动跑：读 CI/issue → 开 worktree → 子 agent 起草+审查 → 过了自动开 PR，没把握进收件箱，状态写文件留给第二天。

### 2. Stripe 的 Minions —— 企业级，每周 1300+ PR（无一行人手写）
- 触发很轻：Slack @ bot 或加 emoji，fire-and-forget。
- 真正靠谱的是 **LLM 醒来之前**：确定性 orchestrator 先备齐上下文（扫链接、拉 Jira、找文档、Sourcegraph+MCP 搜代码）。
- **核心论点：AI 的可靠性来自约束的质量，不是模型的大小**（Minions 是开源工具 Goose 的 fork，不是更强的模型）。
- 架构六层，确定性 gate 与 LLM 创造步骤交替咬合；沙箱 "cattle not pets"，用完即弃。
- **人没退场，人换了工位**：1300 个 PR 仍由工程师 review，时间从"写"挪到"审"。

### 3. "睡觉时跑"到底靠什么 —— 调度选型
| | Cloud Routines | Desktop 定时任务 | /loop |
|---|---|---|---|
| 跑在哪 | Anthropic 云 | 你的机器 | 你的机器 |
| 需要开机 | 否 | 是 | 是 |
| 需要开着会话 | 否 | 否 | 是 |
| 最小间隔 | 1 小时 | 1 分钟 | 1 分钟 |
| 能看本地文件 | 否（fresh clone） | 能 | 能 |

选择逻辑：**要频繁 + 看本地文件 → 本地 `/loop`；要关机也跑 + 不依赖本地 → 上云（Cloud Routines / GitHub Actions schedule）。**

> ⚠️ 谨慎对待二手大数字（如"Anthropic 九成代码自写""Nubank 提效 12 倍"），三个一手案例更经得起较真。

---

## §07 四笔代价（都不会当场报警）

> A loop running unattended is also a loop making mistakes unattended.
> 一个没人看着的循环，也是一个没人看着犯错的循环。

| 代价 | 症状 | 一句话防它 |
|------|------|-----------|
| **验证债** | 产出堆着没人验，错误安静积累 | 装一个跟干活的不是同一个的评判者 |
| **理解腐烂** | 代码在长，你脑里的地图停了 | 定期读产出，讲不出就是该更新 |
| **认知投降** | 循环给啥收啥，懒得有意见 | 执行可外包，拿主意不行 |
| **token 失控** | 用量剧烈波动，账单不可预测 | 上线前钉死预算和重试上限 |

最危险处：团队会互相 review/吵架，一个人加一堆循环容易变成**没人吵架的回音壁**。

---

## §08 当工程师，不只是按下启动键

> Two people can build the same loop and get opposite outcomes.
> 两个人造一模一样的循环，结果可以完全相反。

- 一个人用循环**加速理解**（循环是他延伸的手）→ 半年后更强。
- 另一个人用循环**逃避理解**（绕过看不懂）→ 半年后变成"自己都不知道在跑什么的机器的看门人"。

循环是个**忠实的乘号**，乘的是你：带进理解就放大理解，带进偷懒就放大偷懒。

- 不稀缺：生成（代码/方案/PR 可无限造）。
- 稀缺：**判断力**——哪个对、哪行该拦、哪个能跑但根上错了。
- 循环不懂你为什么造它，它只看见代码、看不见动机 → 哪里留人工卡点必须事先想清楚写进去。

> Build the loop. But build it like someone who intends to stay the engineer, not just the person who presses go.
> 造那个循环。但要像一个打算继续当工程师的人去造，而不是只负责按启动键的人。

工程师身份"需要每天续费"：今天多读一个 PR、多问一句"这真的对吗"，你就还在工程师那边。

---

## §09 今天就动手：搭你的第一个 Loop

> Stripe 那套是终点不是起点。第一个 loop 应该小到几乎不像系统。

| 步骤 | 做什么 | 工具 |
|------|--------|------|
| 第一步 | 跑一个定时重跑 | `/loop`（Claude Code v2.1.72+） |
| 第二步 | 读 CI/issue/commit 做 triage | prompt + automation |
| 第三步 | 加状态文件，让它有记忆 | markdown / Linear 看板 |
| 第四步 | 加 evaluator，让它能说"不" | `/goal`（v2.1.139+） |
| 第五步 | 加 worktree，让它并行 | `--worktree` / `-w` |

### `/loop` 三种形态
```
/loop 5m check the deploy   # 固定 5 分钟一次
/loop check the deploy      # Claude 自定节奏（1 分钟~1 小时）
/loop                       # 裸跑，执行 .claude/loop.md 内容
```
- 时间单位 s/m/h/d，cron 最小 1 分钟。
- session-scoped，recurring 任务 **7 天**后过期。
- 跑在本机，关机即停；要关机也跑用 Cloud Routines / GitHub Actions。
- 全关：`CLAUDE_CODE_DISABLE_CRON=1`。

### 工具现状速查（Claude Code vs Codex，2026-06）
| 能力 | Claude Code | Codex |
|------|-------------|-------|
| 定时调度 | `/loop` | Automations 标签页（daily/weekly + cron） |
| 跑到条件满足 | `/goal` | —（automation 重跑 + 判断） |
| 并行隔离 | `--worktree` / `-w` | 专用 background worktree → Triage 收件箱 |
| 子 agent | Subagents（`.claude/agents/`） | `.codex/agents/` TOML |
| 外部连接 | MCP + Plugins | MCP connector（跨两边兼容） |
| 显式调技能 | Skills（SKILL.md） | `$skill-name` |
| 关机也跑 | Cloud Routines | 云端 Codex Jobs（规划中） |

### 第一个 loop 检查清单
| 要素 | 问自己 |
|------|--------|
| 发现源 | 它定时去读什么？（CI / issue / commit / 收件箱） |
| 状态文件 | 跨轮记忆落在哪个磁盘文件？ |
| evaluator | 有没有独立的、会说"不"的检查？ |
| 隔离 | 并行 agent 是不是各自一个 worktree？ |
| token 上限 | 设没设花费天花板？跑飞了谁拦得住？ |
| 人工复核点 | 哪一步停下来等你看一眼，而不是一路自动到底？ |

> 前两条决定能不能跑，后四条决定跑起来会不会闯祸。第一个 loop 宁可小，也要把"会说不的检查"和"人工复核点"装齐。

---

## 全书一句话回顾

1. **它是什么**：把"prompt agent 的人"从你换成系统（栈的第四层，在 harness 之上）。
2. **怎么转**：五个动作（发现/交付/验证/持久化/调度）+ 六个零件。
3. **最难的事**：往循环里放一个能说"不"的独立评判器。
4. **代价**：验证债、理解腐烂、认知投降、token 失控——都不当场报警。
5. **结局取决于人**：像打算留下来的工程师那样造循环，而不是只按启动键。
