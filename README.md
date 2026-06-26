# 软件开发 Loop 工程 · 脚手架

一条通用、语言无关的**自动化软件开发循环**模板，平台 Claude Code，依据《Loop Engineering 橙皮书》。
循环每圈：**发现 → 交付 → 验证 → 持久化 → 调度**，由 skill/子agent（创造层）+ hook（确定性 gate 层）协作。

> ⚠️ 默认 **C 档：评判通过即自动合并 `main`**，风险最高。护栏全开。生产环境建议先用 B 档（见下）。

## 套用到任意项目（一键安装）

```bash
bash install-loop.sh <目标项目目录>
# 例: bash install-loop.sh /d/work/my-app
```
脚本会把 `.claude/`、`CLAUDE.md`、`.gitattributes` 拷进目标项目，并重置运行态记忆。
若目标已有 `.claude`，会自动备份不覆盖。

装完后**只需改一个文件**：`<目标>/.claude/loop.env`。

**第一步选模式** `PROJECT_MODE`：`frontend` / `backend` / `fullstack`。

| 键 | 改成 |
|----|------|
| `PROJECT_MODE` | `frontend`(纯前端) / `backend`(纯后端) / `fullstack`(前后端) |
| `FE_LANG` / `FE_DIR` / `FE_TEST_CMD` / `FE_LINT_CMD` / `FE_BUILD_CMD` / `FE_RUN_CMD` | 前端语言/目录/命令（含前端时填） |
| `BE_LANG` / `BE_DIR` / `BE_TEST_CMD` / `BE_LINT_CMD` / `BE_BUILD_CMD` / `BE_RUN_CMD` | 后端语言/目录/命令（含后端时填） |
| `MAIN_BRANCH` | 主分支名（默认 main） |
| `AUTO_MERGE` | `true`=C档自动合并 / `false`=B档只开PR |
| `MAX_FIX_ATTEMPTS` | 验证打回重试上限（建议 3） |
| `PER_LOOP_BUDGET` / `DAILY_BUDGET` / `MAX_RETRIES` | 预算上限数字 |

> **MCP（项目级，随仓库附带）**：项目根的 `.mcp.json` 已预配 **Playwright**，clone 即用——别人不需要任何全局配置，前端评判开箱即用。要给某项目加 GitHub/数据库等专属连接器，参考 `.mcp.json.example` 合并进 `.mcp.json`；**token 一律用 `${ENV_VAR}`**，真实值放各自环境变量，绝不硬编码进仓库。

**三模式行为**：纯前端只填+只验 FE；纯后端只填+只验 BE；全栈两组都填，任务自动打 `[fe]`/`[be]`/`[both]` 层标签——generator 进对应目录、evaluator 选对应验证（前端 Playwright 浏览器、后端 API/测试）、`gate-stop` 硬门两侧都跑（都得绿）。

项目规约写在 `CLAUDE.md` 的「项目规约」一节（给模型读的自由文本，不放 loop.env）。

## Windows 必做（一次性）

1. **bash 在 PATH**：hook 由 `settings.json` 里 `bash .claude/hooks/*.sh` 调用，需 git-bash 的 bash 可用（Windows 装了 Git 即有）。
2. **jq + gh（必装，`install-loop.sh` 会自动装）**：jq 是预算守卫/危险拦截精确解析的硬前提，gh 是开 PR/合并的硬前提——缺任一安装脚本直接中止。脚本装不上时手动装：`winget install jqlang.jq`、`winget install GitHub.cli`。
3. **gh 登录（必做一次）**：`gh auth login` —— 自动安装不含登录，开 PR/合并前必须登录（或改用 GitHub MCP）。
4. **换行**：`.gitattributes` 已强制 `.sh` 为 LF（CRLF 会让 bash 报 `\r` 错）。
5. **首次冒烟验证**：让 agent 试跑一条 `rm -rf` 看 `danger-guard` 是否拦下（退出码 2）。不灵则说明 hook 没被正确调用，改用 `cmd /c` 包装命令重试。

## 启动

在目标项目里运行 `/loop 30m`（每 30 分钟一圈）。

> **首次会弹 MCP 批准框**：第一次加载本仓库的 `.mcp.json` 时，Claude Code 出于安全会弹窗让你确认是否信任并启用其中的 MCP 服务器（如 Playwright）。这是正常机制，点同意即可；拒绝则前端浏览器评判用不了。需要 Node/npx 可用（`npx @playwright/mcp` 首次会自动下载）。

## 文件地图

| 路径 | 作用 |
|------|------|
| `CLAUDE.md` | 总纲：配置指引、项目规约、安全约定、急停 |
| `.claude/loop.env` | **唯一配置文件**：模式/语言/命令/参数/档位 |
| `.mcp.json` | 项目级 MCP（自带 Playwright，clone 即用） |
| `.mcp.json.example` | 加 GitHub/DB 等连接器的参考（token 用 env） |
| `install-loop.sh` | 一键把模板装进任意项目 |
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

## C 档 / B 档切换（改一个值）

C 档自动合并 `main` 欠"验证债"最重。切换只需改 `.claude/loop.env`：
```
AUTO_MERGE="false"   # B档：评判+全绿后只开 PR，停在此等人 review+merge（推荐生产用）
AUTO_MERGE="true"    # C档：评判+全绿后自动合并 main
```
人没退场，只是把时间从"写"挪到"审"。

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
