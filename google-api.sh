#!/bin/bash
# Google API helper - refreshes token and makes authenticated requests
# Usage: ./google-api.sh <URL> [curl args...]
# Example: ./google-api.sh "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=5"
# Example: ./google-api.sh "https://gmail.googleapis.com/gmail/v1/users/me/messages/send" -X POST -d '{"raw":"..."}'

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/gmail-oauth.env"

# Refresh access token
TOKEN_RESPONSE=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d "client_id=$GOOGLE_GMAIL_CLIENT_ID" \
  -d "client_secret=$GOOGLE_GMAIL_CLIENT_SECRET" \
  -d "refresh_token=$GOOGLE_GMAIL_REFRESH_TOKEN" \
  -d "grant_type=refresh_token")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: Failed to refresh token: $TOKEN_RESPONSE" >&2
  exit 1
fi

URL="$1"
shift

curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "$URL" "$@"
