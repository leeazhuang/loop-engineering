# 软件开发 Loop 工程 · 总纲

本仓库是一条**自动化软件开发循环**的通用模板（依据《Loop Engineering 橙皮书》）。
循环每圈：发现任务 → 隔离交付 → 生成实现 → 独立评判 → 持久化 → 调度下一圈。

> ⚠️ 当前为 **C 档（评判通过即自动合并 main）**，风险最高。护栏全开。
> 想更安全：见 `README.md` 的「降级到 B 档」。

## 启动前的唯一配置

**所有命令和参数都在一个文件里：`.claude/loop.env`。** 套用到新项目时，你只改这一个文件，其余文件不用动。

先选 **`PROJECT_MODE`**：`frontend`(纯前端) / `backend`(纯后端) / `fullstack`(前后端)。然后填对应侧语言与命令：
- 含前端 → `FE_LANG` / `FE_DIR` / `FE_TEST_CMD` / `FE_LINT_CMD` / `FE_BUILD_CMD` / `FE_RUN_CMD`
- 含后端 → `BE_LANG` / `BE_DIR` / `BE_TEST_CMD` / `BE_LINT_CMD` / `BE_BUILD_CMD` / `BE_RUN_CMD`
- 通用 → `MAIN_BRANCH` / `AUTO_MERGE`(C档=true,B档=false) / `MAX_FIX_ATTEMPTS` / `PER_LOOP_BUDGET` / `DAILY_BUDGET` / `MAX_RETRIES`

**MCP（项目级）**：项目根的 `.mcp.json` 已自带 Playwright，clone 即用（前端评判靠它）。要加 GitHub/数据库等连接器，参考 `.mcp.json.example` 合并，token 用 `${ENV_VAR}` 不要硬编码。

全栈模式下任务会被打 `[fe]`/`[be]`/`[both]` 层标签：generator 据此进对应目录，evaluator 据此选验证方式（前端走 Playwright 浏览器、后端走 API/测试），`gate-stop` 硬门两侧都跑。

**项目规约**（命名/分层/测试约定等给模型读的自由文本）写在下方「项目规约」一节，不放 loop.env。

## 项目规约

<!-- 在这里写本项目的约定：目录结构、命名、测试规范、不可触碰的区域等。generator/evaluator 会读这里。 -->
（套用到新项目后填写）

## 安全约定（强制）

1. **一圈只推进一个任务**，控制影响面。
2. **生成者与评判者必须是不同子 agent**，绝不让写代码的 agent 给自己打分。
3. **任何 gate 不过 → 不推进，写入 `.claude/memory/inbox.md` 等人**。绝不绕过硬门、绝不 `--no-verify`、绝不删测试来"过关"。
4. **禁止**：`git push --force` 到主分支、`git reset --hard`、`rm -rf`、删分支、改 CI 配置。这些由 `danger-guard.sh` 拦截，也是你的红线。
5. 能写死规则的判断交给 hook，不交给模型。

## 三种急停

1. 设环境变量 `CLAUDE_CODE_DISABLE_CRON=1` —— 关掉所有定时。
2. 创建文件 `.claude/memory/STOP` —— 每圈开头检测到它就整圈跳过（最快刹车）。
3. 直接停掉 `/loop` 会话。

## 一圈流程

详见 `.claude/loop.md`。启动：填好 `.claude/loop.env` 后，手动跑一圈用 `/loop-cycle`；定时自动跑用 `/loop 30m /loop-cycle`（间隔运行器，见 README「启动」）。
