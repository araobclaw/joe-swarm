# TOOLS.md — Quick Reference

## 📅 Calendar (Google)

Script: `./skills/calendar/scripts/calendar.sh`

```bash
# View
./skills/calendar/scripts/calendar.sh today
./skills/calendar/scripts/calendar.sh upcoming          # next 7 days
./skills/calendar/scripts/calendar.sh upcoming 3 10     # 3 days, max 10
./skills/calendar/scripts/calendar.sh search "dentist"
./skills/calendar/scripts/calendar.sh freebusy 2026-03-05 2026-03-05

# Create
./skills/calendar/scripts/calendar.sh quick "Lunch with Sarah tomorrow at noon"

# Manage
./skills/calendar/scripts/calendar.sh update <eventId> /tmp/update.json
./skills/calendar/scripts/calendar.sh delete <eventId>
```

Timezone: America/Sao_Paulo. Full docs: `./skills/calendar/SKILL.md`

## 📧 Gmail

Script: `./skills/gmail/scripts/gmail.sh`

```bash
./skills/gmail/scripts/gmail.sh unread               # list unread
./skills/gmail/scripts/gmail.sh read <messageId>     # read one
./skills/gmail/scripts/gmail.sh search "from:someone subject:invoice"
./skills/gmail/scripts/scan-emails.py                # full heartbeat scan
./skills/gmail/scripts/send-email.py                 # send (interactive)
```

Full docs: `./skills/gmail/SKILL.md`

## 🧠 Open Brain

```bash
# Capture a memory
./skills/open-brain-capture.sh "Decision: use Stripe instead of PayPal"

# Search (via MCP API)
curl -s -X POST http://localhost:8100/mcp \
  -H "Content-Type: application/json" \
  -H "x-brain-key: 1e536a81182a29a8f8e2ca0393f824314fad0763ef9096c0aefc18d68397a1c2" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"search_thoughts","arguments":{"query":"YOUR QUERY"}}}'
```

MCP tools: `search_thoughts`, `list_thoughts`, `delete_thought`, `thought_stats`

---

## Shelley (Coding Agent) 🚨 USE FOR ANYTHING OUTSIDE WORKSPACE

Shelley is a powerful coding agent with **full server access** (not just workspace).

**🛑 CRITICAL:** You (Joe) can ONLY access `~/.openclaw/workspace/`. Shelley can access the entire server.

**If you hit sandbox/security limits → DON'T ask for approval. USE SHELLEY.**

The script is in your workspace: `./shelley-task`

```bash
# Start a task
shelley-task start "<task description>" [model] [cwd]

# Check status
shelley-task status <conversation_id>

# Wait for completion
shelley-task wait <conversation_id>

# Get response
shelley-task response <conversation_id>

# Send follow-up
shelley-task send <conversation_id> "<message>"

# List conversations
shelley-task list

# Show models
shelley-task models
```

**Models:**
- `claude-opus-4.6` - Best for complex tasks **(default)**
- `claude-sonnet-4.5` - Good balance of speed/capability
- `claude-haiku-4.5` - Fast, simple tasks

**When to use Shelley:**
- Tasks outside workspace (Joe can't access)
- System admin (packages, services)
- Multi-file refactoring across server
- Complex debugging
- Architecture decisions
- Browser/web research

**Example workflow:**
```bash
CONV=$(shelley-task start "Refactor auth to use JWT" | jq -r .conversation_id)
shelley-task wait $CONV
shelley-task response $CONV
```

Full docs: `~/.openclaw/workspace/skills/shelley/SKILL.md`

---

Add whatever helps you do your job. This is your cheat sheet.
