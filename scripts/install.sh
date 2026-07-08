#!/bin/bash
# AgentDock 安装脚本:构建 → 交互式配置(语言/自启/集成/权限)→ 启动。
# 幂等,重复运行安全;所有问题都有默认值,一路回车即可。
set -euo pipefail

cd "$(dirname "$0")/.."
BIN=".build/arm64-apple-macosx/release/AgentDock"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
ask() {  # ask <提示> <默认值>
  local answer
  read -r -p "$1 [$2]: " answer
  echo "${answer:-$2}"
}

bold "== AgentDock 安装 =="

echo "[1/5] 构建 release 版本…"
swift build -c release >/dev/null
echo "      构建完成"

echo
bold "[2/5] 基础设置"
LANG_CHOICE=$(ask "  界面语言 (zh=简体中文 / en=English)" "zh")
AUTOSTART=$(ask "  开机自动启动? (yes/no)" "yes")

echo
bold "[3/5] Agent 集成(注册事件推送,提供亚秒级状态与面板内审批)"
INTEGRATIONS=""
[ "$(ask "  安装 Claude Code 集成? (yes/no)" "yes")" = "yes" ] && INTEGRATIONS="claude"
[ "$(ask "  安装 Codex 集成? (yes/no)" "yes")" = "yes" ] && INTEGRATIONS="${INTEGRATIONS:+$INTEGRATIONS,}codex"
[ "$(ask "  安装 Cursor 集成? (yes/no)" "yes")" = "yes" ] && INTEGRATIONS="${INTEGRATIONS:+$INTEGRATIONS,}cursor"

echo
bold "[4/5] 写入配置"
"$BIN" --setup "language=$LANG_CHOICE" "autostart=$AUTOSTART" "integrations=$INTEGRATIONS"

echo
bold "[5/5] 系统权限"
echo "  「辅助功能」用于 Codex/Cursor 的面板内审批代答(可选,稍后也可在设置页授权)。"
if [ "$(ask "  现在请求授权? (yes/no)" "yes")" = "yes" ]; then
  "$BIN" --setup "permissions=ask" || true
  echo "  如弹出系统设置,请勾选 AgentDock 后回来继续。"
fi

echo
echo "启动 AgentDock…"
launchctl remove dev.agentdock 2>/dev/null || true
sleep 1
launchctl submit -l dev.agentdock -o /tmp/agentdock.log -e /tmp/agentdock.err -- "$PWD/$BIN"
sleep 2
if lsof "$HOME/.agentdock/agentdock.sock" >/dev/null 2>&1; then
  bold "✓ 安装完成,AgentDock 正在运行(鼠标悬停屏幕顶部刘海区域即可展开)"
else
  bold "✗ 启动异常,请查看 /tmp/agentdock.err"
  exit 1
fi
