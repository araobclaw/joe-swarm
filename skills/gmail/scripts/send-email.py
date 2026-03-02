#!/usr/bin/env python3
"""Send email via Gmail API. Handles all encoding safely.
Usage: send-email.py --to <addr> --subject <subj> --body <body> [--cc <addr>] [--bcc <addr>] [--reply-to <msgId>] [--html]
Or:    send-email.py --json <file.json>
"""
import argparse, base64, json, os, sys
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import urllib.request, urllib.parse

def get_token():
    env_path = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'gmail-oauth.env')
    env = {}
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                k, v = line.split('=', 1)
                env[k] = v
    data = urllib.parse.urlencode({
        'client_id': env['GOOGLE_GMAIL_CLIENT_ID'],
        'client_secret': env['GOOGLE_GMAIL_CLIENT_SECRET'],
        'refresh_token': env['GOOGLE_GMAIL_REFRESH_TOKEN'],
        'grant_type': 'refresh_token'
    }).encode()
    req = urllib.request.Request('https://oauth2.googleapis.com/token', data=data)
    resp = json.loads(urllib.request.urlopen(req).read())
    return resp['access_token']

def send(to, subject, body, cc=None, bcc=None, reply_to=None, html=False):
    subtype = 'html' if html else 'plain'
    msg = MIMEText(body, subtype, 'utf-8')
    msg['To'] = to
    msg['From'] = 'Joe <joearaobassistant@gmail.com>'
    msg['Subject'] = subject
    if cc: msg['Cc'] = cc
    if bcc: msg['Bcc'] = bcc
    if reply_to:
        msg['In-Reply-To'] = reply_to
        msg['References'] = reply_to
    
    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode()
    token = get_token()
    
    payload = json.dumps({'raw': raw}).encode()
    req = urllib.request.Request(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
        data=payload,
        headers={
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
    )
    resp = json.loads(urllib.request.urlopen(req).read())
    return resp

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--to', help='Recipient')
    parser.add_argument('--subject', help='Subject')
    parser.add_argument('--body', help='Body text')
    parser.add_argument('--cc', help='CC recipients')
    parser.add_argument('--bcc', help='BCC recipients')
    parser.add_argument('--reply-to', help='Message ID to reply to')
    parser.add_argument('--html', action='store_true', help='Body is HTML')
    parser.add_argument('--json', dest='json_file', help='JSON file with email data')
    args = parser.parse_args()
    
    if args.json_file:
        with open(args.json_file) as f:
            data = json.load(f)
        result = send(**data)
    elif args.to and args.subject and args.body:
        result = send(
            to=args.to, subject=args.subject, body=args.body,
            cc=args.cc, bcc=args.bcc, reply_to=args.reply_to, html=args.html
        )
    else:
        parser.print_help()
        sys.exit(1)
    
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
