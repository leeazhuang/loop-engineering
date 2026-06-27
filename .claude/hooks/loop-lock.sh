#!/usr/bin/env bash
# loop-lock.sh —— 单飞锁（single-flight lock），防「上一圈没跑完，下一圈又开始」导致同一任务被做两遍。
#
# 不是 hook，是 loop.md 第 0 步/收尾显式调用的脚本。两条子命令：
#   acquire  在圈开头抢锁。退出码：0=拿到锁，继续跑本圈；10=已有别的圈在跑，本圈什么都不做直接结束。
#   release  在圈结束时放锁（任何结束路径都要调，幂等，重复调用无害）。退出码恒 0。
#
# 为什么用「锁目录 + mkdir」：mkdir 是 POSIX 原子操作，两圈同瞬间抢锁只有一个能建成，
#   天然防竞态；普通 `[ -f ] && touch` 有 check-then-act 间隙，不可靠。
#
# 防死锁（这类锁最致命的坑）：若某圈跑到一半崩了/会话被杀，没机会 release → 锁永远在 →
#   之后每圈都跳过 → 整个循环卡死。对策：锁里记开始时间戳，新圈见锁先看「锁有多旧」：
#     - 还新鲜（< LOOP_LOCK_TIMEOUT）→ 上一圈真在干活 → 跳过（exit 10）。
#     - 已过期（>= LOOP_LOCK_TIMEOUT）→ 上一圈多半已崩 → 偷锁、接着干（自动恢复，不卡死）。
#   ⚠ 因此 LOOP_LOCK_TIMEOUT 必须 > 你最长一圈的真实耗时，否则会把还在认真跑的圈误判过期、
#     被新圈偷锁 → 又重叠了。先手动跑几圈看最慢任务多久，再据此调大该值。
#
# 配置来自 .claude/loop.env 的 LOOP_LOCK_TIMEOUT（支持 s/m/h 后缀，默认 90m）。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../loop.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

LOCKDIR="$SCRIPT_DIR/../memory/loop.lock.d"
META="$LOCKDIR/meta"

# 把 "90m" / "2h" / "300s" / 裸数字(按秒) 解析成秒。非法值回退到 5400(=90m)。
parse_seconds() {
  local v="${1:-}" n unit
  case "$v" in
    "" ) echo 5400; return ;;
  esac
  n="${v%[smhSMH]}"          # 去掉末尾单位字符
  unit="${v##$n}"            # 剩下的就是单位（可能为空）
  case "$n" in ''|*[!0-9]*) echo 5400; return ;; esac
  case "$unit" in
    s|S|"") echo "$n" ;;
    m|M)    echo $((n * 60)) ;;
    h|H)    echo $((n * 3600)) ;;
    *)      echo 5400 ;;
  esac
}

TIMEOUT_S="$(parse_seconds "${LOOP_LOCK_TIMEOUT:-90m}")"

now_epoch() { date +%s; }

case "${1:-}" in
  acquire)
    mkdir -p "$(dirname "$LOCKDIR")" 2>/dev/null
    if mkdir "$LOCKDIR" 2>/dev/null; then
      # 原子地建成锁目录 = 当前没有别的圈，干净拿到锁。
      printf '%s\n%s\n%s\n' "$(now_epoch)" "$$" "$(date '+%F %T')" > "$META"
      echo "[loop-lock] 已获取锁，开始本圈。" >&2
      exit 0
    fi
    # 锁已存在 —— 看它有多旧。
    LOCK_TS="$(head -n1 "$META" 2>/dev/null | tr -d '\r')"
    case "$LOCK_TS" in ''|*[!0-9]*) LOCK_TS=0 ;; esac
    AGE=$(( $(now_epoch) - LOCK_TS ))
    if [ "$LOCK_TS" -ne 0 ] && [ "$AGE" -lt "$TIMEOUT_S" ]; then
      echo "[loop-lock] 已有圈在跑（锁 ${AGE}s 前建立，未超时 ${TIMEOUT_S}s）。本圈跳过，什么都不做。" >&2
      exit 10
    fi
    # 过期（或 meta 损坏）→ 上一圈多半已崩，偷锁接管，避免永久卡死。
    printf '%s\n%s\n%s\n' "$(now_epoch)" "$$" "$(date '+%F %T')" > "$META"
    echo "[loop-lock] ⚠ 检测到过期锁（${AGE}s 前建立，已超 ${TIMEOUT_S}s）——上一圈疑似崩溃未释放，偷锁接管本圈。" >&2
    exit 0
    ;;
  release)
    if [ -d "$LOCKDIR" ]; then
      rm -rf "$LOCKDIR" 2>/dev/null
      echo "[loop-lock] 已释放锁。" >&2
    else
      echo "[loop-lock] 无锁可释放（已是空闲态）。" >&2
    fi
    exit 0
    ;;
  *)
    echo "[loop-lock] 用法：loop-lock.sh {acquire|release}" >&2
    exit 0
    ;;
esac
