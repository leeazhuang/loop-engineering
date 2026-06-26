#!/usr/bin/env bash
# ============================================================
# install-loop.sh —— 把 Loop 工程模板装进任意项目
# 用法:
#   bash install-loop.sh <目标项目目录>
# 例:
#   bash install-loop.sh /d/work/my-app
#   bash install-loop.sh "C:/Users/Administrator/Desktop/my-app"
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

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 已存在 .claude 则备份，不覆盖用户现有配置
if [ -e "$TARGET/.claude" ]; then
  BAK="$TARGET/.claude.bak.$(date +%Y%m%d%H%M%S)"
  echo "⚠️  目标已有 .claude，备份到: $BAK"
  mv "$TARGET/.claude" "$BAK"
fi

echo "📦 拷贝模板到 $TARGET ..."
cp -r "$SRC/.claude"          "$TARGET/.claude"
cp -n "$SRC/CLAUDE.md"        "$TARGET/CLAUDE.md"        2>/dev/null || echo "   (保留已存在的 CLAUDE.md)"
cp -n "$SRC/.gitattributes"   "$TARGET/.gitattributes"   2>/dev/null || true
cp -n "$SRC/.mcp.json"        "$TARGET/.mcp.json"        2>/dev/null || echo "   (保留已存在的 .mcp.json)"
cp -n "$SRC/.mcp.json.example" "$TARGET/.mcp.json.example" 2>/dev/null || true

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

# 确保 hook 可执行（Windows 无影响，*nix 需要）
chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true

echo ""
echo "✅ 安装完成。下一步："
echo "   1. 编辑 $TARGET/.claude/loop.env  先选 PROJECT_MODE，再填对应侧 FE_LANG/FE_* 与 BE_LANG/BE_*"
echo "      （.mcp.json 已附带 Playwright，前端评判 clone 即用；要加 GitHub/DB 见 .mcp.json.example）"
echo "   2. 在 CLAUDE.md 的「项目规约」一节写本项目约定"
echo "   3. (Windows) 确保 git-bash 的 bash 在 PATH；建议装 jq、gh"
echo "   4. 想更安全：把 loop.env 的 AUTO_MERGE 设为 false（B档：只开PR不自动合并）"
echo "   5. 在该项目里运行: /loop 30m"
