#!/bin/bash
# Google Calendar CLI for OpenClaw
# Usage: calendar.sh <command> [args]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OAUTH_ENV="$WORKSPACE/gmail-oauth.env"
LOG_FILE="$SCRIPT_DIR/../calendar-usage.log"
CALENDAR_ID="primary"

source "$OAUTH_ENV"

log_usage() {
  echo "$(date -Iseconds) | $1" >> "$LOG_FILE"
}

# Get fresh access token
get_token() {
  local resp
  resp=$(curl -s -X POST https://oauth2.googleapis.com/token \
    -d "client_id=$GOOGLE_GMAIL_CLIENT_ID" \
    -d "client_secret=$GOOGLE_GMAIL_CLIENT_SECRET" \
    -d "refresh_token=$GOOGLE_GMAIL_REFRESH_TOKEN" \
    -d "grant_type=refresh_token")
  echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))"
}

gapi() {
  local token
  token=$(get_token)
  if [ -z "$token" ]; then
    echo '{"error":"Failed to refresh OAuth token"}'
    return 1
  fi
  curl -s -H "Authorization: Bearer $token" "$@"
}

case "${1:-help}" in

  ## ── LIST / TODAY / UPCOMING ─────────────────────────────

  today)
    # Events for today. Usage: calendar.sh today
    log_usage "today"
    NOW=$(date -u +%Y-%m-%dT00:00:00Z)
    END=$(date -u -d "tomorrow" +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -v+1d +%Y-%m-%dT00:00:00Z)
    gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events?timeMin=$NOW&timeMax=$END&singleEvents=true&orderBy=startTime" | \
      python3 -c "
import sys, json
data = json.load(sys.stdin)
events = data.get('items', [])
if not events:
    print(json.dumps({'count': 0, 'events': []}))
else:
    results = []
    for e in events:
        start = e.get('start',{}).get('dateTime', e.get('start',{}).get('date',''))
        end = e.get('end',{}).get('dateTime', e.get('end',{}).get('date',''))
        results.append({
            'id': e['id'],
            'summary': e.get('summary','(no title)'),
            'start': start,
            'end': end,
            'location': e.get('location',''),
            'status': e.get('status',''),
            'description': (e.get('description','') or '')[:500],
            'attendees': [a.get('email','') for a in e.get('attendees',[])],
            'hangoutLink': e.get('hangoutLink',''),
            'htmlLink': e.get('htmlLink',''),
        })
    print(json.dumps({'count': len(results), 'events': results}, ensure_ascii=False, indent=2))
"
    ;;

  upcoming)
    # Upcoming events. Usage: calendar.sh upcoming [days] [max]
    DAYS="${2:-7}"
    MAX="${3:-20}"
    log_usage "upcoming days=$DAYS max=$MAX"
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    END=$(date -u -d "+${DAYS} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+${DAYS}d +%Y-%m-%dT%H:%M:%SZ)
    gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events?timeMin=$NOW&timeMax=$END&maxResults=$MAX&singleEvents=true&orderBy=startTime" | \
      python3 -c "
import sys, json
data = json.load(sys.stdin)
events = data.get('items', [])
if not events:
    print(json.dumps({'count': 0, 'events': []}))
else:
    results = []
    for e in events:
        start = e.get('start',{}).get('dateTime', e.get('start',{}).get('date',''))
        end = e.get('end',{}).get('dateTime', e.get('end',{}).get('date',''))
        results.append({
            'id': e['id'],
            'summary': e.get('summary','(no title)'),
            'start': start,
            'end': end,
            'location': e.get('location',''),
            'status': e.get('status',''),
            'attendees': [a.get('email','') for a in e.get('attendees',[])],
            'hangoutLink': e.get('hangoutLink',''),
        })
    print(json.dumps({'count': len(results), 'events': results}, ensure_ascii=False, indent=2))
"
    ;;

  list)
    # List events in a date range. Usage: calendar.sh list <startDate> <endDate> [max]
    # Dates in YYYY-MM-DD format
    START_DATE="$2"
    END_DATE="$3"
    MAX="${4:-50}"
    log_usage "list start=$START_DATE end=$END_DATE max=$MAX"
    gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events?timeMin=${START_DATE}T00:00:00Z&timeMax=${END_DATE}T23:59:59Z&maxResults=$MAX&singleEvents=true&orderBy=startTime" | \
      python3 -c "
import sys, json
data = json.load(sys.stdin)
events = data.get('items', [])
results = []
for e in events:
    start = e.get('start',{}).get('dateTime', e.get('start',{}).get('date',''))
    end = e.get('end',{}).get('dateTime', e.get('end',{}).get('date',''))
    results.append({
        'id': e['id'],
        'summary': e.get('summary','(no title)'),
        'start': start,
        'end': end,
        'location': e.get('location',''),
        'status': e.get('status',''),
    })
print(json.dumps({'count': len(results), 'events': results}, ensure_ascii=False, indent=2))
"
    ;;

  ## ── GET / SEARCH ───────────────────────────────────

  get)
    # Get event details by ID. Usage: calendar.sh get <eventId>
    EVENT_ID="$2"
    log_usage "get id=$EVENT_ID"
    gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events/$EVENT_ID" | \
      python3 -c "
import sys, json
e = json.load(sys.stdin)
start = e.get('start',{}).get('dateTime', e.get('start',{}).get('date',''))
end = e.get('end',{}).get('dateTime', e.get('end',{}).get('date',''))
result = {
    'id': e['id'],
    'summary': e.get('summary','(no title)'),
    'start': start,
    'end': end,
    'location': e.get('location',''),
    'description': e.get('description',''),
    'status': e.get('status',''),
    'creator': e.get('creator',{}),
    'organizer': e.get('organizer',{}),
    'attendees': [{'email': a.get('email',''), 'responseStatus': a.get('responseStatus','')} for a in e.get('attendees',[])],
    'hangoutLink': e.get('hangoutLink',''),
    'htmlLink': e.get('htmlLink',''),
    'recurrence': e.get('recurrence',[]),
    'reminders': e.get('reminders',{}),
    'created': e.get('created',''),
    'updated': e.get('updated',''),
}
print(json.dumps(result, ensure_ascii=False, indent=2))
"
    ;;

  search)
    # Search events by text. Usage: calendar.sh search <query> [max]
    QUERY="$2"
    MAX="${3:-10}"
    log_usage "search query='$QUERY' max=$MAX"
    ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")
    gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events?q=$ENCODED&maxResults=$MAX&singleEvents=true&orderBy=startTime&timeMin=$(date -u -d '-90 days' +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -v-90d +%Y-%m-%dT00:00:00Z)" | \
      python3 -c "
import sys, json
data = json.load(sys.stdin)
events = data.get('items', [])
results = []
for e in events:
    start = e.get('start',{}).get('dateTime', e.get('start',{}).get('date',''))
    results.append({
        'id': e['id'],
        'summary': e.get('summary','(no title)'),
        'start': start,
        'location': e.get('location',''),
    })
print(json.dumps({'count': len(results), 'events': results}, ensure_ascii=False, indent=2))
"
    ;;

  ## ── CREATE ───────────────────────────────────────

  create)
    # Create event from JSON file. Usage: calendar.sh create <json-file>
    # JSON: {"summary","start","end","description"?,"location"?,"attendees"?[emails],"reminders"?{minutes},"allDay"?bool}
    JSON_FILE="$2"
    log_usage "create file=$JSON_FILE"
    python3 -c "
import json, sys

with open('$JSON_FILE') as f:
    d = json.load(f)

event = {'summary': d['summary']}

if d.get('allDay'):
    event['start'] = {'date': d['start']}
    end = d.get('end', d['start'])
    event['end'] = {'date': end}
else:
    tz = d.get('timezone', 'America/Sao_Paulo')
    event['start'] = {'dateTime': d['start'], 'timeZone': tz}
    event['end'] = {'dateTime': d['end'], 'timeZone': tz}

if d.get('description'):
    event['description'] = d['description']
if d.get('location'):
    event['location'] = d['location']
if d.get('attendees'):
    event['attendees'] = [{'email': e} for e in d['attendees']]
if d.get('reminders'):
    event['reminders'] = {
        'useDefault': False,
        'overrides': [{'method': 'popup', 'minutes': d['reminders'].get('minutes', 30)}]
    }
if d.get('recurrence'):
    event['recurrence'] = d['recurrence']
if d.get('colorId'):
    event['colorId'] = d['colorId']

print(json.dumps(event))
" | gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events?sendUpdates=all" \
      -X POST -H "Content-Type: application/json" -d @- | \
      python3 -c "
import sys, json
e = json.load(sys.stdin)
start = e.get('start',{}).get('dateTime', e.get('start',{}).get('date',''))
print(json.dumps({
    'id': e.get('id',''),
    'summary': e.get('summary',''),
    'start': start,
    'htmlLink': e.get('htmlLink',''),
    'status': 'created'
}, indent=2))
"
    ;;

  quick)
    # Quick-add event from natural text. Usage: calendar.sh quick "Lunch with Sarah tomorrow at noon"
    TEXT="$2"
    log_usage "quick text='$TEXT'"
    ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TEXT'))")
    gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events/quickAdd?text=$ENCODED" \
      -X POST | \
      python3 -c "
import sys, json
e = json.load(sys.stdin)
start = e.get('start',{}).get('dateTime', e.get('start',{}).get('date',''))
print(json.dumps({
    'id': e.get('id',''),
    'summary': e.get('summary',''),
    'start': start,
    'htmlLink': e.get('htmlLink',''),
    'status': 'created'
}, indent=2))
"
    ;;

  ## ── UPDATE ───────────────────────────────────────

  update)
    # Update event from JSON file. Usage: calendar.sh update <eventId> <json-file>
    # JSON can contain any subset of: {"summary","start","end","description","location","attendees"}
    EVENT_ID="$2"
    JSON_FILE="$3"
    log_usage "update id=$EVENT_ID file=$JSON_FILE"
    python3 -c "
import json
with open('$JSON_FILE') as f:
    d = json.load(f)
patch = {}
if 'summary' in d: patch['summary'] = d['summary']
if 'description' in d: patch['description'] = d['description']
if 'location' in d: patch['location'] = d['location']
tz = d.get('timezone', 'America/Sao_Paulo')
if 'start' in d:
    if len(d['start']) == 10:  # date only
        patch['start'] = {'date': d['start']}
    else:
        patch['start'] = {'dateTime': d['start'], 'timeZone': tz}
if 'end' in d:
    if len(d['end']) == 10:
        patch['end'] = {'date': d['end']}
    else:
        patch['end'] = {'dateTime': d['end'], 'timeZone': tz}
if 'attendees' in d:
    patch['attendees'] = [{'email': e} for e in d['attendees']]
print(json.dumps(patch))
" | gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events/$EVENT_ID?sendUpdates=all" \
      -X PATCH -H "Content-Type: application/json" -d @- | \
      python3 -c "
import sys, json
e = json.load(sys.stdin)
print(json.dumps({'id': e.get('id',''), 'summary': e.get('summary',''), 'status': 'updated'}, indent=2))
"
    ;;

  ## ── DELETE ───────────────────────────────────────

  delete)
    # Delete an event. Usage: calendar.sh delete <eventId>
    EVENT_ID="$2"
    log_usage "delete id=$EVENT_ID"
    gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events/$EVENT_ID?sendUpdates=all" \
      -X DELETE
    echo '{"status":"deleted","id":"'"$EVENT_ID"'"}'
    ;;

  ## ── RESPOND ─────────────────────────────────────

  respond)
    # Respond to an event invite. Usage: calendar.sh respond <eventId> <accepted|declined|tentative>
    EVENT_ID="$2"
    RESPONSE="$3"
    log_usage "respond id=$EVENT_ID response=$RESPONSE"
    # Get current event, patch our attendee status
    gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events/$EVENT_ID" | \
      python3 -c "
import sys, json
e = json.load(sys.stdin)
attendees = e.get('attendees', [])
for a in attendees:
    if a.get('self'):
        a['responseStatus'] = '$RESPONSE'
if not attendees:
    attendees = [{'email': 'joearaobassistant@gmail.com', 'responseStatus': '$RESPONSE'}]
e['attendees'] = attendees
print(json.dumps({'attendees': e['attendees']}))
" | gapi "https://www.googleapis.com/calendar/v3/calendars/$CALENDAR_ID/events/$EVENT_ID?sendUpdates=all" \
      -X PATCH -H "Content-Type: application/json" -d @-  | \
      python3 -c "
import sys, json
e = json.load(sys.stdin)
print(json.dumps({'id': e.get('id',''), 'summary': e.get('summary',''), 'response': '$RESPONSE'}, indent=2))
"
    ;;

  ## ── CALENDARS ───────────────────────────────────

  calendars)
    # List all calendars. Usage: calendar.sh calendars
    log_usage "calendars"
    gapi "https://www.googleapis.com/calendar/v3/users/me/calendarList" | \
      python3 -c "
import sys, json
data = json.load(sys.stdin)
for c in data.get('items',[]):
    print(json.dumps({'id': c['id'], 'summary': c.get('summary',''), 'primary': c.get('primary', False), 'accessRole': c.get('accessRole','')}))
"
    ;;

  ## ── FREE/BUSY ───────────────────────────────────

  freebusy)
    # Check free/busy for a date range. Usage: calendar.sh freebusy <startDate> <endDate>
    START_DATE="$2"
    END_DATE="$3"
    log_usage "freebusy start=$START_DATE end=$END_DATE"
    gapi "https://www.googleapis.com/calendar/v3/freeBusy" \
      -X POST -H "Content-Type: application/json" \
      -d '{"timeMin":"'"${START_DATE}T00:00:00Z"'","timeMax":"'"${END_DATE}T23:59:59Z"'","items":[{"id":"primary"}]}' | \
      python3 -c "
import sys, json
data = json.load(sys.stdin)
cals = data.get('calendars',{})
for cal_id, info in cals.items():
    busy = info.get('busy',[])
    print(json.dumps({'calendar': cal_id, 'busy_slots': len(busy), 'slots': busy}, indent=2))
"
    ;;

  ## ── HELP ────────────────────────────────────────

  help|*)
    cat <<HELP
Google Calendar CLI for Joe
Usage: calendar.sh <command> [args]

View:
  today                                  Today's events
  upcoming [days] [max]                  Next N days (default: 7)
  list <startDate> <endDate> [max]       Events in date range (YYYY-MM-DD)
  get <eventId>                          Full event details
  search <query> [max]                   Search events by text
  calendars                              List all calendars
  freebusy <startDate> <endDate>         Check free/busy slots

Create:
  create <json-file>                     Create event from JSON
  quick "text"                           Quick-add from natural language

Modify:
  update <eventId> <json-file>           Patch event fields
  delete <eventId>                       Delete event
  respond <eventId> <accepted|declined|tentative>  RSVP to invite

JSON format for create:
  {"summary": "Meeting", "start": "2026-03-05T14:00:00", "end": "2026-03-05T15:00:00",
   "description": "...", "location": "...", "attendees": ["a@b.com"],
   "timezone": "America/Sao_Paulo", "allDay": false,
   "reminders": {"minutes": 15}, "recurrence": ["RRULE:FREQ=WEEKLY;COUNT=4"]}
HELP
    ;;
esac
