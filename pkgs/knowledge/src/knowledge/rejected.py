"""Rejected knowledge: what the curator found wrong, and what the user dropped, as dated lines of text.

`rejected.md` in the state dir is append-only and never trimmed; the user may edit it. The prompt shows its last lines so
the curator does not take back what is listed there.
"""

import datetime
import os
from pathlib import Path

from .config import ensure_private, state_dir

FILE = "rejected.md"
FILE_MODE = 0o600
SHOWN = 100  # lines the prompt shows
NOTED_REASONS = ("refuted", "obsolete")  # the reasons of a delete op that are noted


def path() -> Path:
    return state_dir() / FILE


def note(text: str, today: datetime.date) -> None:
    """Append `- YYYY-MM-DD text` (the text on one line)."""
    line = f"- {today.isoformat()} {' '.join(text.split())}\n"
    ensure_private(state_dir())
    fd = os.open(path(), os.O_WRONLY | os.O_APPEND | os.O_CREAT, FILE_MODE)
    try:
        data = line.encode("utf-8", "replace")
        while data:
            data = data[os.write(fd, data) :]
    finally:
        os.close(fd)


def recent(limit: int = SHOWN) -> list[str]:
    """The last `limit` non-empty lines, oldest first; none if there is no file."""
    try:
        text = path().read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return []
    lines = [line.rstrip() for line in text.split("\n") if line.strip()]
    return lines[-limit:] if limit > 0 else []
