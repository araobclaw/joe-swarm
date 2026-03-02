---
name: shelley
description: "Delegate tasks to Shelley ONLY when they require access outside the OpenClaw workspace (~/.openclaw/workspace/), system administration, package installation, or browser automation. Do NOT use for tasks achievable with workspace read/write tools or other skills."
metadata:
  version: "1.0.0"
---

# Shelley Skill

Shelley is a coding agent with full server access. This skill delegates tasks to her.

## ⛔ When NOT to Use Shelley

- **Do NOT use for reading/writing files inside your workspace** — use `read`/`write` tools directly
- **Do NOT use for Gmail operations** — use the Gmail skill scripts
- **Do NOT use for Open Brain queries** — query via `curl http://localhost:8100/mcp` directly
- **Do NOT use for Google API calls** — use `./google-api.sh`
- **Do NOT use for simple questions** — answer them yourself
- **Do NOT delegate just because a task feels complex** — only delegate when you literally cannot access the required resources

## ✅ When to Use Shelley

- **Tasks requiring files outside `~/.openclaw/workspace/`** (e.g., `/home/exedev/` projects)
- **System administration** (installing packages, managing services, systemd)
- **Browser automation and web research**
- **Multi-file refactoring across the server**
- **Complex debugging that needs persistent context and full system access**

## Access Differences

| Agent | Access Scope |
|-------|-------------|
| **Shelley** | Full server access (`/home/exedev` and beyond) |
| **Joe (OpenClaw)** | Workspace only (`~/.openclaw/workspace/`) |

**When to use Shelley:**
- Tasks requiring access outside the OpenClaw workspace
- System administration tasks
- Installing packages, managing services
- Working with files in `/home/exedev/` projects
- Browser automation and web research

## Quick Reference

| Action | Command |
|--------|--------|
| Start new task | `shelley_start "<task description>"` |
| Check status | `shelley_status <conversation_id>` |
| Get response | `shelley_response <conversation_id>` |
| Send follow-up | `shelley_send <conversation_id> "<message>"` |
| List conversations | `shelley_list` |

## API Details

Shelley runs at `http://localhost:9999` and requires the header `X-Exedev-Userid: 1`.

### Start a New Conversation

```bash
curl -s -X POST -H "Content-Type: application/json" -H "X-Exedev-Userid: 1" -H "X-Shelley-Request: 1" \
  http://localhost:9999/api/conversations/new \
  -d '{"message":"<your task>","model":"claude-opus-4.5","cwd":"/home/exedev"}'
```

Response: `{"conversation_id":"<id>","status":"accepted"}`

### Check If Conversation Is Complete

```bash
curl -s -H "X-Exedev-Userid: 1" http://localhost:9999/api/conversations | \
  python3 -c "import json,sys; convs=json.load(sys.stdin); [print(f'{c[\"conversation_id\"]}: working={c[\"working\"]}') for c in convs]"
```

Wait until `working=False` before reading the response.

### Get Conversation Response

```bash
curl -s -H "X-Exedev-Userid: 1" "http://localhost:9999/api/conversation/<conversation_id>" | \
  python3 -c "
import json,sys
data = json.load(sys.stdin)
for msg in data.get('messages', []):
    if msg['type'] == 'agent':
        llm = json.loads(msg.get('llm_data', '{}'))
        for content in llm.get('Content', []):
            if content.get('Text'):
                print(content['Text'])"
```

### Send Follow-up Message

```bash
curl -s -X POST -H "Content-Type: application/json" -H "X-Exedev-Userid: 1" -H "X-Shelley-Request: 1" \
  http://localhost:9999/api/conversation/<conversation_id>/chat \
  -d '{"message":"<follow-up message>"}'
```

### List All Conversations

```bash
curl -s -H "X-Exedev-Userid: 1" http://localhost:9999/api/conversations
```

## Available Models

- `claude-opus-4.6` - Most capable, best for complex tasks **(default)**
- `claude-opus-4.5` - Very capable, good balance
- `claude-sonnet-4.5` - Faster, good for medium tasks
- `claude-haiku-4.5` - Fastest, good for simple tasks
- `gpt-5.3-codex` - OpenAI's coding model

## When to Use Shelley

**Good candidates for Shelley:**
- Tasks outside `~/.openclaw/workspace/` (Joe can't access)
- System administration (installing packages, services)
- Multi-file refactoring across the server
- Complex debugging sessions
- Architecture reviews
- Code generation requiring deep context
- Tasks that need web browsing and research
- Long-running operations
- Working with projects in `/home/exedev/`

**Keep in Joe:**
- Quick questions
- Workspace file edits
- Status checks
- Routine operations within workspace

## Example Workflow

```bash
# 1. Start a complex task
CONV_ID=$(curl -s -X POST -H "Content-Type: application/json" -H "X-Exedev-Userid: 1" -H "X-Shelley-Request: 1" \
  http://localhost:9999/api/conversations/new \
  -d '{"message":"Refactor the authentication module to use JWT tokens. Current code is in /home/exedev/myapp/auth/","model":"claude-opus-4.5"}' | \
  python3 -c "import json,sys; print(json.load(sys.stdin)['conversation_id'])")

echo "Started conversation: $CONV_ID"

# 2. Poll until complete
while true; do
  WORKING=$(curl -s -H "X-Exedev-Userid: 1" http://localhost:9999/api/conversations | \
    python3 -c "import json,sys; convs=json.load(sys.stdin); print(next((c['working'] for c in convs if c['conversation_id']=='$CONV_ID'), False))")
  if [ "$WORKING" = "False" ]; then
    echo "Complete!"
    break
  fi
  echo "Still working..."
  sleep 5
done

# 3. Get the response
curl -s -H "X-Exedev-Userid: 1" "http://localhost:9999/api/conversation/$CONV_ID" | \
  python3 -c "
import json,sys
data = json.load(sys.stdin)
for msg in data.get('messages', []):
    if msg['type'] == 'agent':
        llm = json.loads(msg.get('llm_data', '{}'))
        for content in llm.get('Content', []):
            if content.get('Text'):
                print(content['Text'])"
```

## Helper Script

A helper script is available at `~/.openclaw/workspace/skills/shelley/scripts/shelley.sh`

## Notes

- Shelley has access to the same filesystem as Joe
- Shelley can use browser tools for web research
- Complex tasks may take several minutes
- Check `working` status before reading responses
- Shelley's responses may include tool calls and their results
