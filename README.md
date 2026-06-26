# 软件开发 Loop 工程 · 脚手架

一条通用、语言无关的**自动化软件开发循环**模板，平台 Claude Code，依据《Loop Engineering 橙皮书》。
循环每圈：**发现 → 交付 → 验证 → 持久化 → 调度**，由 skill/子agent（创造层）+ hook（确定性 gate 层）协作。

> ⚠️ 默认 **C 档：评判通过即自动合并 `main`**，风险最高。护栏全开。生产环境建议先用 B 档（见下）。

> 📖 **想看懂这套循环怎么转、为什么这么设计**（分层架构、一圈逐步拆解、三道护栏、新老项目工作流、FAQ）：
> 见 **[项目详解 · doc/项目详解.md](doc/项目详解.md)**。只想快速上手用，继续往下读本 README 即可。

## 前置条件（所有平台）

跑起来需要下面这些，缺了对应环节会失败：
- **Claude Code CLI**：本工程是 Claude Code 的脚手架，所有 skill / 子 agent / hook 都靠它执行。
- **bash**：hook 由 `bash .claude/hooks/*.sh` 调起。Windows 用 git-bash 的 bash（装了 Git 即有），需在 PATH。
- **git**：循环用 `git worktree` 隔离每个任务。
- **jq + gh**：jq 是预算守卫/危险拦截精确解析的硬前提，gh 用于开 PR/合并。`install-loop.sh` 会**尝试**自动装（scoop/choco/winget/brew/apt），但**自动安装可能失败**——尤其 Windows git-bash 调 winget 常报 `Permission denied`。此时请在**真实终端（PowerShell/CMD）**手动装：
  - Windows（任选）：`scoop install jq gh` ／ `choco install jq gh -y` ／ `winget install jqlang.jq` + `winget install GitHub.cli`
  - macOS：`brew install jq gh`　Linux：`sudo apt-get install jq gh`
  - 装好后 `gh auth login` 登录一次。**缺 jq 时预算守卫会失效（仅大声告警并拦住 Bash），务必先装好再跑循环。**
- **Node / npx**：前端评判用的 Playwright MCP 靠 `npx @playwright/mcp`（首次自动下载）；纯后端可不需要。

**目标项目要求**：必须是 **git 仓库**、有主分支（默认 `main`）、且**已连 GitHub 远程**——`loop-implement` 用 `git worktree` 隔离、`loop-persist` 用 `gh pr create` 开 PR，缺远程会卡在持久化阶段。

## 套用到任意项目（一键安装·新老项目都兼容）

```bash
bash install-loop.sh <目标项目目录>
# 例: bash install-loop.sh /d/work/my-app
```
脚本把 `.claude/`、`CLAUDE.md`、`.gitattributes`、`.mcp.json` 拷进目标项目，并重置运行态记忆。

**新项目（绿地）**：目标是刚建、连好 GitHub 远程的空 git 仓库——直接装、直接填、直接写需求开干。

**老项目（存量改造）**：直接装进现有仓库即可。为了不破坏你已有的配置，脚本**不覆盖**这些文件，而是放成 sidecar 并提示你合并：
- 目标已有 `.claude` → 自动备份成 `.claude.bak.<时间戳>`，再装新的。
- 目标已有 `CLAUDE.md` → 循环总纲放成 `CLAUDE.loop.md`，**你需手动把其中「安全约定」一节并入你的 `CLAUDE.md`**（否则 generator/evaluator 读不到循环安全红线）。
- 目标已有 `.mcp.json` → 循环 MCP 放成 `.mcp.loop.json`，**含前端时把里面的 `playwright` 服务器并入你的 `.mcp.json`**（否则前端浏览器评判用不了）。

> 老项目装完先完成上述合并，再按下文「老项目（存量改造）」一节写需求开跑。

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
| `PER_LOOP_BUDGET` / `DAILY_BUDGET` | 工具调用预算上限数字（`MAX_RETRIES` 为预留，暂未启用） |

> **MCP（项目级，随仓库附带）**：项目根的 `.mcp.json` 已预配 **Playwright**，clone 即用——别人不需要任何全局配置，前端评判开箱即用。要给某项目加 GitHub/数据库等专属连接器，参考 `.mcp.json.example` 合并进 `.mcp.json`；**token 一律用 `${ENV_VAR}`**，真实值放各自环境变量，绝不硬编码进仓库。

**三模式行为**：纯前端只填+只验 FE；纯后端只填+只验 BE；全栈两组都填，任务自动打 `[fe]`/`[be]`/`[both]` 层标签——generator 进对应目录、evaluator 选对应验证（前端 Playwright 浏览器、后端 API/测试）、`gate-stop` 硬门两侧都跑（都得绿）。

项目规约写在 `CLAUDE.md` 的「项目规约」一节（给模型读的自由文本，不放 loop.env）。

## Windows 专属注意（一次性）

通用依赖见上「前置条件」。Windows 还要注意：
1. **bash 必须在 PATH**：用 git-bash 的 bash，hook 才能被 `settings.json` 里 `bash .claude/hooks/*.sh` 调起。
2. **换行**：`.gitattributes` 已强制 `.sh` 为 LF（CRLF 会让 bash 报 `\r` 错）。
3. **首次冒烟验证**：让 agent 试跑一条 `rm -rf` 看 `danger-guard` 是否拦下（退出码 2）。不灵则说明 hook 没被正确调用，改用 `cmd /c` 包装命令重试。

## 把客户需求喂进循环（新项目 & 老项目）

循环的第一步「发现」(`loop-triage`) 会从四个来源找活，**第一优先就是你的需求文档**——新老项目都靠它喂活：

| 来源 | 适合 | 怎么用 |
|------|------|--------|
| **需求文档** | 新项目从零造、老项目按需改造（主入口） | 在项目根写 `需求文档.md`（或 `需求/*.md`、`BACKLOG.md`），triage 把每条需求拆成可独立交付的任务；**老项目下 triage 会先读需求关联的现有代码再拆** |
| open issue | 已有项目的待办 | 把需求写成 GitHub issue（需在 `.mcp.json` 加 github 连接器，见 `.mcp.json.example`） |
| CI 失败 | 修红 | 自动读 |
| 代码 `TODO`/`FIXME` | 边写边记的小活 | 自动读 |

### 新项目（绿地从零开始）

```
1. 新建空 git 仓库（连好 GitHub 远程）
2. bash install-loop.sh <你的项目>，填好 .claude/loop.env（模式+语言+命令）
3. 在项目根写 需求文档.md —— 把客户的想法写成一条条功能需求 + 完成标准
4. 跑 /loop-cycle：triage 读需求→拆任务→generator 实现→evaluator 验证→（C档）合并→交付客户
5. 需求做完了就再往 需求文档.md / BACKLOG.md 追加新需求，循环继续
```

### 老项目（存量改造）

老项目的关键差别：改之前要**先读懂需求关联的现有代码**，否则容易踩坏存量功能。这条循环已内建：triage 拆任务时会定位关联代码、generator 实现前会先读关联代码再做最小改动。

```
1. bash install-loop.sh <现有仓库>，完成上文 sidecar 文件的合并（CLAUDE.loop.md / .mcp.loop.json）
2. 填好 .claude/loop.env（按现有项目的真实语言/目录/测试命令填，命令要能真跑通）
3. 在项目根写 需求文档.md —— 把客户要改/要加的需求写清楚（最好点名涉及的模块/页面/接口）
4. 跑 /loop-cycle：triage 读需求→读关联现有代码→拆任务（标注受影响文件）→generator 读代码后最小改动→evaluator 验证不破坏存量→（C档）合并→交付客户
5. 建议先用 B 档（AUTO_MERGE=false 只开PR）跑几圈，确认改动安全再开 C 档
```

> 需求写得越具体（接口/字段/涉及模块/完成标准越清晰），triage 拆得越准、交付越稳。写不清的会被丢进 `inbox.md` 等你补充，不会瞎猜。

`需求文档.md` 示例（最小）：
```markdown
# 需求：待办 API
1. POST /todos 新建（字段 title）  | 完成标准: 返回201+id，pytest覆盖
2. GET /todos 列出全部            | 完成标准: 返回数组，pytest覆盖
技术约定: Python+FastAPI，内存存储，pytest
# 老项目追加示例（点名涉及模块，triage 会先读这些代码）
3. 给 GET /todos 加分页（涉及 app/routers/todos.py） | 完成标准: 支持 ?page&size，不破坏现有返回结构，pytest 覆盖新旧行为
```

## 启动

1. **手动跑一圈**：在目标项目里运行 `/loop-cycle`（本工程自带的命令，见 `.claude/commands/loop-cycle.md`），它按 `.claude/loop.md` 执行一整圈。先用它把流程跑顺。
2. **定时自动跑**：用间隔运行器驱动该命令，例如每 30 分钟一圈：`/loop 30m /loop-cycle`。
   - `/loop` 间隔运行器来自 superpowers 的 loop skill；**没有它也行**——用 OS cron / GitHub Actions 定时调用 `/loop-cycle` 即可。

> **首次会弹 MCP 批准框**：第一次加载本仓库的 `.mcp.json` 时，Claude Code 出于安全会弹窗让你确认是否信任并启用其中的 MCP 服务器（如 Playwright）。这是正常机制，点同意即可；拒绝则前端浏览器评判用不了。需要 Node/npx 可用（`npx @playwright/mcp` 首次会自动下载）。

## 文件地图

| 路径 | 作用 |
|------|------|
| `doc/项目详解.md` | **项目详解**：分层架构、一圈逐步拆解、三道护栏、新老项目工作流、FAQ |
| `CLAUDE.md` | 总纲：配置指引、项目规约、安全约定、急停 |
| `.claude/loop.env` | **唯一配置文件**：模式/语言/命令/参数/档位 |
| `.mcp.json` | 项目级 MCP（自带 Playwright，clone 即用） |
| `.mcp.json.example` | 加 GitHub/DB 等连接器的参考（token 用 env） |
| `install-loop.sh` | 一键把模板装进任意项目 |
| `.claude/loop.md` | 一圈五动作的编排（由 `/loop-cycle` 执行） |
| `.claude/commands/loop-cycle.md` | `/loop-cycle` 命令：跑一圈的入口 |
| `.claude/settings.json` | 注册 3 个 hook（MCP 配在 `.mcp.json`） |
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
| 交付 | Worktrees | `loop-implement`（`git worktree`） |
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
3. 信任建立后，再开 C 档自动合并，并确认护栏都生效（`gate-stop` / `token-guard` / `danger-guard` 三道 hook + 独立评判者）。

## 许可证与致谢

- 本项目以 **MIT License** 开源（见 `LICENSE`），可自由使用、修改、商用。
- 设计依据《Loop Engineering 橙皮书》（作者 alchaincyf，MIT 许可）：<https://github.com/alchaincyf/loop-engineering-orange-book>。本仓库是依其理念的独立实现；橙皮书 PDF 为第三方版权材料，已通过 `.gitignore` 排除，不随本仓库分发。
