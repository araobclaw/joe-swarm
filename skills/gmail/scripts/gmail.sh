#!/bin/bash
# Gmail CLI helper for OpenClaw
# Usage: gmail.sh <command> [args]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OAUTH_ENV="$WORKSPACE/gmail-oauth.env"
LOG_FILE="$SCRIPT_DIR/../gmail-usage.log"

source "$OAUTH_ENV"

log_usage() {
  echo "$(date -Iseconds) | $1" >> "$LOG_FILE"
}

# Get fresh access token
get_token() {
  local resp
  resp=$(curl -s -X POST https://oauth2.googleapis.com/token \
    -d "client_id=$GOOGLE_GMAIL_CLIENT_ID" \
    -d "client_secret=$GOOGLE_GMAIL_CLIENT_SECRET" \
    -d "refresh_token=$GOOGLE_GMAIL_REFRESH_TOKEN" \
    -d "grant_type=refresh_token")
  echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))"
}

gapi() {
  local token
  token=$(get_token)
  if [ -z "$token" ]; then
    echo '{"error":"Failed to refresh OAuth token"}'
    return 1
  fi
  curl -s -H "Authorization: Bearer $token" "$@"
}

case "${1:-help}" in

  ## ── READ ──────────────────────────────────────────────

  unread)
    # List unread messages. Usage: gmail.sh unread [max]
    MAX="${2:-10}"
    log_usage "unread max=$MAX"
    MSGS=$(gapi "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=is:unread&maxResults=$MAX")
    
    # If no messages, return early
    echo "$MSGS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
msgs = data.get('messages', [])
if not msgs:
    print(json.dumps({'count': 0, 'messages': []}))
    sys.exit(0)
print(json.dumps({'count': len(msgs), 'messageIds': [m['id'] for m in msgs]}))
"
    ;;

  read)
    # Read a message by ID. Usage: gmail.sh read <messageId> [format]
    MSG_ID="$2"
    FORMAT="${3:-full}"
    log_usage "read id=$MSG_ID format=$FORMAT"
    RESULT=$(gapi "https://gmail.googleapis.com/gmail/v1/users/me/messages/$MSG_ID?format=$FORMAT")
    
    echo "$RESULT" | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
headers = {h['name'].lower(): h['value'] for h in data.get('payload',{}).get('headers',[])}

# Extract body
def get_body(payload):
    if payload.get('body',{}).get('data'):
        return base64.urlsafe_b64decode(payload['body']['data']).decode('utf-8','replace')
    for part in payload.get('parts',[]):
        if part.get('mimeType','').startswith('text/plain') and part.get('body',{}).get('data'):
            return base64.urlsafe_b64decode(part['body']['data']).decode('utf-8','replace')
    for part in payload.get('parts',[]):
        body = get_body(part)
        if body: return body
    return ''

result = {
    'id': data.get('id'),
    'threadId': data.get('threadId'),
    'from': headers.get('from',''),
    'to': headers.get('to',''),
    'subject': headers.get('subject',''),
    'date': headers.get('date',''),
    'labels': data.get('labelIds',[]),
    'snippet': data.get('snippet',''),
    'body': get_body(data.get('payload',{}))
}
print(json.dumps(result, ensure_ascii=False))
"
    ;;

  search)
    # Search messages. Usage: gmail.sh search <query> [max]
    QUERY="$2"
    MAX="${3:-10}"
    log_usage "search query='$QUERY' max=$MAX"
    gapi "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))"  )&maxResults=$MAX"
    ;;

  ## ── SEND ──────────────────────────────────────────────

  send)
    # Send email. Usage: gmail.sh send <to> <subject> <body> [cc] [replyToMessageId]
    TO="$2"
    SUBJECT="$3"
    BODY="$4"
    CC="${5:-}"
    REPLY_TO="${6:-}"
    log_usage "send to=$TO subject='$SUBJECT'"
    
    RAW=$(python3 -c "
import base64, email.mime.text
msg = email.mime.text.MIMEText('''$BODY''', 'plain', 'utf-8')
msg['To'] = '$TO'
msg['From'] = 'Joe <joearaobassistant@gmail.com>'
msg['Subject'] = '$SUBJECT'
cc = '$CC'
if cc: msg['Cc'] = cc
reply_to = '$REPLY_TO'
if reply_to:
    msg['In-Reply-To'] = reply_to
    msg['References'] = reply_to
raw = base64.urlsafe_b64encode(msg.as_bytes()).decode()
print(raw)
")
    
    gapi "https://gmail.googleapis.com/gmail/v1/users/me/messages/send" \
      -X POST -H "Content-Type: application/json" \
      -d "{\"raw\":\"$RAW\"}"
    ;;

  send-raw)
    # Send with full JSON control. Usage: gmail.sh send-raw <json-file>
    # JSON file must contain {"to","subject","body","cc"(opt),"bcc"(opt)}
    JSON_FILE="$2"
    log_usage "send-raw file=$JSON_FILE"
    
    RAW=$(python3 -c "
import base64, json, email.mime.text, email.mime.multipart
with open('$JSON_FILE') as f:
    data = json.load(f)
msg = email.mime.text.MIMEText(data['body'], data.get('subtype','plain'), 'utf-8')
msg['To'] = data['to']
msg['From'] = 'Joe <joearaobassistant@gmail.com>'
msg['Subject'] = data['subject']
if data.get('cc'): msg['Cc'] = data['cc']
if data.get('bcc'): msg['Bcc'] = data['bcc']
if data.get('reply_to_message_id'):
    msg['In-Reply-To'] = data['reply_to_message_id']
    msg['References'] = data['reply_to_message_id']
raw = base64.urlsafe_b64encode(msg.as_bytes()).decode()
print(raw)
")
    
    gapi "https://gmail.googleapis.com/gmail/v1/users/me/messages/send" \
      -X POST -H "Content-Type: application/json" \
      -d "{\"raw\":\"$RAW\"}"
    ;;

  ## ── LABELS ────────────────────────────────────────────

  labels)
    # List all labels. Usage: gmail.sh labels
    log_usage "labels"
    gapi "https://gmail.googleapis.com/gmail/v1/users/me/labels" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for l in data.get('labels',[]):
    print(json.dumps({'id': l['id'], 'name': l['name'], 'type': l.get('type','')}))
"
    ;;

  label-create)
    # Create a label. Usage: gmail.sh label-create <name>
    NAME="$2"
    log_usage "label-create name='$NAME'"
    gapi "https://gmail.googleapis.com/gmail/v1/users/me/labels" \
      -X POST -H "Content-Type: application/json" \
      -d "{\"name\":\"$NAME\",\"labelListVisibility\":\"labelShow\",\"messageListVisibility\":\"show\"}"
    ;;

  label)
    # Apply label(s) to a message. Usage: gmail.sh label <messageId> <labelId> [labelId2...]
    MSG_ID="$2"
    shift 2
    LABEL_IDS=$(python3 -c "import json; print(json.dumps([$(printf '"%s",' "$@")]))") 
    log_usage "label id=$MSG_ID labels=$LABEL_IDS"
    gapi "https://gmail.googleapis.com/gmail/v1/users/me/messages/$MSG_ID/modify" \
      -X POST -H "Content-Type: application/json" \
      -d "{\"addLabelIds\":$LABEL_IDS}"
    ;;

  unlabel)
    # Remove label(s) from a message. Usage: gmail.sh unlabel <messageId> <labelId> [labelId2...]
    MSG_ID="$2"
    shift 2
    LABEL_IDS=$(python3 -c "import json; print(json.dumps([$(printf '"%s",' "$@")]))") 
    log_usage "unlabel id=$MSG_ID labels=$LABEL_IDS"
    gapi "https://gmail.googleapis.com/gmail/v1/users/me/messages/$MSG_ID/modify" \
      -X POST -H "Content-Type: application/json" \
      -d "{\"removeLabelIds\":$LABEL_IDS}"
    ;;

  ## ── ARCHIVE ───────────────────────────────────────────

  archive)
    # Archive a message (remove INBOX label, mark read). Usage: gmail.sh archive <messageId>
    MSG_ID="$2"
    log_usage "archive id=$MSG_ID"
    gapi "https://gmail.googleapis.com/gmail/v1/users/me/messages/$MSG_ID/modify" \
      -X POST -H "Content-Type: application/json" \
      -d '{"removeLabelIds":["INBOX","UNREAD"]}'
    ;;

  archive-batch)
    # Archive multiple messages. Usage: gmail.sh archive-batch <id1> <id2> ...
    shift
    IDS=$(python3 -c "import json; print(json.dumps([$(printf '"%s",' "$@")]))") 
    log_usage "archive-batch ids=$IDS"
    local token
    token=$(get_token)
    curl -s -H "Authorization: Bearer $token" \
      -X POST -H "Content-Type: application/json" \
      "https://gmail.googleapis.com/gmail/v1/users/me/messages/batchModify" \
      -d "{\"ids\":$IDS,\"removeLabelIds\":[\"INBOX\",\"UNREAD\"]}"
    ;;

  ## ── HEARTBEAT SCAN ────────────────────────────────────

  scan)
    # Full unread scan: fetches unread IDs then reads each. Usage: gmail.sh scan [max]
    MAX="${2:-20}"
    log_usage "scan max=$MAX"
    TOKEN=$(get_token)
    
    # Get unread message IDs
    MSGS=$(curl -s -H "Authorization: Bearer $TOKEN" \
      "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=is:unread&maxResults=$MAX")
    
    IDS=$(echo "$MSGS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
msgs = data.get('messages', [])
for m in msgs:
    print(m['id'])
" 2>/dev/null)
    
    if [ -z "$IDS" ]; then
      echo '{"count": 0, "emails": []}'
      exit 0
    fi
    
    # Read each message
    RESULTS="[]"
    for ID in $IDS; do
      MSG=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "https://gmail.googleapis.com/gmail/v1/users/me/messages/$ID?format=full")
      
      PARSED=$(echo "$MSG" | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
headers = {h['name'].lower(): h['value'] for h in data.get('payload',{}).get('headers',[])}
def get_body(payload):
    if payload.get('body',{}).get('data'):
        return base64.urlsafe_b64decode(payload['body']['data']).decode('utf-8','replace')
    for part in payload.get('parts',[]):
        if part.get('mimeType','').startswith('text/plain') and part.get('body',{}).get('data'):
            return base64.urlsafe_b64decode(part['body']['data']).decode('utf-8','replace')
    for part in payload.get('parts',[]):
        body = get_body(part)
        if body: return body
    return ''
result = {
    'id': data.get('id'),
    'threadId': data.get('threadId'),
    'from': headers.get('from',''),
    'to': headers.get('to',''),
    'subject': headers.get('subject',''),
    'date': headers.get('date',''),
    'labels': data.get('labelIds',[]),
    'snippet': data.get('snippet',''),
    'body': get_body(data.get('payload',{}))[:2000]
}
print(json.dumps(result, ensure_ascii=False))
")
      RESULTS=$(echo "$RESULTS" | python3 -c "
import sys, json
arr = json.load(sys.stdin)
arr.append(json.loads('''$PARSED'''))
print(json.dumps(arr, ensure_ascii=False))
")
    done
    
    echo "$RESULTS" | python3 -c "
import sys, json
arr = json.load(sys.stdin)
print(json.dumps({'count': len(arr), 'emails': arr}, ensure_ascii=False, indent=2))
"
    ;;

  ## ── HELP ──────────────────────────────────────────────

  help|*)
    cat <<HELP
Gmail CLI for Joe
Usage: gmail.sh <command> [args]

Read:
  unread [max]                     List unread message IDs
  read <id> [format]               Read a message (full|minimal|metadata)
  search <query> [max]             Search messages
  scan [max]                       Full unread scan (read all unread)

Send:
  send <to> <subject> <body> [cc]  Send an email
  send-raw <json-file>             Send from JSON file

Labels:
  labels                           List all labels
  label-create <name>              Create a label
  label <id> <labelId...>          Apply labels to message
  unlabel <id> <labelId...>        Remove labels from message

Archive:
  archive <id>                     Archive message (remove from inbox)
  archive-batch <id1> <id2> ...    Archive multiple messages
HELP
    ;;
esac
