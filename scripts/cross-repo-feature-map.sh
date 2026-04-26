#!/usr/bin/env bash
# scripts/cross-repo-feature-map.sh
# 重新扫描两条分支，自动生成 docs/feature-commit-map-auto.md
# §21.5 双仓 7 个功能 commit 映射表（hash 表 + 唯一性校验）。
#
# 注意：故意不开 -o pipefail，因为 `git log ... | head -1` 触发的 SIGPIPE
# 在 macOS 自带 bash 3.2 上会被识别为致命错误，导致脚本中途退出。

set -eu

cd "$(git rev-parse --show-toplevel)"

OUT="docs/feature-commit-map-auto.md"
BR_A="v5-android-source"
BR_H="v5-arkts-final"

desc_for() {
  case "$1" in
    1) echo "笔记列表渲染" ;;
    2) echo "笔记详情页"   ;;
    3) echo "RDB 持久化"   ;;
    4) echo "权限申请"     ;;
    5) echo "主题切换"     ;;
    6) echo "分享笔记"     ;;
    7) echo "设置页"       ;;
    *) echo ""             ;;
  esac
}

first_hash() {
  local branch="$1" n="$2"
  git log "$branch" --format="%H" --grep="^\[feat-$n\]" | sed -n '1p'
}

count_hash() {
  local branch="$1" n="$2"
  git log "$branch" --format="%H" --grep="^\[feat-$n\]" | wc -l | tr -d ' '
}

{
  echo "# §21.5 双仓 7 个功能 commit 映射表（自动生成）"
  echo
  echo "> 由 \`scripts/cross-repo-feature-map.sh\` 在 $(date '+%Y-%m-%d %H:%M:%S') 扫描生成。"
  echo "> 手写说明 / 关键 API 对照请看 [\`docs/feature-commit-map.md\`](./feature-commit-map.md)。"
  echo
  echo "| 功能编号 | 描述 | Android commit | 鸿蒙 commit |"
  echo "|---|---|---|---|"
  for n in 1 2 3 4 5 6 7; do
    desc=$(desc_for "$n")
    a=$(first_hash "$BR_A" "$n")
    h=$(first_hash "$BR_H" "$n")
    echo "| feat-$n | $desc | \`${a:0:8}\` | \`${h:0:8}\` |"
  done

  echo
  echo "## 唯一性校验"
  echo
  echo '```'
  for n in 1 2 3 4 5 6 7; do
    a_n=$(count_hash "$BR_A" "$n")
    h_n=$(count_hash "$BR_H" "$n")
    echo "feat-$n: android=$a_n harmony=$h_n (must be 1 each)"
  done
  echo '```'
} > "$OUT"

echo "[ok] generated $OUT"
