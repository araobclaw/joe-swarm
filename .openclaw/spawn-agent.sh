#!/bin/bash
# Usage: .openclaw/spawn-agent.sh <id> <owner/repo> "<task>" [model=codex] [branch=auto]
set -e

ID=${1:?ID required}
REPO=${2:?owner/repo required}
TASK=${3:?Task required}
MODEL=${4:-codex}
BRANCH=${5:-feat-${ID}}
TMUX_SESS=${MODEL}-${ID}
WORKDIR=../worktrees/${ID}
REPO_URL=https://github.com/${REPO}.git

echo "Spawning ${MODEL} agent for ${TASK} in ${WORKDIR}..."

mkdir -p ${WORKDIR}
cd ${WORKDIR}
git init 2>/dev/null || true
git remote add origin ${REPO_URL} 2>/dev/null || true
git fetch origin
git checkout ${BRANCH} || (git checkout main && git pull origin main && git checkout -b ${BRANCH} origin/main)

# Install deps if node
if [ -f package.json ]; then
  command -v pnpm >/dev/null && pnpm install || (npm ci || yarn install)
fi

# Track task
STARTED=$(date +%s)
jq --arg id \"${ID}\" --arg tmux \"${TMUX_SESS}\" --arg agent \"${MODEL}\" --arg desc \"${TASK}\" --arg repo \"${REPO}\" --arg worktree \"${WORKDIR}\" --arg branch \"${BRANCH}\" \
  '. += [{id: $id, tmuxSession: $tmux, agent: $agent, description: $desc, repo: $repo, worktree: $worktree, branch: $branch, startedAt: $STARTED, status: \"running\", notifyOnComplete: true, attempts: 0}]' \
  ../.clawdbot/active-tasks.json > tmp.json && mv tmp.json ../.clawdbot/active-tasks.json

# Start tmux (pty for agent)
tmux new-session -d -s ${TMUX_SESS} -c ${WORKDIR}

# Initial kickoff: Agent prompt (steer later)
tmux send-keys -t ${TMUX_SESS} \"echo 'Coding agent booted in \$(pwd). Model: ${MODEL}. Task: ${TASK}. Explore codebase, plan, code, test, commit/PR when done. Use high thinking.'\" Enter
tmux send-keys -t ${TMUX_SESS} \"pwd; ls -la; git status\" Enter

echo \"Agent ${TMUX_SESS} ready in ${WORKDIR}. PR coming. /status to check.\"
