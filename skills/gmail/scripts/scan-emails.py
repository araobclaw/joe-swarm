#!/usr/bin/env python3
"""Scan unread Gmail messages. Returns JSON with parsed emails.
Usage: scan-emails.py [--max N]
"""
import argparse, base64, json, os, sys, urllib.request, urllib.parse

def load_env():
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'gmail-oauth.env')
    env = {}
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                k, v = line.split('=', 1)
                env[k] = v
    return env

def get_token(env):
    data = urllib.parse.urlencode({
        'client_id': env['GOOGLE_GMAIL_CLIENT_ID'],
        'client_secret': env['GOOGLE_GMAIL_CLIENT_SECRET'],
        'refresh_token': env['GOOGLE_GMAIL_REFRESH_TOKEN'],
        'grant_type': 'refresh_token'
    }).encode()
    req = urllib.request.Request('https://oauth2.googleapis.com/token', data=data)
    resp = json.loads(urllib.request.urlopen(req).read())
    return resp['access_token']

def gapi(token, url):
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    return json.loads(urllib.request.urlopen(req).read())

def get_body(payload):
    body_data = payload.get('body', {}).get('data')
    if body_data:
        return base64.urlsafe_b64decode(body_data).decode('utf-8', 'replace')
    for part in payload.get('parts', []):
        if part.get('mimeType', '').startswith('text/plain'):
            bd = part.get('body', {}).get('data')
            if bd:
                return base64.urlsafe_b64decode(bd).decode('utf-8', 'replace')
    for part in payload.get('parts', []):
        result = get_body(part)
        if result:
            return result
    return ''

def parse_message(data):
    headers = {h['name'].lower(): h['value'] for h in data.get('payload', {}).get('headers', [])}
    body = get_body(data.get('payload', {}))
    return {
        'id': data.get('id'),
        'threadId': data.get('threadId'),
        'from': headers.get('from', ''),
        'to': headers.get('to', ''),
        'subject': headers.get('subject', ''),
        'date': headers.get('date', ''),
        'labels': data.get('labelIds', []),
        'snippet': data.get('snippet', ''),
        'body': body[:3000]  # truncate very long bodies
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--max', type=int, default=20, help='Max messages to fetch')
    parser.add_argument('--query', default='is:unread', help='Gmail search query')
    args = parser.parse_args()

    env = load_env()
    token = get_token(env)

    # Get message IDs
    url = f'https://gmail.googleapis.com/gmail/v1/users/me/messages?q={urllib.parse.quote(args.query)}&maxResults={args.max}'
    listing = gapi(token, url)
    msg_ids = [m['id'] for m in listing.get('messages', [])]

    if not msg_ids:
        print(json.dumps({'count': 0, 'emails': []}))
        return

    # Fetch each message
    emails = []
    for mid in msg_ids:
        data = gapi(token, f'https://gmail.googleapis.com/gmail/v1/users/me/messages/{mid}?format=full')
        emails.append(parse_message(data))

    print(json.dumps({'count': len(emails), 'emails': emails}, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
