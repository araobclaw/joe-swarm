#!/bin/bash
# Task management for Open Brain, from Joe's workspace.
# Usage:
#   open-brain-tasks.sh list [pending|done|cancelled]  — list tasks
#   open-brain-tasks.sh stats                          — task statistics
#   open-brain-tasks.sh complete <id>                  — mark task done (8-char prefix OK)
#   open-brain-tasks.sh cancel <id>                    — cancel a task
#   open-brain-tasks.sh create '<json>'                — create task
#   open-brain-tasks.sh update '<json>'                — update task fields

set -euo pipefail

URL="http://localhost:8100/mcp"
KEY="1e536a81182a29a8f8e2ca0393f824314fad0763ef9096c0aefc18d68397a1c2"

mcp_call() {
  local tool="$1"
  local args="$2"
  curl -s -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "x-brain-key: $KEY" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}" \
    | python3 -c "import json,sys; r=json.load(sys.stdin); print(r.get('result',{}).get('content',[{}])[0].get('text','error'))"
}

# Resolve 8-char ID prefix to full UUID via the API
resolve_id() {
  local prefix="$1"
  if [ ${#prefix} -ge 36 ]; then
    echo "$prefix"
    return
  fi
  # List all pending tasks + grep for prefix
  local full
  full=$(mcp_call "list_tasks" '{"limit":50}' | grep -oP "ID: ${prefix}[a-f0-9-]+" | head -1 | sed 's/ID: //')
  if [ -z "$full" ]; then
    echo "error: no task found with prefix $prefix" >&2
    exit 1
  fi
  echo "$full"
}

CMD="${1:-list}"
shift || true

case "$CMD" in
  list)
    STATUS="${1:-pending}"
    mcp_call "list_tasks" "{\"status\":\"$STATUS\",\"limit\":30}"
    ;;
  stats)
    mcp_call "task_stats" "{}"
    ;;
  complete)
    ID="${1:?Usage: open-brain-tasks.sh complete <task-id>}"
    FULL=$(resolve_id "$ID")
    mcp_call "complete_task" "{\"id\":\"$FULL\"}"
    ;;
  cancel)
    ID="${1:?Usage: open-brain-tasks.sh cancel <task-id>}"
    FULL=$(resolve_id "$ID")
    mcp_call "update_task" "{\"id\":\"$FULL\",\"status\":\"cancelled\"}"
    ;;
  create)
    JSON="${1:?Usage: open-brain-tasks.sh create '<json>'}"
    mcp_call "create_task" "$JSON"
    ;;
  update)
    JSON="${1:?Usage: open-brain-tasks.sh update '<json with id>'}"
    mcp_call "update_task" "$JSON"
    ;;
  *)
    echo "Usage: open-brain-tasks.sh {list|stats|complete|cancel|create|update} [args]"
    exit 1
    ;;
esac
