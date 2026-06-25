# 软件开发 Loop 工程 · 设计文档

> 依据《Loop Engineering 橙皮书 v260615》设计 · 平台：Claude Code · 2026-06-25

## 1. 目标与决策

构建一条**端到端的软件开发主循环**：自动发现任务 → 隔离交付 → 生成实现 → 独立评判 → 持久化 → 定时调度，覆盖白皮书全部五动作六零件。

| 决策项 | 选择 |
|--------|------|
| 交付物 | 设计文档 + 可运行脚手架 |
| 平台 | Claude Code |
| 项目类型 | 通用模板（语言无关，占位符填充） |
| 循环数量 | 一条完整开发主循环 |
| 自主边界 | **C 档：评判器通过即自动合并 main**（最高风险，护栏堆满） |
| 调度方式 | 本地 `/loop`（文档附上云升级路径） |
| 架构 | **方案 3：Skill/子agent 创造层 + Hook 确定性 gate 层**（Stripe Minions 原则） |

**风险声明**：自动合并 main 是白皮书 §07 明确警告欠"验证债"最重的做法。本设计通过四道防线 + 三种急停加固；文档提供一行切换降级到 B 档（只开 PR 不合并）。

## 2. 架构总览

- **创造层**（LLM）：`skills/` + `agents/` —— 发现、写码、审查
- **确定性 gate 层**（硬编码）：`hooks/` —— 全绿门、预算守卫、危险拦截
- **持久化层**：`memory/` —— 状态文件、收件箱、预算计数
- **编排 + 调度层**：`loop.md` + `settings.json` + `/loop`

核心原则：**能写死规则的判断交给 hook，不交给 LLM**（白皮书 Stripe 案例：可靠性来自约束质量，不是模型大小）。

## 3. 目录结构

> **复用机制（方式 B）**：所有命令/参数集中在唯一文件 `.claude/loop.env`，hook 用 `source` 读取、skill/agent 被指示先读它；`install-loop.sh` 一键把模板装进任意项目。换项目 = 跑安装脚本 + 改一个 `loop.env`。档位 C/B 由 `loop.env` 的 `AUTO_MERGE` 一个值切换。

```
项目根/
├── CLAUDE.md                    # loop 总纲：配置指引、项目规约、急停、安全约定
├── README.md                    # 上手 + Windows 必做 + 档位切换 + 上云
├── install-loop.sh              # 一键安装到任意项目
├── .gitattributes               # 强制 .sh 为 LF（Windows CRLF 坑）
│   └── .claude/loop.env         # ★唯一配置文件（命令/参数/档位）
├── .claude/
│   ├── loop.md                  # 裸 /loop 执行的一圈编排
│   ├── settings.json            # 注册 hooks + 占位 MCP
│   ├── skills/
│   │   ├── loop-triage/SKILL.md     # 发现
│   │   ├── loop-implement/SKILL.md  # 交付
│   │   ├── loop-review/SKILL.md     # 验证
│   │   └── loop-persist/SKILL.md    # 持久化
│   ├── agents/
│   │   ├── generator.md             # 生成者
│   │   └── evaluator.md             # 评判者（怀疑/会动手/模型可换）
│   ├── hooks/
│   │   ├── gate-stop.sh             # 全绿硬门 (Stop)
│   │   ├── token-guard.sh           # 预算守卫 (PreToolUse)
│   │   └── danger-guard.sh          # 危险命令拦截 (PreToolUse)
│   └── memory/
│       ├── loop-state.md            # 状态文件
│       ├── inbox.md                 # 收件箱
│       └── budget.json              # token/调用计数
└── docs/superpowers/specs/      # 本文档
```

## 4. 五动作落地

| 动作 | 落到哪 | 一圈里干什么 | 输出 |
|------|--------|-------------|------|
| ① 发现 | `skills/loop-triage` | 读 CI 失败 / open issue / `TODO`/`FIXME` → 判断值得做的 | 写 `loop-state.md` 待办；做不了的进 `inbox.md` |
| ② 交付 | `loop.md` + `agents/generator` | 取最高优先级 **1 个**任务，开 `--worktree`，派生成者 | 一个 worktree + 明确任务 |
| ③ 验证 | `agents/evaluator` + `hooks/gate-stop.sh` | 评判者怀疑论审查 + 会动手跑命令；硬 gate 复核全绿 | 通过 / 打回（重试 ≤ `<max_fix_attempts>`） |
| ④ 持久化 | `skills/loop-persist` + `hooks/gate-stop.sh` | 开 PR；全绿+评判通过→自动合并 main | PR/合并记录 + 游标推进 |
| ⑤ 调度 | `loop.md` + `/loop` | 更新 `loop-state.md` 游标，下圈接着跑 | 持续循环 |

**编排原则（写进 `loop.md`）**：
1. 一圈只推进一个任务（控制 blast radius）。
2. 发现用 `$skill-name` 触发，不贴大段指令。
3. 生成者/评判者必须不同子 agent，指令不同、模型可不同。
4. 能写死规则的判断全交给 hook。
5. 任何 gate 不过 → 不推进，写 `inbox.md` 等人，绝不绕过硬合。

一圈伪流程：
```
/loop 醒来
  → 检测 memory/STOP，存在则整圈跳过
  → loop-triage（发现）；无新活则结束本圈
  → 取 1 个最高优先级任务
  → 开 worktree，generator 实现（交付）
  → evaluator 审查 + gate-stop 全绿门（验证）；不过→改/打回 inbox
  → loop-persist 开 PR → 自动合并 main（持久化）
  → 更新 loop-state.md 游标（调度）
  → 全程 token-guard 在 PreToolUse 守预算
```

## 5. 六零件落地

| 零件 | 文件 | 内容 |
|------|------|------|
| 1 Automations | `loop.md` + `/loop` | 一圈编排；`/loop 30m` 启动；文档附上云 |
| 2 Worktrees | `loop-implement` 内 | 每任务 `--worktree`，一圈一弃（cattle not pets） |
| 3 Skills | `skills/*/SKILL.md` | 固化发现/实现/审查/收尾；规约用 `<project_conventions>` |
| 4 Connectors | `settings.json` + 文档 | 不强绑 MCP，留 `<mcp_config>` 接 GitHub/issue/Slack |
| 5 Sub-agents | `generator.md`、`evaluator.md` | 生成 vs 评判分离；评判默认怀疑、会动手、模型可换 |
| 6 Memory | `loop-state.md`、`inbox.md`、`budget.json` | 状态/收件箱/预算计数 |

**两个子 agent 关键差异**（白皮书 §05）：
- `generator`：专注实现 + 自测，倾向"我做完了"。
- `evaluator`：指令完全不同、model 可设为不同型号、默认 "assume broken until proven otherwise"，必须实际跑 test/lint/启动验证，而非只读代码。

**占位符清单**（用户只改这些）：
`<test_command>` `<lint_command>` `<build_command>` `<run_command>` `<main_branch>`(默认 main) `<project_conventions>` `<mcp_config>`(可选) `<max_fix_attempts>`(默认 3) `<per_loop_budget>` `<daily_budget>` `<max_retries>`

## 6. 护栏与急停（C 档加固）

**四道防线**
1. **评判器（软门）**：`evaluator` 默认怀疑、动手验证；打回则 `generator` 改，≤ `<max_fix_attempts>`；仍不过→不合并，写 `inbox.md`。
2. **全绿硬门**（`gate-stop.sh`，Stop hook）：`<test_command>` 且 `<lint_command>` 且 `<build_command>` 退出码全 0 才放行，任一非 0 阻断。
3. **预算守卫**（`token-guard.sh`，PreToolUse）：读写 `budget.json`，单圈/每日/重试上限到顶即停。
4. **危险命令拦截**（`danger-guard.sh`，PreToolUse）：拦 `push --force`、`reset --hard`、`rm -rf`、删分支、改 CI → 转人工。

**三种急停**
1. `CLAUDE_CODE_DISABLE_CRON=1` —— 关所有定时。
2. `memory/STOP` 文件存在 → 开圈检测，整圈跳过（最快刹车）。
3. 停 `/loop` 会话。

**降级到 B 档**：把 `loop-persist` 的"自动合并"换成"只开 PR，停在此等人 merge"，一行注释切换。

## 7. 完整文件清单

| # | 文件 | 类型 | 职责 |
|---|------|------|------|
| 1 | `CLAUDE.md` | 文档 | 总纲：占位符、急停、安全约定 |
| 2 | `.claude/loop.md` | 编排 | 一圈五动作编排 |
| 3 | `.claude/settings.json` | 配置 | 注册 3 hook + 占位 MCP |
| 4 | `.claude/skills/loop-triage/SKILL.md` | skill | 发现 |
| 5 | `.claude/skills/loop-implement/SKILL.md` | skill | 交付 |
| 6 | `.claude/skills/loop-review/SKILL.md` | skill | 验证 |
| 7 | `.claude/skills/loop-persist/SKILL.md` | skill | 持久化 |
| 8 | `.claude/agents/generator.md` | 子agent | 生成者 |
| 9 | `.claude/agents/evaluator.md` | 子agent | 评判者 |
| 10 | `.claude/hooks/gate-stop.sh` | hook | 全绿硬门 |
| 11 | `.claude/hooks/token-guard.sh` | hook | 预算守卫 |
| 12 | `.claude/hooks/danger-guard.sh` | hook | 危险拦截 |
| 13 | `.claude/memory/loop-state.md` | 记忆 | 状态文件 |
| 14 | `.claude/memory/inbox.md` | 记忆 | 收件箱 |
| 15 | `.claude/memory/budget.json` | 记忆 | 预算计数 |
| 16 | `.claude/memory/STOP` | 急停 | 存在即跳圈（文档说明，不预置） |
| 17 | `docs/.../loop-engineering-design.md` | 文档 | 本文档 |
| 18 | `README.md` | 文档 | 上手 + 占位符 + 上云/降级 |

## 8. 上手与升级路径

- **启动**：填占位符 → `/loop 30m`（每 30 分钟一圈）。
- **从小到大**（白皮书 §09）：先只开 triage（发现+列清单），跑通后逐步接 implement/review/persist。
- **上云**（关机也跑）：把 `loop.md` 逻辑迁到 Cloud Routines 或 GitHub Actions schedule，注意云端最小间隔 1 小时、fresh clone 看不到本地文件。
