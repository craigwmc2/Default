# Gmail Cleanup Tool

A Python script that connects to your Gmail account and bulk-moves emails from the **Promotions**, **Social**, and **Updates** categories to Trash — safely and efficiently.

**Dry-run is the default.** The script will never move anything unless you explicitly pass `--execute`.

---

## Safety First

- Running the script without `--execute` only **previews** what would be trashed — no changes are made.
- Emails moved to Trash are **kept for 30 days** and can be recovered from Gmail's Trash folder at any time.
- The script uses the `gmail.modify` scope — it **cannot permanently delete** emails.

---

## Prerequisites

- Python 3.8 or newer
- `pip`
- A Google account (the Gmail account you want to clean up)

---

## Step 1 — Create a Google Cloud Project

1. Go to [https://console.cloud.google.com/](https://console.cloud.google.com/)
2. Click the project selector at the top → **New Project**
3. Give it a name (e.g., `Gmail Cleanup`) and click **Create**
4. Once created, select that project in the top bar

---

## Step 2 — Enable the Gmail API

1. In the left sidebar: **APIs & Services** → **Library**
2. Search for `Gmail API`
3. Click **Gmail API** → click **Enable**

---

## Step 3 — Create OAuth2 Credentials

1. Go to **APIs & Services** → **Credentials** → **Create Credentials** → **OAuth client ID**

2. If prompted to configure the OAuth Consent Screen first:
   - **User Type:** External
   - **App name:** `Gmail Cleanup` (or any name you like)
   - **User support email:** your Gmail address
   - **Developer contact email:** your Gmail address
   - Click **Save and Continue** through the Scopes step (no changes needed there)
   - Under **Test users**, click **Add Users** and add your own Gmail address
   - Click **Save and Continue**, then **Back to Dashboard**

3. Back in **Create OAuth client ID**:
   - **Application type:** Desktop App
   - **Name:** `Gmail Cleanup Desktop`
   - Click **Create**

4. In the dialog that appears, click **Download JSON**

5. Rename the downloaded file to `credentials.json` and place it in the same folder as `gmail_cleanup.py`

---

## Step 4 — Install Dependencies

```bash
pip install -r requirements.txt
```

---

## Step 5 — First Run (Browser Authentication)

```bash
python gmail_cleanup.py
```

- A browser window opens asking you to sign in with your Google account
- Click **Continue** past the "Google hasn't verified this app" warning (this is expected for personal projects)
- Grant the requested permissions
- Return to the terminal — a `token.json` file is created automatically
- **Future runs reuse `token.json`** — no browser interaction needed

---

## Usage Examples

```bash
# Preview what would be trashed across all three categories (safe default)
python gmail_cleanup.py

# Preview only Promotions
python gmail_cleanup.py --categories promotions

# Preview emails older than 90 days
python gmail_cleanup.py --older-than-days 90

# Preview Promotions older than 30 days, limit to 500
python gmail_cleanup.py --categories promotions --older-than-days 30 --max-emails 500

# Execute: move all three categories to Trash (requires confirmation)
python gmail_cleanup.py --execute

# Execute: move only Promotions older than 60 days to Trash
python gmail_cleanup.py --execute --categories promotions --older-than-days 60

# Execute: move Promotions + Social, cap at 200 emails
python gmail_cleanup.py --execute --categories promotions,social --max-emails 200
```

---

## All Options

| Flag | Default | Description |
|------|---------|-------------|
| *(no flag)* | — | Dry-run (preview only) |
| `--dry-run` | — | Same as above, explicit |
| `--execute` | — | Actually move emails to Trash |
| `--categories LIST` | `promotions,social,updates` | Comma-separated categories to target |
| `--older-than-days N` | `0` (all ages) | Only target emails older than N days |
| `--max-emails N` | no limit | Cap the number of emails processed |

---

## Files Created by the Script

| File | Purpose |
|------|---------|
| `token.json` | Cached OAuth token — reused on subsequent runs |
| `credentials.json` | Your OAuth client secret — downloaded from Google Cloud |

**Keep both files private.** They are already listed in `.gitignore` so they won't be accidentally committed.

---

## Security Notes

- Never commit `token.json` or `credentials.json` to version control
- The `gmail.modify` scope allows reading and labeling but **not** permanent deletion
- To revoke access at any time: [https://myaccount.google.com/permissions](https://myaccount.google.com/permissions)

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| `credentials.json not found` | Download from Cloud Console (Step 3) and place in the script folder |
| "Access blocked: app not verified" | In the OAuth Consent Screen, add your Gmail address as a **Test user** |
| "The caller does not have permission" | Make sure you enabled the Gmail API (Step 2) |
| Quota / rate limit errors | The script retries automatically with exponential backoff |
| Browser doesn't open | Delete `token.json` and re-run; or try on a machine with a browser |
