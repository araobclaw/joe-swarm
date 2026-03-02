---
name: gmail
description: "Gmail operations for joearaobassistant@gmail.com. Strictly limited to: (1) Heartbeat email triage, (2) Arao explicitly asks to send/read email, (3) Contacting someone who has no Telegram."
metadata:
  version: "1.0.0"
---

# Gmail Skill

Manages Joe's Gmail account (`joearaobassistant@gmail.com`) via OAuth2 API.

## ⛔ When NOT to Use This Skill

- **Do NOT send emails unless Arao explicitly asks or you're replying to an actionable inbound email**
- **Do NOT use email to contact someone reachable via Telegram** — Telegram is always preferred
- **Do NOT scan emails outside of heartbeat** — the heartbeat handles inbox monitoring
- **Do NOT send test emails, promotional emails, or unsolicited outreach**
- **Do NOT create labels, modify filters, or change mailbox settings unless Arao asks**
- **Do NOT read or search old emails unless Arao asks a specific question about email history**

## ✅ When to Use This Skill

1. **Heartbeat email triage** — scan unread, classify, label, archive (see HEARTBEAT.md)
2. **Arao says "email X about Y"** — explicit send request
3. **Arao says "check my email" or "any new emails?"** — explicit read request
4. **Replying to an actionable inbound email** during heartbeat triage (only if confident and appropriate)
5. **Contacting someone with no Telegram** — when Joe needs to reach an external person and email is the only channel available

## Scripts

All scripts are in `./skills/gmail/scripts/`.

### Send Email

Prefer the Python script for safe encoding:
```bash
python3 ./skills/gmail/scripts/send-email.py \
  --to "recipient@example.com" \
  --subject "Subject line" \
  --body "Email body text"
```

With CC/BCC/reply:
```bash
python3 ./skills/gmail/scripts/send-email.py \
  --to "main@example.com" \
  --cc "cc@example.com" \
  --subject "Re: Thread" \
  --body "Reply text" \
  --reply-to "<original-message-id@mail.gmail.com>"
```

For complex emails, write a JSON file:
```json
{"to": "a@b.com", "subject": "Hi", "body": "Content", "cc": "c@d.com"}
```
Then: `python3 ./skills/gmail/scripts/send-email.py --json /tmp/email.json`

### Read & Search
```bash
python3 ./skills/gmail/scripts/scan-emails.py --max 20   # Full scan (heartbeat)
./skills/gmail/scripts/gmail.sh read <msgId>              # Read one message
./skills/gmail/scripts/gmail.sh search "query" [max]      # Search (only when Arao asks)
```

### Labels
```bash
./skills/gmail/scripts/gmail.sh label <msgId> <labelId>   # Apply label
./skills/gmail/scripts/gmail.sh unlabel <msgId> <labelId> # Remove label
```
Label IDs: `Label_1` = Joe/Actioned, `Label_2` = Joe/Notified, `Label_3` = Joe/Archived

### Archive
```bash
./skills/gmail/scripts/gmail.sh archive <msgId>           # Archive one
```

## Sender Identity

From: `Joe <joearaobassistant@gmail.com>`

- On behalf of Arao: "I'm reaching out on behalf of Arao regarding..."
- As Joe directly: sign as Joe
- Always professional, brief, clear. Never spam.
