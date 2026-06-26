---
name: loop-persist
description: 循环第四步「持久化」。开 PR，C 档下自动合并 main，更新状态文件。
---

# loop-persist · 持久化

职责：把通过验证的改动落到对话之外的地方，并推进状态。

> 先读 `.claude/loop.env` 取 `MAIN_BRANCH`、`AUTO_MERGE`、`MCP_CONFIG`。

## 步骤
1. **提交改动**：generator 只写代码不提交，所以这里先在 worktree 里把本圈改动提交掉（没有 commit 就 push 不了分支、开不了 PR）。
   ```bash
   cd "<worktree 路径>"   # 即 .claude/memory/current-worktree 记录的路径
   git add -A             # 注意别带进运行态/临时文件；该 gitignore 的先 gitignore（如构建临时目录）
   git commit -m "<type>(<scope>): <本圈任务简述>"
   ```
2. **跑硬门（合并前必须显式跑一次）**：`gate-stop.sh` 既是 Stop 钩子，也要在这里**主动调用**作为合并前的确定性闸（此时 `current-worktree` 仍在、指向待验 worktree）。退出码非 0 一律不合并：
   ```bash
   bash .claude/hooks/gate-stop.sh || { echo "硬门未过，转人工"; }   # 非0 → 不进入合并，写 inbox
   ```
3. **开 PR**：把 worktree 分支推上去，开一个 PR（`MCP_CONFIG` 非空接 GitHub 则用 MCP；否则用 `gh pr create --base "$MAIN_BRANCH"`）。PR 描述写清：做了什么、为什么、对应任务、验证结果。
   - 首圈若报 `Base ref must be a branch` / `No commits between...`，多半是**主分支没发布到远程**（新项目常见）。这本应由安装脚本（`install-loop.sh`）在装好时自动 `git push -u origin <主分支>` 解决；若当时没远程/没登录而没推成，**不要在这里 push 主分支**——直推主分支是 `danger-guard` 的红线，agent 一跑必被拦。改为写 `.claude/memory/inbox.md`（"主分支未发布到远程，请人工 `git push -u origin <主分支>` 后重试本任务"）并结束本圈，转人工。
4. **合并（由 `AUTO_MERGE` 决定档位）**：
   - 前置条件（缺一不可）：`evaluator` 通过 **且** 上面第 2 步 `gate-stop.sh` 显式跑过且退出 0 **且** 本任务涉及的那一侧命令在 `loop.env` 里已真实填好。
   - **防零验证合并**：`gh pr merge` 这步有确定性硬门 `merge-guard.sh`（PreToolUse 钩子）兜底——它按 `PROJECT_MODE` 校验每一侧 `*_TEST_CMD`/`*_LINT_CMD`/`*_BUILD_CMD`，只要有占位符 `<...>`/空就 `exit 2` 拦掉自动合并，LLM 跳不过（呼应主轴原则"能写死的判断不交给模型"）。你在这里也要主动复查同样的条件：若发现未配置侧，别硬试合并，直接写 `inbox.md`（"loop.env 未配置该侧、无法验证，拒绝自动合并"）转人工。脚本是底线，你的复查是省一次无谓尝试。
   - `AUTO_MERGE="true"`（C 档）→ 自动合并到 `$MAIN_BRANCH`：`gh pr merge --squash --auto`。
   - `AUTO_MERGE="false"`（B 档，更安全）→ **不合并**，只留 PR，把"待人工 review+merge"记进 `loop-state.md`，结束本任务。
   - 切换档位只需改 loop.env 里的 `AUTO_MERGE`，不用动这个文件。
5. **更新状态**：
   - `loop-state.md`：把任务从「进行中」移到「## 已完成」，记录 PR 链接 / 合并 commit / 时间。
   - 清理用完的 worktree（cattle not pets）：`git worktree remove ".worktrees/loop-<任务短名>" --force`。
   - 删分支：**别用 `git branch -D`**——squash 合并后本地分支不算"已合并"，`git branch -d` 会失败、退到 `-D` 又会被 `danger-guard` 拦（强删分支是红线）。正确做法：
     - 远程分支：`git push origin --delete loop/<任务短名>`（合并后清理，允许）。
     - 本地分支引用：`git update-ref -d refs/heads/loop/<任务短名>`（删 ref，不触红线）。
   - 删掉 gate-stop 用的定位文件，避免下一圈用到过期路径：`rm -f .claude/memory/current-worktree`。

## 约束
- 绝不 `--no-verify`、绝不 `push --force` 到 `$MAIN_BRANCH`（`danger-guard.sh` 会拦）。
- 合并失败（冲突等）→ 不强推，写 `inbox.md` 转人工。
