#!/bin/bash
# 向运行中的 AgentDock 灌一段模拟的 Claude Code 会话事件,用于端到端验证 UI。
set -e
SOCK="$HOME/.agentdock/agentdock.sock"
[ -S "$SOCK" ] || { echo "AgentDock 未运行($SOCK 不存在)"; exit 1; }

emit() {
  printf '{"source":"claude-code","type":"hook","payload":{"session_id":"agentdock-demo","hook_event_name":"%s","cwd":"/tmp/agentdock-demo","tool_name":"%s"}}\n' "$1" "$2" \
    | nc -U -w 1 "$SOCK"
}
metrics() {
  printf '{"source":"claude-code","type":"statusline","payload":{"session_id":"agentdock-demo","model":{"display_name":"Opus"},"cost":{"total_cost_usd":0.42},"context_window":{"used_percentage":37}}}\n' \
    | nc -U -w 1 "$SOCK"
}

echo "SessionStart";       emit SessionStart "";        sleep 2
echo "UserPromptSubmit";   emit UserPromptSubmit "";    metrics; sleep 2
echo "PreToolUse(Bash)";   emit PreToolUse "Bash";      sleep 3
echo "Notification(审批)"; emit Notification "";        sleep 6
echo "PostToolUse";        emit PostToolUse "Bash";     sleep 2
echo "Stop";               emit Stop ""
echo "done — 面板中会话应显示 已完成"
