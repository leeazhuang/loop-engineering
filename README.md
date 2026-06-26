# 软件开发 Loop 工程

**一条会自己干活的 AI 软件开发流水线。** 你把需求写清楚交给它，它自己拆任务、写代码、做测试、自我验收，最后开 PR 甚至直接合并——做完一件接着做下一件，像一条不停转的循环。

跑在 **Claude Code** 上，语言无关（前端、后端、全栈都行）。设计依据《Loop Engineering 橙皮书》。

---

## 它能帮你做什么

- **新项目**：客户给需求 → 你写成 `需求文档.md` → 循环从零把功能一个个做出来交付。
- **老项目**：客户要加功能/改东西 → 循环先读懂相关现有代码，再小心改、验证不破坏老功能、交付。

你做的事变成了：**写清需求 + 把关（review）**；重复的"拆活、写、测、提交"交给循环。

## 它是怎么转的（30 秒版）

每一圈，循环按顺序做五件事：

```
发现 → 交付 → 验证 → 持久化 → 调度
找活    开分支   独立验收   开PR/合并   安排下一圈
       写代码
```

关键设计：**写代码的 AI 和验收的 AI 是两个不同角色**（绝不自己给自己打分），底下还压着**四道写死的安全脚本**（防烧钱、拦危险命令、卡"测试全绿才放行"、未配置侧禁止自动合并）。所以它敢自动化，又不容易闯祸。

> 📖 想真正看懂它怎么运转、为什么这么设计、每个文件干什么 → 读 **[工程详解 · doc/工程详解.md](doc/工程详解.md)**。
> 只想用，继续往下看「使用教程」就够了。

> ⚠️ 默认是 **C 档（验收通过就自动合并 main）**，最省事也最激进。**生产环境建议先用 B 档（只开 PR 等你审）**，改一个值即可，见下文「使用说明」。

---

## 准备工作（第一次用，装一次）

| 需要 | 干嘛用的 | 怎么装 |
|------|----------|--------|
| **Claude Code CLI** | 整套循环的运行平台 | 见 Claude Code 官方 |
| **git** | 用 `git worktree` 给每个任务开隔离工作区 | 装 Git |
| **bash** | 跑三道护栏脚本 | Windows 用 git-bash 自带的 bash，确保在 PATH |
| **jq + gh** | jq 让护栏能精确计数/解析；gh 用来开 PR、合并 | `install-loop.sh` 会尝试自动装；失败就手动（见下） |
| **Node / npx** | 前端评判用 Playwright 开浏览器（纯后端不需要） | 装 Node，`npx @playwright/mcp` 首次自动下载 |

**手动装 jq/gh**（自动装失败时，尤其 Windows）：
- Windows（任选一种）：`scoop install jq gh` ／ `choco install jq gh -y` ／ `winget install jqlang.jq` + `winget install GitHub.cli`
  - winget 在 git-bash 里报 `Permission denied` 是常见现象，改到 **PowerShell/CMD** 里跑。
- macOS：`brew install jq gh`　Linux：`sudo apt-get install jq gh`
- 装好后跑一次 `gh auth login` 登录。

**对目标项目的要求**：必须是 **git 仓库**、有主分支（默认 `main`）、**已连 GitHub 远程**（开 PR 要用）。

---

## 使用教程（手把手）

### 第 1 步 · 把循环装进你的项目

```bash
bash install-loop.sh <你的项目目录>
# 例: bash install-loop.sh /d/work/my-app
```

它会把循环引擎（`.claude/`、`CLAUDE.md`、`.mcp.json` 等）拷进去，并重置运行状态。

- **新项目**：先 `git init` 建个空仓库、连好 GitHub 远程，再装。安装脚本会**自动把 `MAIN_BRANCH` 同步成你的实际分支名**（修 `git init` 默认 `master` 与默认 `main` 不一致的坑），在空仓库里**自动建一次初始提交**（循环开 `git worktree` 需要基线 commit），并**把主分支发布到 `origin`**（修「首圈开 PR 必崩」的坑：`gh pr create --base 主分支` 要求远程已存在该分支，而新仓库只在本地有提交、从没 push 过主分支）——所以装完就能直接 `/loop-cycle`。若机器没配 `git user.name/email` 导致自动提交失败、或没连远程/没登录导致推送失败，脚本会明确提示你手动补这一步。
- **老项目**：直接装进现有仓库。为不破坏你已有的配置，脚本**不覆盖**而是放备用文件让你合并：
  - 已有 `.claude` → 自动备份成 `.claude.bak.<时间戳>`。
  - 已有 `CLAUDE.md` → 循环总纲放成 `CLAUDE.loop.md`，请把里面**「安全约定」一节**并进你的 `CLAUDE.md`。
  - 已有 `.mcp.json` → 循环 MCP 放成 `.mcp.loop.json`，含前端时把 **`playwright`** 那段并进你的 `.mcp.json`。

### 第 2 步 · 改唯一的配置文件

打开 `<你的项目>/.claude/loop.env`，**只改这一个文件**。

1. 先选模式 `PROJECT_MODE`：`frontend`(纯前端) / `backend`(纯后端) / `fullstack`(前后端)。
2. 把对应侧的语言、目录、命令填成你项目真实能跑通的（详见下文「使用说明」的字段表）。

> ⚠️ 命令一定要填能真跑通的（比如后端 `pytest`、前端 `npm test`）。没填的那一侧会被 `merge-guard.sh` 护栏拦下、拒绝自动合并——"没验证 ≠ 通过"，这是写死的脚本判断，不靠模型自觉。

3. 顺手在 `CLAUDE.md` 的「项目规约」一节，写下本项目的命名/分层/测试约定（给 AI 读的自由文本）。

### 第 3 步 · 写需求文档（把活喂进来）

安装时已在项目根生成 `需求文档.md` 模板（若你原本没有 backlog）。打开它，把客户需求写成一条条**功能 + 完成标准**，替换掉里面的示例即可。写得越具体，循环拆得越准。

```markdown
# 需求：待办 API
1. POST /todos 新建（字段 title）   | 完成标准: 返回 201+id，pytest 覆盖
2. GET /todos 列出全部             | 完成标准: 返回数组，pytest 覆盖
技术约定: Python + FastAPI，内存存储，pytest

# 老项目示例：点名涉及的模块，循环会先读这些代码再改
3. 给 GET /todos 加分页（涉及 app/routers/todos.py）
   | 完成标准: 支持 ?page&size，不破坏现有返回结构，pytest 覆盖新旧行为
```

> 写不清、需要拍板的需求，循环不会瞎猜——会丢进 `.claude/memory/inbox.md` 等你补充。

### 第 4 步 · 跑起来

```
/loop-cycle
```

在你的项目里运行这个命令，它就**完整跑一圈**（发现→交付→验证→持久化→调度）。先用它手动跑顺。

想让它定时自动跑（比如每 30 分钟一圈）：

```
/loop 30m /loop-cycle
```

> `/loop` 来自 superpowers 的 loop skill；没有它也行——用系统 cron 或 GitHub Actions 定时调 `/loop-cycle` 即可。
> 首次加载 `.mcp.json` 会弹一个 MCP 批准框（问你是否信任 Playwright 等），点同意即可，拒绝则前端浏览器评判用不了。

**一圈做完会发生什么**：做完的功能进 PR（C 档自动合并、B 档等你审），进度记进 `loop-state.md`，下一圈接着做需求里的下一条。需求做完了，往 `需求文档.md` 追加新需求继续即可。

---

## 使用说明（参考手册）

### 配置文件 `loop.env` 字段

| 键 | 改成 |
|----|------|
| `PROJECT_MODE` | `frontend` / `backend` / `fullstack` |
| `FE_LANG` / `FE_DIR` / `FE_TEST_CMD` / `FE_LINT_CMD` / `FE_BUILD_CMD` / `FE_RUN_CMD` | 前端语言/目录/测试/检查/构建/启动命令（含前端时填） |
| `BE_LANG` / `BE_DIR` / `BE_TEST_CMD` / `BE_LINT_CMD` / `BE_BUILD_CMD` / `BE_RUN_CMD` | 后端语言/目录/测试/检查/构建/启动命令（含后端时填） |
| `MAIN_BRANCH` | 主分支名（默认 `main`） |
| `AUTO_MERGE` | `true`=C 档自动合并 ／ `false`=B 档只开 PR（切档位就改这一个值） |
| `MAX_FIX_ATTEMPTS` | 验收打回后最多重修几次（建议 3） |
| `PER_LOOP_BUDGET` / `DAILY_BUDGET` | 单圈/每日工具调用预算上限（防烧钱） |

> `*_RUN_CMD` 是给验收器起服务用的：前端起页面让浏览器点、后端起服务让它发真请求。
> 全栈模式下每个任务会自动打 `[fe]`/`[be]`/`[both]` 标签，决定进哪个目录、用哪种方式验。

### C 档 / B 档：自动程度的旋钮

改 `loop.env` 一个值切换：

```
AUTO_MERGE="false"   # B 档：验收+全绿后只开 PR，停下等你 review+merge（推荐生产用）
AUTO_MERGE="true"    # C 档：验收+全绿后自动合并 main（最省事，风险最高）
```

**建议从小到大**：先只跑发现（不改代码）→ 再开 B 档（开 PR 不合并）→ 信任建立后再开 C 档。

### 四道安全护栏（自动生效，不用配）

| 护栏 | 干什么 |
|------|--------|
| `danger-guard.sh` | 拦危险命令：`rm -rf`、强推、`reset --hard`、直推 main… 一律挡下转人工 |
| `token-guard.sh` | 守预算：工具调用超上限就停，防空转烧光额度 |
| `gate-stop.sh` | 全绿硬门：收尾时 test/lint/build 全绿才放行，AI 跳不过 |
| `merge-guard.sh` | 防零验证合并：自动合并前按 `PROJECT_MODE` 校验对应侧 test/lint/build 已真实配置（非占位符），未配齐即拦——"未配置≠通过"由脚本把守，不靠模型自觉 |

> 细节见 [工程详解 §5](doc/工程详解.md)。

### 三种急停

1. `export CLAUDE_CODE_DISABLE_CRON=1` —— 关掉所有定时。
2. `touch .claude/memory/STOP` —— 每圈开头检测到就整圈跳过（最快的刹车；删掉文件恢复）。
3. 直接停掉 `/loop` 会话。

### 上云（关机也能跑）

本地 `/loop` 要求机器开着。要睡觉/关机也跑，把 `loop.md` 的逻辑迁到 GitHub Actions schedule 或 Cloud Routines。注意云端最小间隔 1 小时、每次全新 clone（看不到本地未提交文件），适合"每天扫一遍 issue 提 PR"这类。

### Windows 一次性注意

1. **bash 在 PATH**：用 git-bash 的 bash，hook 才能被调起。
2. **换行**：`.gitattributes` 已强制 `.sh` 为 LF（CRLF 会让 bash 报 `\r` 错）。
3. **冒烟验证**：让 AI 试跑一条 `rm -rf` 看是否被 `danger-guard` 拦下（退出码 2）。不灵说明 hook 没生效。

### 工程目录速览

整个工程长什么样、每个文件干什么，见 **[工程详解 §12 · 工程目录详解](doc/工程详解.md)**。最常打交道的就两个：

- `.claude/loop.env` —— 唯一配置文件，套用新项目基本只改它。
- `CLAUDE.md` —— 总纲，在「项目规约」一节写本项目约定。

---

## 许可证与致谢

- 本项目以 **MIT License** 开源（见 `LICENSE`），可自由使用、修改、商用。
- 设计依据《Loop Engineering 橙皮书》（作者 alchaincyf，MIT 许可）：<https://github.com/alchaincyf/loop-engineering-orange-book>。本仓库是依其理念的独立实现；橙皮书 PDF 为第三方版权材料。
