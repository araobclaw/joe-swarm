#!/bin/bash
# Efficient babysitter: tmux/gh checks only. No LLM polls.
set -e

cd \"\$(dirname \\\"$0\\\")/../\"

LOG=.openclaw/agent-check.log
echo \"\$(date): Checking agents...\" >> ${LOG}

TASKS=\$(cat .clawdbot/active-tasks.json | jq -c '.[] | select(.status == \"running\")')

if [ \"\$TASKS\" = \"[]\" ]; then
  echo \"No running tasks.\" >> ${LOG}
  exit 0
fi

echo \$TASKS | while read task; do
  ID=\$(echo \$task | jq -r .id)
  TMUX=\$(echo \$task | jq -r .tmuxSession)
  REPO=\$(echo \$task | jq -r .repo)
  BRANCH=\$(echo \$task | jq -r .branch)

  # Tmux alive?
  if ! tmux has-session -t \$TMUX 2>/dev/null; then
    ATTEMPTS=\$(jq -r \"select(.id==\\\"\$ID\\\") | .attempts // 0\" .clawdbot/active-tasks.json)
    if [ \$ATTEMPTS -lt 3 ]; then
      echo \"Respawning \$TMUX (attempt \$((\$ATTEMPTS+1)))\" >> ${LOG}
      # Update attempts + respawn
      jq \"select(.id==\\\"\$ID\\\") | .attempts += 1\" .clawdbot/active-tasks.json > tmp && mv tmp .clawdbot/active-tasks.json
      .openclaw/spawn-agent.sh \$ID \$REPO \"Retry: \$(echo \$task | jq -r .description)\"  # same model
    else
      echo \"Failed \$ID after 3 attempts\" >> ${LOG}
      jq \"select(.id==\\\"\$ID\\\") | .status = \\\"failed\\\"\" .clawdbot/active-tasks.json > tmp && mv tmp .clawdbot/active-tasks.json
    fi
    continue
  fi

  # PR created?
  PR=\$(gh pr list --repo \$REPO --head \$BRANCH --json number,status --limit 1 | jq -r '.[0].number // empty')
  if [ -n \"\$PR\" ] && [ \"\$(gh pr view \$PR --repo \$REPO --json status | jq -r .status)\" != \"OPEN\" ]; then PR=; fi

  if [ -n \"\$PR\" ]; then
    # CI?
    CI_STATUS=\$(gh run list --repo \$REPO --branch \$BRANCH --json status --limit 1 | jq -r '.[0].status // \"none\"')
    [ \"\$CI_STATUS\" = \"success\" ] || continue  # Wait for pass

    # Reviews: Check comments or spawn if new PR (spawn once)
    # Simplified: Assume agent did; check if reviews mentioned or status updated

    # All good? Notify + done
    jq \"select(.id==\\\"\$ID\\\") | .status = \\\"done\\\" | .pr = ${PR}\" .clawdbot/active-tasks.json > tmp && mv tmp .clawdbot/active-tasks.json
    echo \"🚀 PR #\${PR} ready in \${REPO}! CI passed. Merge? https://github.com/\${REPO}/pull/\${PR}\" >> ${LOG}
    # TODO: message to telegram/channel
  fi
done

echo \"Check complete. Log: tail -f .openclaw/agent-check.log\" >> ${LOG}
