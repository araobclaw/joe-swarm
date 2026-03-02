#!/bin/bash
# Shelley CLI helper for OpenClaw
# Usage: shelley.sh <command> [args]

SHELLEY_URL="http://localhost:9999"
HEADERS='-H "X-Exedev-Userid: 1" -H "X-Shelley-Request: 1"'
LOG_FILE="$HOME/.openclaw/workspace/skills/shelley/shelley-usage.log"

# Log function
log_usage() {
  echo "$(date -Iseconds) | $1" >> "$LOG_FILE"
}

case "$1" in
  start)
    # Start a new conversation
    # Usage: shelley.sh start "<message>" [model] [cwd]
    MESSAGE="$2"
    MODEL="${3:-claude-opus-4.6}"
    CWD="${4:-/home/exedev}"
    
    if [ -z "$MESSAGE" ]; then
      echo "Usage: shelley.sh start \"<message>\" [model] [cwd]" >&2
      exit 1
    fi
    
    PAYLOAD=$(python3 -c "import json; print(json.dumps({'message': '''$MESSAGE''', 'model': '$MODEL', 'cwd': '$CWD'}))")
    
    RESULT=$(curl -s -X POST -H "Content-Type: application/json" -H "X-Exedev-Userid: 1" -H "X-Shelley-Request: 1" \
      "$SHELLEY_URL/api/conversations/new" \
      -d "$PAYLOAD")
    
    CONV_ID=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('conversation_id','unknown'))" 2>/dev/null)
    log_usage "START | conv=$CONV_ID | model=$MODEL | msg=${MESSAGE:0:100}"
    echo "$RESULT"
    ;;
    
  status)
    # Check conversation status
    # Usage: shelley.sh status <conversation_id>
    CONV_ID="$2"
    
    if [ -z "$CONV_ID" ]; then
      echo "Usage: shelley.sh status <conversation_id>" >&2
      exit 1
    fi
    
    curl -s -H "X-Exedev-Userid: 1" "$SHELLEY_URL/api/conversations" | \
      python3 -c "
import json,sys
convs = json.load(sys.stdin)
for c in convs:
    if c['conversation_id'] == '$CONV_ID':
        print(f\"conversation_id: {c['conversation_id']}\")
        print(f\"working: {c['working']}\")
        print(f\"slug: {c.get('slug', 'N/A')}\")
        print(f\"model: {c.get('model', 'N/A')}\")
        sys.exit(0)
print('Conversation not found')
sys.exit(1)"
    ;;
    
  response)
    # Get conversation response (last agent message)
    # Usage: shelley.sh response <conversation_id>
    CONV_ID="$2"
    
    if [ -z "$CONV_ID" ]; then
      echo "Usage: shelley.sh response <conversation_id>" >&2
      exit 1
    fi
    
    log_usage "RESPONSE | conv=$CONV_ID"
    curl -s -H "X-Exedev-Userid: 1" "$SHELLEY_URL/api/conversation/$CONV_ID" | \
      python3 -c "
import json,sys
data = json.load(sys.stdin)
last_agent_text = ''
for msg in data.get('messages', []):
    if msg['type'] == 'agent':
        llm = json.loads(msg.get('llm_data', '{}'))
        for content in llm.get('Content', []):
            if content.get('Text'):
                last_agent_text = content['Text']
print(last_agent_text)"
    ;;
    
  full)
    # Get full conversation with all messages
    # Usage: shelley.sh full <conversation_id>
    CONV_ID="$2"
    
    if [ -z "$CONV_ID" ]; then
      echo "Usage: shelley.sh full <conversation_id>" >&2
      exit 1
    fi
    
    curl -s -H "X-Exedev-Userid: 1" "$SHELLEY_URL/api/conversation/$CONV_ID" | \
      python3 -c "
import json,sys
data = json.load(sys.stdin)
for msg in data.get('messages', []):
    print(f\"=== {msg['type'].upper()} (seq {msg['sequence_id']}) ===\")
    if msg['type'] in ['user', 'agent']:
        llm = json.loads(msg.get('llm_data', '{}'))
        for content in llm.get('Content', []):
            if content.get('Text'):
                print(content['Text'][:2000])
                if len(content.get('Text', '')) > 2000:
                    print('... (truncated)')
    print()"
    ;;
    
  send)
    # Send follow-up message
    # Usage: shelley.sh send <conversation_id> "<message>"
    CONV_ID="$2"
    MESSAGE="$3"
    
    if [ -z "$CONV_ID" ] || [ -z "$MESSAGE" ]; then
      echo "Usage: shelley.sh send <conversation_id> \"<message>\"" >&2
      exit 1
    fi
    
    PAYLOAD=$(python3 -c "import json; print(json.dumps({'message': '''$MESSAGE'''}))")
    
    curl -s -X POST -H "Content-Type: application/json" -H "X-Exedev-Userid: 1" -H "X-Shelley-Request: 1" \
      "$SHELLEY_URL/api/conversation/$CONV_ID/chat" \
      -d "$PAYLOAD"
    log_usage "SEND | conv=$CONV_ID | msg=${MESSAGE:0:100}"
    echo "Message sent"
    ;;
    
  list)
    # List all conversations
    # Usage: shelley.sh list
    curl -s -H "X-Exedev-Userid: 1" "$SHELLEY_URL/api/conversations" | \
      python3 -c "
import json,sys
convs = json.load(sys.stdin)
for c in convs:
    status = 'WORKING' if c['working'] else 'DONE'
    slug = c.get('slug', 'no-slug')[:30]
    print(f\"{c['conversation_id']}  [{status:7}]  {slug}\")"
    ;;
    
  wait)
    # Wait for conversation to complete
    # Usage: shelley.sh wait <conversation_id> [timeout_seconds]
    CONV_ID="$2"
    TIMEOUT="${3:-300}"
    
    if [ -z "$CONV_ID" ]; then
      echo "Usage: shelley.sh wait <conversation_id> [timeout_seconds]" >&2
      exit 1
    fi
    
    START=$(date +%s)
    while true; do
      WORKING=$(curl -s -H "X-Exedev-Userid: 1" "$SHELLEY_URL/api/conversations" | \
        python3 -c "
import json,sys
convs = json.load(sys.stdin)
for c in convs:
    if c['conversation_id'] == '$CONV_ID':
        print('True' if c['working'] else 'False')
        sys.exit(0)
print('False')")
      
      if [ "$WORKING" = "False" ]; then
        echo "Complete"
        exit 0
      fi
      
      NOW=$(date +%s)
      ELAPSED=$((NOW - START))
      if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "Timeout after ${TIMEOUT}s"
        exit 1
      fi
      
      echo "Waiting... (${ELAPSED}s)"
      sleep 5
    done
    ;;
    
  models)
    # List available models
    curl -s -H "X-Exedev-Userid: 1" "$SHELLEY_URL/api/models" | \
      python3 -c "
import json,sys
models = json.load(sys.stdin)
for m in models:
    ready = '✓' if m.get('ready', False) else '✗'
    print(f\"{ready} {m['id']}\")"
    ;;
    
  log)
    # Show usage log
    # Usage: shelley.sh log [lines]
    LINES="${2:-20}"
    if [ -f "$LOG_FILE" ]; then
      tail -n "$LINES" "$LOG_FILE"
    else
      echo "No log file yet. Usage is logged when start/send/response commands are used."
    fi
    ;;
    
  *)
    echo "Shelley CLI - Delegate tasks to Shelley coding agent"
    echo ""
    echo "Usage: shelley.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  start <message> [model] [cwd]   Start new conversation"
    echo "  status <conv_id>                Check if conversation is done"
    echo "  response <conv_id>              Get last agent response"
    echo "  full <conv_id>                  Get full conversation"
    echo "  send <conv_id> <message>        Send follow-up message"
    echo "  wait <conv_id> [timeout]        Wait for completion"
    echo "  list                            List all conversations"
    echo "  models                          List available models"
    echo "  log [lines]                     Show usage log (default: 20 lines)"
    echo ""
    echo "Example:"
    echo "  CONV=\$(shelley.sh start \"Explain Go interfaces\" | jq -r .conversation_id)"
    echo "  shelley.sh wait \$CONV"
    echo "  shelley.sh response \$CONV"
    ;;
esac
