#!/usr/bin/env python3
"""Upload the release AAB to a Google Play track.

    PLAY_SERVICE_ACCOUNT=<path to service-account.json> \
      python3 tool/play_upload.py --track internal --notes cs-CZ=notes-cs.txt

The app must already exist in Play Console. A new app still in draft accepts
only draft releases; pass --status draft until it has been published once.
"""

import argparse
import os
import pathlib
import sys

from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE = "com.nkshub.nextcloudnotes"
DEFAULT_AAB = (
    pathlib.Path(__file__).resolve().parents[1]
    / "apps/mobile/build/app/outputs/bundle/release/app-release.aab"
)

parser = argparse.ArgumentParser()
parser.add_argument("--aab", type=pathlib.Path, default=DEFAULT_AAB)
parser.add_argument("--track", default="internal")
parser.add_argument("--status", default="completed",
                    choices=["completed", "draft"])
parser.add_argument("--notes", action="append", default=[],
                    metavar="LANG=FILE", help="release notes per language")
args = parser.parse_args()

key = os.environ.get("PLAY_SERVICE_ACCOUNT")
if not key:
    sys.exit("PLAY_SERVICE_ACCOUNT is not set")
if not args.aab.is_file():
    sys.exit(f"missing {args.aab}; run flutter build appbundle --release")

notes = []
for item in args.notes:
    language, _, path = item.partition("=")
    text = pathlib.Path(path).read_text(encoding="utf-8").strip()
    if len(text) > 500:
        sys.exit(f"{language}: release notes exceed Play's 500 characters")
    notes.append({"language": language, "text": text})

service = build(
    "androidpublisher", "v3", cache_discovery=False,
    credentials=Credentials.from_service_account_file(
        key, scopes=["https://www.googleapis.com/auth/androidpublisher"]),
)
edits = service.edits()
edit = edits.insert(packageName=PACKAGE, body={}).execute()["id"]
try:
    bundle = edits.bundles().upload(
        packageName=PACKAGE, editId=edit,
        media_body=MediaFileUpload(str(args.aab),
                                   mimetype="application/octet-stream",
                                   resumable=True),
    ).execute()
    code = bundle["versionCode"]
    edits.tracks().update(
        packageName=PACKAGE, editId=edit, track=args.track,
        body={"track": args.track, "releases": [{
            "versionCodes": [str(code)],
            "status": args.status,
            "releaseNotes": notes,
        }]},
    ).execute()
    edits.commit(packageName=PACKAGE, editId=edit).execute()
except Exception:
    edits.delete(packageName=PACKAGE, editId=edit).execute()
    raise
print(f"uploaded versionCode {code} to {args.track} ({args.status})")
