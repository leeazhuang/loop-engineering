#!/usr/bin/env bash
# ============================================================
# install-loop.sh —— 把 Loop 工程模板装进任意项目
# 用法:
#   bash install-loop.sh <目标项目目录>
# 例:
#   bash install-loop.sh /d/work/my-app
#   bash install-loop.sh "C:/Users/you/Desktop/my-app"
# 装完后：编辑 <目标>/.claude/loop.env 填好命令，即可在该项目里跑 /loop
# ============================================================
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "用法: bash install-loop.sh <目标项目目录>" >&2
  exit 1
fi
if [ ! -d "$TARGET" ]; then
  echo "❌ 目标目录不存在: $TARGET" >&2
  exit 1
fi

# 整条循环硬依赖 git（worktree 隔离、gh 开 PR、合并主分支）。目标若不是 git 仓库，
# 安装能成功但跑起来才莫名失败——这里提前清楚告警（不强制中止：用户可能装完再 git init）。
# 同时探测真实分支名与是否有提交：修两个 greenfield 首圈必崩的坑——
#   ① git init 默认分支常是 master，而 loop.env 默认 MAIN_BRANCH=main → 开 worktree 时 ref 不存在；
#   ② 空仓库零提交时，git worktree add <branch> 直接 fatal（没有基线 commit 可切）。
IS_GIT=0; REAL_BRANCH=""; HAS_COMMITS=0
if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IS_GIT=1
  # 有提交→当前分支；空仓库→HEAD 指向的待建分支名（master/main 等）
  REAL_BRANCH="$(git -C "$TARGET" symbolic-ref --short -q HEAD 2>/dev/null || true)"
  git -C "$TARGET" rev-parse --verify -q HEAD >/dev/null 2>&1 && HAS_COMMITS=1
else
  echo "⚠️  目标不是 git 仓库：$TARGET" >&2
  echo "    循环依赖 git worktree / gh 开 PR / 主分支。请在该目录先：git init && 连好 GitHub 远程，再开跑。" >&2
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# 强制依赖：jq + gh。两者是护栏的硬性前提——
#   jq：token-guard 预算守卫精确计数、danger-guard 精确解析命令；缺了护栏会失效/退化。
#   gh：loop-persist 开 PR / 合并主分支。
# 缺失则尝试用本机包管理器安装；装不上直接中止安装（不允许在没有护栏的情况下继续）。
# ============================================================
# 注：Windows 上 git-bash 调 winget 常因 App Execution Alias 报 "Permission denied"，
# 此时自动安装会失败——脚本会清楚提示，让你在 PowerShell/CMD 里手动装。scoop/choco 若装了会优先尝试。
detect_pm() {
  if   command -v scoop   >/dev/null 2>&1; then echo scoop
  elif command -v choco   >/dev/null 2>&1; then echo choco
  elif command -v winget  >/dev/null 2>&1; then echo winget
  elif command -v brew    >/dev/null 2>&1; then echo brew
  elif command -v apt-get >/dev/null 2>&1; then echo apt
  else echo ""; fi
}
require_dep() {
  local bin="$1" winget_id="$2" brew_id="$3" apt_id="$4" scoop_id="$5" choco_id="$6" pm
  if command -v "$bin" >/dev/null 2>&1; then
    echo "   ✓ $bin 已就绪"
    return 0
  fi
  pm="$(detect_pm)"
  echo "🔧 缺少必装依赖 $bin，尝试用 ${pm:-无可用包管理器} 安装 ..."
  case "$pm" in
    scoop)  scoop install "$scoop_id" || true ;;
    choco)  choco install "$choco_id" -y || true ;;
    winget) winget install --id "$winget_id" -e --source winget || true ;;
    brew)   brew install "$brew_id" || true ;;
    apt)    sudo apt-get update && sudo apt-get install -y "$apt_id" || true ;;
  esac
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "❌ $bin 仍不可用，但它是必装依赖，安装中止。请在真实终端手动安装后重试：" >&2
    echo "   Windows(任选): scoop install $scoop_id  |  choco install $choco_id  |  winget install $winget_id" >&2
    echo "     （winget 若在 git-bash 报 Permission denied，请改在 PowerShell/CMD 里跑）" >&2
    echo "   macOS:  brew install $brew_id" >&2
    echo "   Linux:  sudo apt-get install $apt_id" >&2
    exit 1
  fi
  echo "   ✓ $bin 安装完成"
}
echo "🔎 检查必装依赖 jq / gh ..."
#          bin winget_id    brew_id apt_id scoop_id choco_id
require_dep jq  jqlang.jq    jq      jq     jq       jq
require_dep gh  GitHub.cli   gh      gh     gh       gh

# 已存在 .claude 则备份，不覆盖用户现有配置
if [ -e "$TARGET/.claude" ]; then
  BAK="$TARGET/.claude.bak.$(date +%Y%m%d%H%M%S)"
  echo "⚠️  目标已有 .claude，备份到: $BAK"
  mv "$TARGET/.claude" "$BAK"
fi

echo "📦 拷贝模板到 $TARGET ..."
cp -r "$SRC/.claude"          "$TARGET/.claude"
cp -n "$SRC/.gitattributes"   "$TARGET/.gitattributes"   2>/dev/null || true
cp -n "$SRC/.mcp.json.example" "$TARGET/.mcp.json.example" 2>/dev/null || true

# 把 loop.env 的 MAIN_BRANCH 同步成目标仓库真实分支名（修 git init 默认 master 与默认 main 不一致的坑）。
# 这样 loop-implement 用 "git worktree add ... $MAIN_BRANCH" 时 ref 一定存在。
if [ "$IS_GIT" = "1" ] && [ -n "$REAL_BRANCH" ]; then
  ENVF="$TARGET/.claude/loop.env"
  if grep -q '^MAIN_BRANCH=' "$ENVF" 2>/dev/null; then
    # 用 | 作 sed 分隔符（替换文本里含 # 注释和 / 路径，不能用它们当分隔符）
    sed -i "s|^MAIN_BRANCH=.*|MAIN_BRANCH=\"$REAL_BRANCH\"               # 主分支名（安装时自动同步为目标仓库当前分支）|" "$ENVF"
    echo "   ✓ MAIN_BRANCH 已同步为目标仓库分支：$REAL_BRANCH"
  fi
fi

# 确保目标 .gitignore 忽略循环的运行态文件（current-worktree 每圈生成，绝不该入客户仓库）。
# 新项目 git init 后无 .gitignore→创建；老项目有→缺哪条补哪条，不动其它内容。
GI="$TARGET/.gitignore"
[ -f "$GI" ] || : > "$GI"
ensure_ignore() {
  local pat="$1"
  grep -qxF "$pat" "$GI" 2>/dev/null || printf '%s\n' "$pat" >> "$GI"
}
ensure_ignore ".claude/memory/current-worktree"
ensure_ignore ".mcp.local.json"

# 标记老项目（已有源码/CLAUDE.md/.mcp.json 的存量仓库），收尾时给出对应提示
IS_BROWNFIELD=0

# CLAUDE.md：老项目通常已有自己的总纲——绝不覆盖。改放 sidecar 并提示合并「安全约定」，
# 否则 generator/evaluator 读不到循环的安全红线与项目规约入口。
if [ -e "$TARGET/CLAUDE.md" ]; then
  IS_BROWNFIELD=1
  cp "$SRC/CLAUDE.md" "$TARGET/CLAUDE.loop.md"
  echo "   ⚠ 目标已有 CLAUDE.md（老项目）：Loop 总纲已放到 CLAUDE.loop.md，未覆盖你的 CLAUDE.md。"
  echo "     请把 CLAUDE.loop.md 的「安全约定」一节合并进你的 CLAUDE.md（项目规约/循环引导按需并入）。"
else
  cp "$SRC/CLAUDE.md" "$TARGET/CLAUDE.md"
fi

# .mcp.json：老项目可能已有自己的 MCP 配置——不覆盖。改放 sidecar 并提示合并 Playwright，
# 否则前端浏览器评判用不了。
if [ -e "$TARGET/.mcp.json" ]; then
  IS_BROWNFIELD=1
  cp "$SRC/.mcp.json" "$TARGET/.mcp.loop.json"
  echo "   ⚠ 目标已有 .mcp.json（老项目）：Loop 的 MCP（含 Playwright）已放到 .mcp.loop.json，未覆盖你的 .mcp.json。"
  echo "     含前端时请把 .mcp.loop.json 里的 playwright 服务器合并进你的 .mcp.json，否则前端评判用不了浏览器。"
else
  cp "$SRC/.mcp.json" "$TARGET/.mcp.json"
fi

# 重置运行态记忆（不要把模板项目的状态带过去）
echo '{"date":"1970-01-01","loop_calls":0,"daily_calls":0}' > "$TARGET/.claude/memory/budget.json"
cat > "$TARGET/.claude/memory/loop-state.md" <<'EOF'
# Loop 状态文件（记忆）

## 游标
- 上次运行：（首次运行前为空）
- 下圈从这里继续：（首次运行前为空）

## 待办
<!-- 任务格式：- [ ] [fe|be|both] (P1) 标题 | 来源 | 完成标准 -->

## 进行中

## 已完成
EOF
cat > "$TARGET/.claude/memory/inbox.md" <<'EOF'
# 收件箱（留给人）

> 循环处理不了、验证多次仍不过、或触碰红线的事写到这里等人。
EOF

# 脚手架：需求文档.md —— 用户喂需求的主入口（triage 第 0 源）。
# 仅当目标里还没有任何需求入口（需求文档.md / 需求/ / BACKLOG.md）时才生成模板，
# 不覆盖老项目可能已有的 backlog；新老项目都受益——装完直接往里粘客户需求即可开干。
if [ ! -e "$TARGET/需求文档.md" ] && [ ! -d "$TARGET/需求" ] && [ ! -e "$TARGET/BACKLOG.md" ]; then
  cat > "$TARGET/需求文档.md" <<'EOF'
# 需求文档

> 这是循环喂活的主入口。把客户需求写成一条条「功能 + 完成标准」，越具体循环拆得越准。
> 写不清、需要拍板的，循环不会瞎猜——会丢进 .claude/memory/inbox.md 等你补充。
> 一条做完接着下一条；需求做完了，往本文件追加新需求继续即可。

## 新项目（从零造）示例
1. POST /todos 新建（字段 title）   | 完成标准: 返回 201+id，pytest 覆盖
2. GET /todos 列出全部             | 完成标准: 返回数组，pytest 覆盖
技术约定: Python + FastAPI，内存存储，pytest

## 老项目（在现有代码上改）示例
3. 给 GET /todos 加分页（涉及 app/routers/todos.py）
   | 完成标准: 支持 ?page&size，不破坏现有返回结构，pytest 覆盖新旧行为
   说明: 点名涉及的模块/接口，循环会先读懂这些现有代码再小心改、验证不破坏老功能。

---
（把上面示例删掉，换成你的真实需求）
EOF
  echo "   ✓ 已生成需求入口模板: 需求文档.md（把客户需求填进去即可开干）"
fi

# 确保 hook 可执行（Windows 无影响，*nix 需要）
chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true

# 空仓库（零提交）兜底：循环开 worktree 需要一个基线 commit，否则首圈 git worktree add 直接 fatal。
# 此时刚拷进去的脚手架就是天然的第一个提交——自动建一次，让新项目真正"装完即可开干"。
# 失败（如未配 git user.name/email）则降级为明确提示，不中断安装。
NEED_MANUAL_COMMIT=0
if [ "$IS_GIT" = "1" ] && [ "$HAS_COMMITS" = "0" ]; then
  echo "🧱 目标仓库尚无提交，创建初始提交（循环开 worktree 需要基线 commit）..."
  if git -C "$TARGET" add -A && git -C "$TARGET" commit -q -m "chore: 初始化 loop 脚手架与项目文件"; then
    HAS_COMMITS=1
    echo "   ✓ 已创建初始提交（分支 ${REAL_BRANCH:-当前分支}）"
  else
    NEED_MANUAL_COMMIT=1
    echo "   ⚠ 自动初始提交失败（多半是未配置 git user.name/email）。" >&2
  fi
fi

# 把主分支发布到 origin —— 修「首圈开 PR 必崩」的坑：
# loop-persist 用 "gh pr create --base $MAIN_BRANCH" 开 PR，base 分支必须已存在于远程。
# 新项目 git init 后只在本地建了初始提交、从没 push 过主分支 → 远程没有该分支 →
# 首圈 gh pr create 直接报 "Base ref must be a branch / No commits between..."。
# 这里在装好后、有提交、且配了 origin 远程时，把主分支推上去（远程已有则跳过）。
# 推送失败（未配远程/没登录/无权限）只告警不中断——用户可稍后手动 push。
NEED_MANUAL_PUSH=0
if [ "$IS_GIT" = "1" ] && [ "$HAS_COMMITS" = "1" ] && [ -n "$REAL_BRANCH" ]; then
  if git -C "$TARGET" remote get-url origin >/dev/null 2>&1; then
    if git -C "$TARGET" ls-remote --exit-code --heads origin "$REAL_BRANCH" >/dev/null 2>&1; then
      echo "   ✓ 主分支 $REAL_BRANCH 已在 origin，无需发布。"
    else
      echo "🚀 发布主分支到 origin（首圈开 PR 需要远程 base 分支）..."
      if git -C "$TARGET" push -u origin "$REAL_BRANCH" >/dev/null 2>&1; then
        echo "   ✓ 已推送 $REAL_BRANCH 到 origin。"
      else
        NEED_MANUAL_PUSH=1
        echo "   ⚠ 推送 $REAL_BRANCH 到 origin 失败（未登录/无权限/远程未建好）。" >&2
      fi
    fi
  else
    NEED_MANUAL_PUSH=1
    echo "   ⚠ 未检测到 origin 远程：首圈开 PR 需要主分支已在 GitHub。请先连远程并推送主分支。" >&2
  fi
fi

echo ""
echo "✅ 安装完成。下一步："
echo "   1. 编辑 $TARGET/.claude/loop.env  先选 PROJECT_MODE，再填对应侧 FE_LANG/FE_* 与 BE_LANG/BE_*"
echo "      （.mcp.json 已附带 Playwright，前端评判 clone 即用；要加 GitHub/DB 见 .mcp.json.example）"
echo "   2. 在 CLAUDE.md 的「项目规约」一节写本项目约定"
echo "   3. (Windows) 确保 git-bash 的 bash 在 PATH；jq/gh 已由本脚本装好，记得 gh auth login 登录一次"
echo "   4. 想更安全：把 loop.env 的 AUTO_MERGE 设为 false（B档：只开PR不自动合并）"
echo "   5. 把客户需求填进项目根的 需求文档.md（已生成模板，新/老项目都用它喂活；老项目会先读关联现有代码再改）"
echo "   6. 在该项目里运行: /loop-cycle 跑一圈；定时自动跑用 /loop 30m /loop-cycle"
if [ "$IS_BROWNFIELD" = "1" ]; then
  echo ""
  echo "📌 检测到老项目（已有 CLAUDE.md / .mcp.json）：请先完成上面 ⚠ 提示的合并，再开跑。"
fi
if [ "$NEED_MANUAL_COMMIT" = "1" ]; then
  echo ""
  echo "❗ 仓库还没有任何提交，且自动初始提交失败。跑 /loop-cycle 前必须先手动提交一次（否则开 worktree 会失败）："
  echo "     git -C \"$TARGET\" config user.email you@example.com && git -C \"$TARGET\" config user.name you"
  echo "     git -C \"$TARGET\" add -A && git -C \"$TARGET\" commit -m \"chore: init\""
fi
if [ "$NEED_MANUAL_PUSH" = "1" ]; then
  echo ""
  echo "❗ 主分支尚未发布到 GitHub。首圈开 PR（gh pr create --base ${REAL_BRANCH:-主分支}）需要远程已有该分支，否则会报 'Base ref must be a branch'。开跑前先："
  echo "     git -C \"$TARGET\" remote add origin <你的GitHub仓库URL>   # 若还没连远程"
  echo "     git -C \"$TARGET\" push -u origin ${REAL_BRANCH:-主分支}"
fi
