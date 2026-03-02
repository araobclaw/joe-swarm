# Google API Access

## Account
- **Email:** joearaobassistant@gmail.com
- **OAuth scopes:** Gmail (full), Calendar, Drive, Sheets, Contacts (read)
- **Credentials:** `gmail-oauth.env` (Client ID, Secret, Refresh Token)

## Helper Script
`./google-api.sh <URL> [curl args...]` — auto-refreshes access token and makes authenticated requests.

### Gmail
```bash
# List messages
./google-api.sh "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=5"

# Read a message
./google-api.sh "https://gmail.googleapis.com/gmail/v1/users/me/messages/MESSAGE_ID"

# Search
./google-api.sh "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=from:someone@example.com+newer_than:1d&maxResults=10"

# Send email (base64url-encoded RFC 2822)
./google-api.sh "https://gmail.googleapis.com/gmail/v1/users/me/messages/send" \
  -X POST -H "Content-Type: application/json" \
  -d '{"raw":"BASE64URL_ENCODED_MESSAGE"}'
```

### Calendar
```bash
# List upcoming events
./google-api.sh "https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=10&timeMin=$(date -u +%Y-%m-%dT%H:%M:%SZ)&orderBy=startTime&singleEvents=true"

# Create event
./google-api.sh "https://www.googleapis.com/calendar/v3/calendars/primary/events" \
  -X POST -H "Content-Type: application/json" \
  -d '{"summary":"Meeting","start":{"dateTime":"2026-03-01T10:00:00-03:00"},"end":{"dateTime":"2026-03-01T11:00:00-03:00"}}'
```

### Drive
```bash
# List files
./google-api.sh "https://www.googleapis.com/drive/v3/files?pageSize=10"

# Search files
./google-api.sh "https://www.googleapis.com/drive/v3/files?q=name+contains+'report'&pageSize=10"
```

### Sheets
```bash
# Read sheet
./google-api.sh "https://sheets.googleapis.com/v4/spreadsheets/SHEET_ID/values/Sheet1!A1:D10"

# Append row
./google-api.sh "https://sheets.googleapis.com/v4/spreadsheets/SHEET_ID/values/Sheet1!A:D:append?valueInputOption=USER_ENTERED" \
  -X POST -H "Content-Type: application/json" \
  -d '{"values":[["col1","col2","col3"]]}'
```

### Contacts
```bash
# List contacts
./google-api.sh "https://people.googleapis.com/v1/people/me/connections?personFields=names,emailAddresses,phoneNumbers&pageSize=50"
```

## Adding Arao's Personal Account (Future)
Same OAuth client works. Just:
1. Add arao's email as test user in Google Cloud Console
2. Run the OAuth flow again with `prompt=consent` for the new account
3. Save the new refresh token with a different env var name
4. Duplicate google-api.sh as google-api-arao.sh pointing to the new token
