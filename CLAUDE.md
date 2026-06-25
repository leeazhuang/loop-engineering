# 软件开发 Loop 工程 · 总纲

本仓库是一条**自动化软件开发循环**的通用模板（依据《Loop Engineering 橙皮书》）。
循环每圈：发现任务 → 隔离交付 → 生成实现 → 独立评判 → 持久化 → 调度下一圈。

> ⚠️ 当前为 **C 档（评判通过即自动合并 main）**，风险最高。护栏全开。
> 想更安全：见 `README.md` 的「降级到 B 档」。

## 启动前必须填的占位符

把以下占位符在对应文件里全局替换成你项目的真实值：

| 占位符 | 含义 | 示例 |
|--------|------|------|
| `<test_command>` | 跑测试 | `npm test` / `pytest` / `mvn test` |
| `<lint_command>` | 跑 lint | `npm run lint` / `ruff check .` |
| `<build_command>` | 构建 | `npm run build` / `mvn -q -DskipTests package` |
| `<run_command>` | 启动（评判器动手验证用） | `npm start` |
| `<main_branch>` | 主分支 | `main` |
| `<project_conventions>` | 项目规约（命名/分层/测试约定） | 自由文本 |
| `<mcp_config>` | 外部连接（可选） | GitHub/issue/Slack MCP |
| `<max_fix_attempts>` | 验证打回重试上限 | `3` |
| `<per_loop_budget>` | 单圈 token 预算 | `200000` |
| `<daily_budget>` | 每日 token 预算 | `2000000` |
| `<max_retries>` | 单圈最大工具重试 | `5` |

## 安全约定（强制）

1. **一圈只推进一个任务**，控制影响面。
2. **生成者与评判者必须是不同子 agent**，绝不让写代码的 agent 给自己打分。
3. **任何 gate 不过 → 不推进，写入 `.claude/memory/inbox.md` 等人**。绝不绕过硬门、绝不 `--no-verify`、绝不删测试来"过关"。
4. **禁止**：`git push --force` 到 `<main_branch>`、`git reset --hard`、`rm -rf`、删分支、改 CI 配置。这些由 `danger-guard.sh` 拦截，也是你的红线。
5. 能写死规则的判断交给 hook，不交给模型。

## 三种急停

1. 设环境变量 `CLAUDE_CODE_DISABLE_CRON=1` —— 关掉所有定时。
2. 创建文件 `.claude/memory/STOP` —— 每圈开头检测到它就整圈跳过（最快刹车）。
3. 直接停掉 `/loop` 会话。

## 一圈流程

详见 `.claude/loop.md`。启动：填好占位符后运行 `/loop 30m`。
