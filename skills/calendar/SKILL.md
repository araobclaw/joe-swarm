---
name: calendar
description: "Google Calendar operations for joearaobassistant@gmail.com. Use ONLY when Arao explicitly asks about calendar/events/schedule, during heartbeat to check upcoming events, or when creating events Arao specifically requests."
metadata:
  version: "1.0.0"
---

# Calendar Skill

Manages Joe's Google Calendar (`joearaobassistant@gmail.com`) via OAuth2 API.

## ⛔ When NOT to Use This Skill

- **Do NOT create events unless Arao explicitly asks OR an Open Brain notification includes dates** — see "Open Brain auto-calendar" below
- **Do NOT delete or modify events unless Arao asks** — calendar is sensitive
- **Do NOT check calendar outside of heartbeat or explicit requests**
- **Do NOT share calendar details with anyone other than Arao**
- **Do NOT accept/decline invites without Arao's approval**
- **Do NOT use calendar to set reminders** — use cron jobs for that

## ✅ When to Use This Skill

1. **Arao asks "what's on my calendar?"** — explicit schedule check
2. **Arao asks to create an event** — "schedule a meeting with X", "add Y to calendar"
3. **Arao asks about availability** — "am I free Thursday?", "when's my next meeting?"
4. **Heartbeat calendar check** — upcoming events in next 24-48h (2-4x/day)
5. **Arao asks to modify/cancel an event** — explicit request only
6. **Open Brain auto-calendar** — when you receive an Open Brain action notification with dates, create calendar events for those dates automatically (see below)

### Open Brain Auto-Calendar

When you receive a `🧠 Open Brain — action detected` notification that includes dates:
1. Create calendar event(s) for each relevant date using `quick` or `create`
2. Use the action item as the event summary
3. Include the full thought content in the event description
4. Confirm to Arao what you created: "📅 Adicionei ao calendário: [summary] em [date]"

## Scripts

All scripts are in `./skills/calendar/scripts/`.

### View Events

```bash
# Today's events
./skills/calendar/scripts/calendar.sh today

# Next 7 days (default)
./skills/calendar/scripts/calendar.sh upcoming

# Next 3 days, max 10 results
./skills/calendar/scripts/calendar.sh upcoming 3 10

# Specific date range
./skills/calendar/scripts/calendar.sh list 2026-03-01 2026-03-15

# Full event details
./skills/calendar/scripts/calendar.sh get <eventId>

# Search events
./skills/calendar/scripts/calendar.sh search "dentist"

# Check free/busy
./skills/calendar/scripts/calendar.sh freebusy 2026-03-05 2026-03-05
```

### Create Events

```bash
# Quick-add from natural language (Google parses the text)
./skills/calendar/scripts/calendar.sh quick "Lunch with Sarah tomorrow at noon"

# Full control via JSON file
cat > /tmp/event.json << 'EOF'
{
  "summary": "Team Meeting",
  "start": "2026-03-05T14:00:00",
  "end": "2026-03-05T15:00:00",
  "description": "Weekly sync",
  "location": "Office",
  "attendees": ["sarah@example.com"],
  "timezone": "America/Sao_Paulo",
  "reminders": {"minutes": 15}
}
EOF
./skills/calendar/scripts/calendar.sh create /tmp/event.json
```

JSON fields:
- `summary` (required) — event title
- `start`, `end` (required) — ISO datetime or YYYY-MM-DD for all-day
- `allDay` — set `true` for all-day events (start/end become dates)
- `description` — event notes
- `location` — where
- `attendees` — array of email addresses
- `timezone` — default: America/Sao_Paulo
- `reminders` — `{"minutes": N}` for popup reminder
- `recurrence` — array of RRULE strings, e.g. `["RRULE:FREQ=WEEKLY;COUNT=4"]`
- `colorId` — Google Calendar color ID (1-11)

### Modify Events

```bash
# Update fields (only include what changes)
cat > /tmp/update.json << 'EOF'
{"summary": "New Title", "start": "2026-03-05T15:00:00", "end": "2026-03-05T16:00:00"}
EOF
./skills/calendar/scripts/calendar.sh update <eventId> /tmp/update.json

# Delete
./skills/calendar/scripts/calendar.sh delete <eventId>

# RSVP to invite
./skills/calendar/scripts/calendar.sh respond <eventId> accepted
./skills/calendar/scripts/calendar.sh respond <eventId> declined
./skills/calendar/scripts/calendar.sh respond <eventId> tentative
```

### Other

```bash
# List all calendars
./skills/calendar/scripts/calendar.sh calendars
```

## Timezone

Default timezone for event creation: `America/Sao_Paulo` (BRT/BRST).
All-day events use date-only format (no timezone).
Query results return UTC or the event's timezone — convert for display.

## Heartbeat Usage

During heartbeat calendar check:
1. Run `./skills/calendar/scripts/calendar.sh upcoming 2 10`
2. If events in next 2 hours → notify Arao with summary
3. If nothing upcoming → skip (don't report empty calendar)
