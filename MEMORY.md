# MEMORY

## Open Brain

- **Capture group Telegram chat ID:** `-5005485723` (group name: "Brain Inbox")
- **Storage:** PostgreSQL 18 + pgvector at `localhost:5432`, database `open_brain`
- **API:** `http://localhost:8100` (systemd service: `open-brain`)
- **MCP endpoint:** `POST /mcp` with header `x-brain-key`
- **Capture endpoint:** `POST /webhook/capture`
- **MCP tools:** `search_thoughts`, `list_thoughts`, `thought_stats`
- **Brain agent:** Forwards every Telegram message via `/home/exedev/open-brain/brain-capture.sh`
- **Arao's Telegram user ID:** `7833538017`
- **Languages:** pt-BR and English (respond in whichever Arao used)
