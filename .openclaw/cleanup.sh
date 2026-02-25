#!/bin/bash
# Daily: Clean old worktrees/tasks
cd \"\$(dirname \\\"$0\\\")/../\"

# Tasks >7d failed/done
jq 'map(select(.status != \"running\" and (.completedAt // now - .startedAt > 604800))) | length' .clawdbot/active-tasks.json | xargs -I {} jq \"map(select(.status == \\\"running\\\"))\" .clawdbot/active-tasks.json > tmp && mv tmp .clawdbot/active-tasks.json

# Old worktrees
find ../worktrees -maxdepth 1 -type d -name 'feat-*' -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo \"Cleanup: old tasks/worktrees purged.\"
