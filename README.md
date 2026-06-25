# 软件开发 Loop 工程 · 脚手架

一条通用、语言无关的**自动化软件开发循环**模板，平台 Claude Code，依据《Loop Engineering 橙皮书》。
循环每圈：**发现 → 交付 → 验证 → 持久化 → 调度**，由 skill/子agent（创造层）+ hook（确定性 gate 层）协作。

> ⚠️ 默认 **C 档：评判通过即自动合并 `main`**，风险最高。护栏全开。生产环境建议先用 B 档（见下）。

## 5 分钟上手

1. **把脚手架拷进你的项目根**（`.claude/`、`CLAUDE.md`、`README.md`）。
2. **替换占位符**（全局搜索 `<...>` 替换）：

   | 占位符 | 改成 |
   |--------|------|
   | `<test_command>` | 你的测试命令 |
   | `<lint_command>` | 你的 lint 命令 |
   | `<build_command>` | 你的构建命令 |
   | `<run_command>` | 你的启动命令（评判器动手验证用） |
   | `<main_branch>` | 主分支名（默认 main） |
   | `<project_conventions>` | 项目规约文本 |
   | `<max_fix_attempts>` | 验证打回重试上限（建议 3） |
   | `<per_loop_budget>` / `<daily_budget>` / `<max_retries>` | 预算上限数字 |
   | `<mcp_config>` | （可选）外部连接 MCP |

   重点文件：`.claude/hooks/gate-stop.sh`、`token-guard.sh` 里的命令/数字必须填真实值，否则门禁会跳过。

3. **给 hook 加执行权限**：`chmod +x .claude/hooks/*.sh`
4. **（推荐）装 jq**：预算守卫与危险拦截的精确解析依赖它。
5. **启动**：在 Claude Code 里运行 `/loop 30m`（每 30 分钟一圈）。

## 文件地图

| 路径 | 作用 |
|------|------|
| `CLAUDE.md` | 总纲：占位符、安全约定、急停 |
| `.claude/loop.md` | 一圈五动作的编排（裸 `/loop` 执行） |
| `.claude/settings.json` | 注册 3 个 hook + MCP 占位 |
| `.claude/skills/loop-triage` | 发现 |
| `.claude/skills/loop-implement` | 交付（开 worktree + 派生成者） |
| `.claude/skills/loop-review` | 验证（派评判者） |
| `.claude/skills/loop-persist` | 持久化（PR/合并/推进） |
| `.claude/agents/generator.md` | 生成者子 agent |
| `.claude/agents/evaluator.md` | 评判者子 agent（怀疑/会动手/模型可换） |
| `.claude/hooks/gate-stop.sh` | 全绿硬门 |
| `.claude/hooks/token-guard.sh` | 预算守卫 |
| `.claude/hooks/danger-guard.sh` | 危险命令拦截 |
| `.claude/memory/loop-state.md` | 状态文件（记忆） |
| `.claude/memory/inbox.md` | 收件箱（留给人） |
| `.claude/memory/budget.json` | 预算计数 |

## 五动作 ↔ 六零件 ↔ 文件

| 动作 | 零件 | 文件 |
|------|------|------|
| 发现 | Skills | `loop-triage` |
| 交付 | Worktrees | `loop-implement`（`--worktree`） |
| 验证 | Sub-agents | `loop-review` + `generator`/`evaluator` + `gate-stop.sh` |
| 持久化 | Memory + Connectors | `loop-persist` + `memory/*` + MCP |
| 调度 | Automations | `loop.md` + `/loop` |

## 三种急停

1. `export CLAUDE_CODE_DISABLE_CRON=1` —— 关所有定时。
2. `touch .claude/memory/STOP` —— 每圈开头检测到即整圈跳过（最快刹车）。删掉它恢复。
3. 直接停 `/loop` 会话。

## 降级到 B 档（更安全，推荐生产用）

C 档自动合并 `main` 欠"验证债"最重。降级方法：编辑 `.claude/skills/loop-persist/SKILL.md`，把"自动合并"那步改成"只开 PR，停在此等人 review + merge"（文件里已注明开关行）。人没退场，只是把时间从"写"挪到"审"。

## 上云（关机也跑）

本地 `/loop` 要求机器开着。要睡觉/关机也跑：
- 把 `loop.md` 的逻辑迁到 **Cloud Routines** 或 **GitHub Actions schedule**。
- 注意云端：最小间隔 1 小时、每次 fresh clone（看不到本地未提交文件）。
- 适合"每天凌晨扫一遍 issue 提 PR"这类不依赖本地状态的循环。

## 从小到大（建议路径，呼应橙皮书 §09）

别一上来就全自动合并。建议：
1. 先只跑 `loop-triage`（发现 + 列清单，不改代码），跑顺。
2. 接上 `loop-implement` + `loop-review`，但停在开 PR（B 档）。
3. 信任建立后，再开 C 档自动合并，并确认四道护栏都生效。
