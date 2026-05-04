"""
Gmail Cleanup Tool
Moves emails from Promotions, Social, and/or Updates categories to Trash.
Dry-run is the default — pass --execute to actually move emails.
"""

import argparse
import json
import os
import random
import sys
import time
from datetime import datetime, timedelta

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = ["https://www.googleapis.com/auth/gmail.modify"]

LABEL_MAP = {
    "promotions": "CATEGORY_PROMOTIONS",
    "social": "CATEGORY_SOCIAL",
    "updates": "CATEGORY_UPDATES",
}

PAGE_SIZE = 500
BATCH_SIZE = 1000
TOKEN_FILE = "token.json"
CREDS_FILE = "credentials.json"


def get_credentials():
    creds = None

    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)

    if creds and creds.valid:
        return creds

    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
    else:
        if not os.path.exists(CREDS_FILE):
            sys.exit(
                f"ERROR: {CREDS_FILE} not found.\n"
                "Download your OAuth2 credentials from Google Cloud Console and\n"
                f"place the file as '{CREDS_FILE}' in this directory.\n"
                "See README.md for step-by-step instructions."
            )
        flow = InstalledAppFlow.from_client_secrets_file(CREDS_FILE, SCOPES)
        creds = flow.run_local_server(port=0)

    with open(TOKEN_FILE, "w") as f:
        f.write(creds.to_json())

    return creds


def list_messages(service, label_ids, older_than_days, max_emails):
    query = ""
    if older_than_days and older_than_days > 0:
        cutoff = datetime.now() - timedelta(days=older_than_days)
        query = f"before:{cutoff.strftime('%Y/%m/%d')}"

    message_ids = []
    page_token = None

    while True:
        kwargs = {
            "userId": "me",
            "labelIds": label_ids,
            "maxResults": PAGE_SIZE,
        }
        if query:
            kwargs["q"] = query
        if page_token:
            kwargs["pageToken"] = page_token

        resp = service.users().messages().list(**kwargs).execute()
        messages = resp.get("messages", [])
        message_ids.extend(m["id"] for m in messages)

        print(f"  Fetched {len(message_ids)} emails so far...", end="\r")

        if max_emails and len(message_ids) >= max_emails:
            message_ids = message_ids[:max_emails]
            break

        page_token = resp.get("nextPageToken")
        if not page_token:
            break

    print()  # newline after the \r progress line
    return message_ids


def _batch_modify_with_retry(service, chunk, max_retries=5):
    body = {
        "ids": chunk,
        "addLabelIds": ["TRASH"],
        "removeLabelIds": ["INBOX"],
    }
    for attempt in range(max_retries):
        try:
            service.users().messages().batchModify(userId="me", body=body).execute()
            return
        except HttpError as e:
            if e.resp.status in (429, 500, 503):
                wait = (2**attempt) + random.uniform(0, 1)
                print(f"\n  Rate limited (HTTP {e.resp.status}). Retrying in {wait:.1f}s...")
                time.sleep(wait)
            else:
                raise
    raise RuntimeError(f"batchModify failed after {max_retries} retries")


def batch_trash(service, message_ids, dry_run):
    if dry_run:
        print(f"[DRY RUN] Would move {len(message_ids)} email(s) to Trash.")
        return 0

    trashed = 0
    total = len(message_ids)
    for i in range(0, total, BATCH_SIZE):
        chunk = message_ids[i : i + BATCH_SIZE]
        _batch_modify_with_retry(service, chunk)
        trashed += len(chunk)
        print(f"  Moved {trashed}/{total} to Trash...", end="\r")

    print()  # newline after \r progress line
    return trashed


def parse_categories(csv_string):
    names = [s.strip().lower() for s in csv_string.split(",") if s.strip()]
    unknown = [n for n in names if n not in LABEL_MAP]
    if unknown:
        valid = ", ".join(LABEL_MAP.keys())
        sys.exit(f"ERROR: Unknown category/categories: {unknown}\nValid options: {valid}")
    return [LABEL_MAP[n] for n in names]


def confirm_action(count):
    print(f"\nFound {count} email(s) to move to Trash.")
    answer = input("Type 'yes' to confirm, anything else to cancel: ").strip().lower()
    return answer == "yes"


def build_parser():
    parser = argparse.ArgumentParser(
        description=(
            "Gmail Cleanup Tool — moves Promotions/Social/Updates emails to Trash.\n"
            "Dry-run is active by default. Use --execute to actually move emails."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Preview emails without moving to Trash (default behavior)",
    )
    mode.add_argument(
        "--execute",
        action="store_true",
        default=False,
        help="Actually move matching emails to Trash",
    )
    parser.add_argument(
        "--categories",
        default="promotions,social,updates",
        metavar="LIST",
        help="Comma-separated categories: promotions,social,updates (default: all three)",
    )
    parser.add_argument(
        "--older-than-days",
        type=int,
        default=0,
        metavar="N",
        help="Only target emails older than N days (default: 0 = all ages)",
    )
    parser.add_argument(
        "--max-emails",
        type=int,
        default=None,
        metavar="N",
        help="Cap the number of emails to process (default: no limit)",
    )
    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()

    dry_run = not args.execute

    label_ids = parse_categories(args.categories)
    category_names = [k for k, v in LABEL_MAP.items() if v in label_ids]

    print(f"Gmail Cleanup Tool")
    print(f"  Mode:       {'DRY RUN (preview only)' if dry_run else 'EXECUTE (will move to Trash)'}")
    print(f"  Categories: {', '.join(category_names)}")
    if args.older_than_days:
        print(f"  Age filter: older than {args.older_than_days} day(s)")
    if args.max_emails:
        print(f"  Email cap:  {args.max_emails}")
    print()

    print("Authenticating with Google...")
    creds = get_credentials()
    service = build("gmail", "v1", credentials=creds)
    print("Authenticated.\n")

    print(f"Searching for matching emails...")
    message_ids = list_messages(service, label_ids, args.older_than_days, args.max_emails)

    if not message_ids:
        print("No matching emails found. Nothing to do.")
        return

    print(f"Found {len(message_ids)} matching email(s).")

    if dry_run:
        print()
        batch_trash(service, message_ids, dry_run=True)
        print("\nTo move these emails to Trash, re-run with --execute:")
        cats = args.categories
        extra = ""
        if args.older_than_days:
            extra += f" --older-than-days {args.older_than_days}"
        if args.max_emails:
            extra += f" --max-emails {args.max_emails}"
        print(f"  python gmail_cleanup.py --execute --categories {cats}{extra}")
    else:
        if not confirm_action(len(message_ids)):
            print("Cancelled. No emails were moved.")
            return

        print()
        trashed = batch_trash(service, message_ids, dry_run=False)
        print(f"\nDone. {trashed} email(s) moved to Trash.")
        print("Recovery: open Gmail > Trash. Emails are kept for 30 days before auto-deletion.")


if __name__ == "__main__":
    main()
