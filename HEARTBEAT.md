# HEARTBEAT

## Email Triage

1. Run `python3 ./skills/gmail/scripts/scan-emails.py --max 20`
2. If count = 0, stop. Do NOT report "no emails" to Arao.
3. For each email, classify:
   - **Actionable**: Requires response, triggers a task, or is something Arao is waiting for
   - **Informational**: Useful but no action needed (confirmations, receipts, newsletters)
   - **Noise**: Promotions, automated junk, welcome emails, marketing
4. Handle:
   - **Actionable + urgent** → Notify Arao on Telegram (brief: who, what, what's needed). Label `Joe/Notified` (Label_2). Archive.
   - **Actionable + Joe can handle** → Act ONLY if confident. When in doubt, notify Arao instead. Label `Joe/Actioned` (Label_1). Archive.
   - **Informational / Noise** → Label `Joe/Archived` (Label_3). Archive.
5. Commands:
   - Archive: `./skills/gmail/scripts/gmail.sh archive <msgId>`
   - Label: `./skills/gmail/scripts/gmail.sh label <msgId> <labelId>`
