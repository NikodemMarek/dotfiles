"""Telling the user, through the event router, that the curator needs them (S4: `notified.json`)."""

import datetime
import logging
from pathlib import Path

from . import data, emit
from .config import ensure_private, router_url, state_dir
from .data import Obj, ParseError
from .store import atomic_write

log = logging.getLogger("knowledge")

EVENT_TYPE = "knowledge.review_needed"  # the name an external router config matches on: do not rename
PROJECT = "knowledge"
FILE_MODE = 0o600


def _path() -> Path:
    return state_dir() / "notified.json"


def _load() -> dict[str, str]:
    """key -> the day it was last notified; a missing or damaged file is empty."""
    try:
        obj = data.as_obj(data.loads(_path().read_text(encoding="utf-8")), "notified.json")
    except (OSError, UnicodeDecodeError, ParseError):
        return {}
    return {k: v for k, v in obj.items() if isinstance(v, str)}


def _save(day: str, key: str, seen: dict[str, str]) -> None:
    """Only today's keys matter for the dedupe, so the older ones are dropped."""
    kept: Obj = {}
    for k, v in seen.items():
        if v == day:
            kept[k] = v
    kept[key] = day
    ensure_private(state_dir())
    atomic_write(_path(), data.dumps(kept) + "\n", FILE_MODE)


def notify(title: str, body: str, key: str | None = None, today: datetime.date | None = None) -> bool:
    """Post a `knowledge.review_needed` event; whether it was sent.

    With a `key` it is sent once a day at most. A router that does not answer is only a warning: the curator's work
    does not depend on it.
    """
    day = (today or datetime.datetime.now(datetime.UTC).date()).isoformat()
    seen = _load()
    if key is not None and seen.get(key) == day:
        log.debug("notification %s was sent today already", key)
        return False
    event: Obj = {"type": EVENT_TYPE, "project": PROJECT, "title": title, "body": body}
    try:
        emit.post(event, router_url(), delays=())
    except emit.EmitError as e:
        log.warning("could not notify (%s): %s", title, e)
        return False
    if key is not None:
        try:
            _save(day, key, seen)
        except OSError as e:
            log.warning("could not write notified.json: %s", e)
    return True
