#!/bin/bash
# Capture a thought to Open Brain from Joe's main session.
# Usage: open-brain-capture.sh "thought text"
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: open-brain-capture.sh <thought>" >&2
  exit 1
fi

JSON=$(python3 -c "
import json, sys
print(json.dumps({'content': sys.argv[1], 'source': sys.argv[2]}))
" "$1" "${2:-joe}")

curl -s -X POST http://localhost:8100/webhook/capture \
  -H "Content-Type: application/json" \
  -d "$JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
t = d.get('type','')
topics = ', '.join(d.get('topics') or [])
people = ', '.join(d.get('people') or [])
print(f'Stored as {t} — {topics}')
if people: print(f'People: {people}')
"
