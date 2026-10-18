#!/usr/bin/env python3
"""Reject reachable commits with a different author or committer."""

import subprocess
import sys
from pathlib import Path

result = subprocess.run(
    ["git", "log", "--all", "--format=%H%x00%an%x00%ae%x00%cn%x00%ce"],
    cwd=Path(__file__).resolve().parents[1],
    check=True,
    capture_output=True,
    text=True,
)
commits = result.stdout.splitlines()
if not commits:
    sys.exit("No commits to verify")
invalid = []
for line in commits:
    sha, author, author_email, committer, committer_email = line.split("\0")
    if (author, author_email, committer, committer_email) != (
        "LuRy", "lury@lury.cz", "LuRy", "lury@lury.cz"
    ):
        invalid.append(sha)
if invalid:
    sys.exit("Unexpected commit identity: " + ", ".join(invalid))
print(f"Verified LuRy <lury@lury.cz> for {len(commits)} commit(s)")
