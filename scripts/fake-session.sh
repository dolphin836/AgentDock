#!/bin/bash
# 向运行中的 AgentDock 灌模拟会话,用于看「进行中」动效 / 轮播 / 分组。
#
# 用法:
#   ./scripts/fake-session.sh           # 默认:多会话停在进行中约 45 秒
#   ./scripts/fake-session.sh running   # 同上
#   ./scripts/fake-session.sh mcp       # 第三方/MCP 调用(任务名后显示短名)
#   ./scripts/fake-session.sh approval  # 2 个需要审批(黄机器人眨眼),保持约 30 秒
#   ./scripts/fake-session.sh cycle     # 完整生命周期(含审批→完成)
#   ./scripts/fake-session.sh clear     # 发 Stop 清掉演示会话
set -euo pipefail
SOCK="$HOME/.agentdock/agentdock.sock"
MODE="${1:-running}"

[ -S "$SOCK" ] || { echo "AgentDock 未运行($SOCK 不存在)。先启动 App 再跑本脚本。"; exit 1; }

emit() {
  local sid="$1" event="$2" tool="${3:-}" cwd="${4:-/tmp/agentdock-demo}"
  printf '{"source":"claude-code","type":"hook","payload":{"session_id":"%s","hook_event_name":"%s","cwd":"%s","tool_name":"%s"}}\n' \
    "$sid" "$event" "$cwd" "$tool" | nc -U -w 1 "$SOCK" >/dev/null || true
}

# Cursor 风格 CallMcpTool:带 server + toolName,展示名走 ingest 抽取
emit_cursor_mcp() {
  local sid="$1" cwd="$2" server="$3" tool_name="$4"
  printf '{"source":"cursor","type":"hook","payload":{"conversation_id":"%s","hook_event_name":"preToolUse","cwd":"%s","workspace_roots":["%s"],"tool_name":"CallMcpTool","tool_input":{"server":"%s","toolName":"%s"},"model":"composer-2"}}\n' \
    "$sid" "$cwd" "$cwd" "$server" "$tool_name" | nc -U -w 1 "$SOCK" >/dev/null || true
}

metrics() {
  local sid="$1" model="${2:-Opus}" pct="${3:-37}"
  printf '{"source":"claude-code","type":"statusline","payload":{"session_id":"%s","model":{"display_name":"%s"},"cost":{"total_cost_usd":0.42},"context_window":{"used_percentage":%s}}}\n' \
    "$sid" "$model" "$pct" | nc -U -w 1 "$SOCK" >/dev/null || true
}

start_running() {
  local sid="$1" cwd="$2" tool="$3" model="$4" pct="$5"
  emit "$sid" SessionStart "" "$cwd"
  sleep 0.15
  emit "$sid" UserPromptSubmit "" "$cwd"
  metrics "$sid" "$model" "$pct"
  sleep 0.15
  emit "$sid" PreToolUse "$tool" "$cwd"
}

case "$MODE" in
  clear)
    echo "停止演示会话…"
    for sid in agentdock-demo-a agentdock-demo-b agentdock-demo-c agentdock-demo \
               agentdock-demo-appr-a agentdock-demo-appr-b \
               agentdock-demo-mcp-a agentdock-demo-mcp-b agentdock-demo-mcp-c; do
      emit "$sid" Stop ""
    done
    echo "done"
    ;;

  mcp)
    echo "模拟 3 个第三方/MCP 调用(悬停刘海看任务名后的青色短名)…"
    echo "  A  notion/search     ·  Claude mcp__… 风格"
    echo "  B  telegram/send…    ·  Cursor CallMcpTool"
    echo "  C  claude-mem/…    ·  Claude mcp__… 风格"
    # A: Claude dunder 命名
    emit agentdock-demo-mcp-a SessionStart "" /tmp/agentdock-notion
    sleep 0.1
    emit agentdock-demo-mcp-a UserPromptSubmit "" /tmp/agentdock-notion
    metrics agentdock-demo-mcp-a Opus 44
    sleep 0.1
    emit agentdock-demo-mcp-a PreToolUse "mcp__plugin-notion-workspace-notion__search" /tmp/agentdock-notion
    sleep 1.2
    emit agentdock-demo-mcp-a PostToolUse "mcp__plugin-notion-workspace-notion__search" /tmp/agentdock-notion

    # B: Cursor CallMcpTool + tool_input
    printf '{"source":"cursor","type":"hook","payload":{"conversation_id":"agentdock-demo-mcp-b","hook_event_name":"sessionStart","workspace_roots":["/tmp/agentdock-telegram"],"model":"composer-2"}}\n' \
      | nc -U -w 1 "$SOCK" >/dev/null || true
    sleep 0.1
    printf '{"source":"cursor","type":"hook","payload":{"conversation_id":"agentdock-demo-mcp-b","hook_event_name":"beforeSubmitPrompt","workspace_roots":["/tmp/agentdock-telegram"],"model":"composer-2"}}\n' \
      | nc -U -w 1 "$SOCK" >/dev/null || true
    sleep 0.1
    emit_cursor_mcp agentdock-demo-mcp-b /tmp/agentdock-telegram \
      plugin-telegram-telegram send_message
    sleep 0.8
    printf '{"source":"cursor","type":"hook","payload":{"conversation_id":"agentdock-demo-mcp-b","hook_event_name":"postToolUse","workspace_roots":["/tmp/agentdock-telegram"],"tool_name":"CallMcpTool","tool_input":{"server":"plugin-telegram-telegram","toolName":"send_message"},"model":"composer-2"}}\n' \
      | nc -U -w 1 "$SOCK" >/dev/null || true

    # C: 另一个 Claude MCP
    emit agentdock-demo-mcp-c SessionStart "" /tmp/agentdock-mem
    sleep 0.1
    emit agentdock-demo-mcp-c UserPromptSubmit "" /tmp/agentdock-mem
    metrics agentdock-demo-mcp-c Sonnet 61
    sleep 0.1
    emit agentdock-demo-mcp-c PreToolUse "mcp__claude-mem__smart_search" /tmp/agentdock-mem
    sleep 1.0
    emit agentdock-demo-mcp-c PostToolUse "mcp__claude-mem__smart_search" /tmp/agentdock-mem

    echo "保持 MCP 调用约 45 秒(Ctrl+C 可提前结束;结束后自动 Stop)…"
    for i in $(seq 1 15); do
      sleep 2
      case $((i % 3)) in
        1)
          emit agentdock-demo-mcp-a PreToolUse "mcp__plugin-notion-workspace-notion__search" /tmp/agentdock-notion
          sleep 1
          emit agentdock-demo-mcp-a PostToolUse "mcp__plugin-notion-workspace-notion__search" /tmp/agentdock-notion
          ;;
        2)
          emit_cursor_mcp agentdock-demo-mcp-b /tmp/agentdock-telegram \
            plugin-telegram-telegram send_message
          sleep 1
          printf '{"source":"cursor","type":"hook","payload":{"conversation_id":"agentdock-demo-mcp-b","hook_event_name":"postToolUse","workspace_roots":["/tmp/agentdock-telegram"],"tool_name":"CallMcpTool","tool_input":{"server":"plugin-telegram-telegram","toolName":"send_message"},"model":"composer-2"}}\n' \
            | nc -U -w 1 "$SOCK" >/dev/null || true
          ;;
        0)
          emit agentdock-demo-mcp-c PreToolUse "mcp__claude-mem__smart_search" /tmp/agentdock-mem
          sleep 1
          emit agentdock-demo-mcp-c PostToolUse "mcp__claude-mem__smart_search" /tmp/agentdock-mem
          ;;
      esac
      printf "  …%ss\n" $((i * 3))
    done

    echo "收尾 → Stop"
    emit agentdock-demo-mcp-a Stop "" /tmp/agentdock-notion
    emit agentdock-demo-mcp-b Stop "" /tmp/agentdock-telegram
    emit agentdock-demo-mcp-c Stop "" /tmp/agentdock-mem
    echo "done"
    ;;

  approval)
    echo "模拟 2 个需要审批…"
    echo "  A  需要审批  ·  /tmp/agentdock-approve-a"
    echo "  B  需要审批  ·  /tmp/agentdock-approve-b"
    for sid_cwd in \
      "agentdock-demo-appr-a|/tmp/agentdock-approve-a|Bash|Opus|41" \
      "agentdock-demo-appr-b|/tmp/agentdock-approve-b|Edit|Sonnet|63"
    do
      IFS='|' read -r sid cwd tool model pct <<<"$sid_cwd"
      emit "$sid" SessionStart "" "$cwd"
      sleep 0.1
      emit "$sid" UserPromptSubmit "" "$cwd"
      metrics "$sid" "$model" "$pct"
      sleep 0.1
      emit "$sid" PreToolUse "$tool" "$cwd"
      sleep 0.1
      emit "$sid" Notification "" "$cwd"
    done
    echo "保持需要审批约 30 秒(Ctrl+C 可提前结束)…"
    for i in $(seq 1 10); do
      sleep 3
      emit agentdock-demo-appr-a Notification "" /tmp/agentdock-approve-a
      emit agentdock-demo-appr-b Notification "" /tmp/agentdock-approve-b
      printf "  …%ss\n" $((i * 3))
    done
    echo "收尾 → Stop"
    emit agentdock-demo-appr-a Stop "" /tmp/agentdock-approve-a
    emit agentdock-demo-appr-b Stop "" /tmp/agentdock-approve-b
    echo "done"
    ;;

  cycle)
    echo "完整生命周期(约 15s)…"
    emit agentdock-demo SessionStart "" /tmp/agentdock-demo
    sleep 1
    emit agentdock-demo UserPromptSubmit "" /tmp/agentdock-demo
    metrics agentdock-demo
    sleep 1
    emit agentdock-demo PreToolUse Bash /tmp/agentdock-demo
    sleep 3
    emit agentdock-demo Notification "" /tmp/agentdock-demo
    sleep 5
    emit agentdock-demo PostToolUse Bash /tmp/agentdock-demo
    sleep 1
    emit agentdock-demo Stop "" /tmp/agentdock-demo
    echo "done — 应进入 RECENT"
    ;;

  running|*)
    echo "模拟 3 个进行中任务(悬停刘海看面板;收起态会轮播)…"
    echo "  A  命令执行中  ·  /tmp/agentdock-alpha"
    echo "  B  检索中      ·  /tmp/agentdock-beta"
    echo "  C  编辑中      ·  /tmp/agentdock-gamma"
    start_running agentdock-demo-a /tmp/agentdock-alpha Bash Sonnet 28
    start_running agentdock-demo-b /tmp/agentdock-beta Grep Opus 55
    start_running agentdock-demo-c /tmp/agentdock-gamma Edit Haiku 12

    # 保持「进行中」:周期性补 PreToolUse,避免被当成空闲
    echo "保持进行中约 45 秒(Ctrl+C 可提前结束;结束后自动 Stop)…"
    for i in $(seq 1 15); do
      sleep 3
      case $((i % 3)) in
        1) emit agentdock-demo-a PreToolUse Bash /tmp/agentdock-alpha ;;
        2) emit agentdock-demo-b PreToolUse Grep /tmp/agentdock-beta ;;
        0) emit agentdock-demo-c PreToolUse Edit /tmp/agentdock-gamma ;;
      esac
      printf "  …%ss\n" $((i * 3))
    done

    echo "收尾 → Stop"
    emit agentdock-demo-a Stop "" /tmp/agentdock-alpha
    emit agentdock-demo-b Stop "" /tmp/agentdock-beta
    emit agentdock-demo-c Stop "" /tmp/agentdock-gamma
    echo "done"
    ;;
esac
