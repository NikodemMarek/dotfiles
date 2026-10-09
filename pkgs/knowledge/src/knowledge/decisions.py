"""The decision log: what the curator did with each submission, one line per decision in `decisions.jsonl` (S4)."""

import datetime
import logging
import os
from dataclasses import dataclass
from pathlib import Path

from . import data
from .config import ensure_private, state_dir
from .data import Json, Obj, ParseError
from .store import atomic_write

log = logging.getLogger("knowledge")

OUTCOMES = ("applied", "rejected", "invalid", "deferred", "failed")
DECIDED = ("applied", "rejected")  # the outcomes that end a submission
RETENTION_DAYS = 90
FILE_MODE = 0o600


@dataclass(frozen=True)
class Decision:
    id: str | None  # the submission; None for a maintenance decision
    key: str  # the id, or m-<run>-<n> for maintenance
    run: str
    at: str  # ISO timestamp
    verdict: str
    reason: str
    paths: tuple[str, ...]
    commit: str | None
    outcome: str
    notes: tuple[str, ...]


def to_obj(d: Decision) -> Obj:
    paths: list[Json] = [p for p in d.paths]
    notes: list[Json] = [n for n in d.notes]
    return {
        "id": d.id,
        "key": d.key,
        "run": d.run,
        "at": d.at,
        "verdict": d.verdict,
        "reason": d.reason,
        "paths": paths,
        "commit": d.commit,
        "outcome": d.outcome,
        "notes": notes,
    }


def from_obj(o: Obj) -> Decision:
    """A decision from a log line; raises ParseError."""
    outcome = data.get_str(o, "outcome")
    if outcome not in OUTCOMES:
        raise ParseError(f"outcome: {outcome!r} is not one of {', '.join(OUTCOMES)}")
    return Decision(
        id=data.opt_str(o, "id"),
        key=data.get_str(o, "key"),
        run=data.get_str(o, "run"),
        at=data.get_str(o, "at"),
        verdict=data.get_str(o, "verdict"),
        reason=data.str_or(o, "reason"),
        paths=tuple(data.str_list(o, "paths")),
        commit=data.opt_str(o, "commit"),
        outcome=outcome,
        notes=tuple(data.str_list(o, "notes")),
    )


def _parse_at(at: str) -> datetime.datetime | None:
    try:
        t = datetime.datetime.fromisoformat(at)
    except ValueError:
        return None
    return t if t.tzinfo is not None else t.replace(tzinfo=datetime.UTC)


def _read_objs(path: Path) -> list[Obj]:
    """Every JSON object in the file, in order; a missing file is empty, unparsable lines are logged and skipped."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return []
    out: list[Obj] = []
    for n, line in enumerate(text.split("\n"), 1):  # not splitlines(): it also splits on U+2028 and the like
        if not line.strip():
            continue
        try:
            out.append(data.as_obj(data.loads(line), "line"))
        except ParseError as e:
            log.warning("%s line %d: skipping an unparsable line: %s", path.name, n, e)
    return out


class Decisions:
    def __init__(self, directory: Path | None = None) -> None:
        self.dir = state_dir() if directory is None else directory
        self.path = self.dir / "decisions.jsonl"

    def append(self, d: Decision) -> None:
        """One line, one write, after a newline. A torn line (a crash mid-write) is skipped by the reader."""
        line = b"\n" + (data.dumps(to_obj(d)) + "\n").encode("utf-8", "replace")  # the \n ends a torn line left by a crash
        ensure_private(self.dir)
        fd = os.open(self.path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, FILE_MODE)
        try:
            while line:
                line = line[os.write(fd, line) :]
        finally:
            os.close(fd)

    def all(self) -> list[Decision]:
        """Every decision in the log, oldest first; lines that are not decisions are logged and skipped."""
        out: list[Decision] = []
        for obj in _read_objs(self.path):
            try:
                out.append(from_obj(obj))
            except ParseError as e:
                log.warning("decisions.jsonl: skipping a line that is not a decision: %s", e)
        return out

    def decided_ids(self) -> set[str]:
        """Submissions that were applied or rejected.

        Not `deferred` (asked of the curator again), and not `failed` or `invalid`: a failed record waits in the inbox
        as `.failed`, and `mv` back makes it a candidate for one more try.
        """
        return {d.id for d in self.all() if d.id is not None and d.outcome in DECIDED}

    def trim(self, days: int = RETENTION_DAYS, now: datetime.datetime | None = None) -> int:
        """Drop the decisions older than `days` (atomic rewrite); how many went."""
        cutoff = (now or datetime.datetime.now(datetime.UTC)) - datetime.timedelta(days=days)
        current = self.all()
        kept = [d for d in current if (t := _parse_at(d.at)) is not None and t >= cutoff]
        if len(kept) == len(current):
            return 0
        ensure_private(self.dir)
        atomic_write(self.path, "".join(data.dumps(to_obj(d)) + "\n" for d in kept), FILE_MODE)
        return len(current) - len(kept)


def status(sid: str, decisions: Decisions, inbox_state: str | None) -> Obj:
    """What became of a submission, given its state in the inbox (`pending`, `failed`, `bad` or None).

    A file in the inbox reads as pending. Else the latest decision that is not `deferred` (a deferred one means the
    curator will be asked again, so a deferred record whose file is gone is unknown). Else the state of a file set aside.
    """
    if inbox_state == "pending":
        return {"id": sid, "state": "pending"}
    d = next((d for d in reversed(decisions.all()) if d.id == sid and d.outcome != "deferred"), None)
    if d is not None:
        paths: list[Json] = [p for p in d.paths]
        notes: list[Json] = [n for n in d.notes]
        return {
            "id": sid,
            "state": d.outcome,
            "key": d.key,
            "run": d.run,
            "at": d.at,
            "verdict": d.verdict,
            "reason": d.reason,
            "paths": paths,
            "commit": d.commit,
            "notes": notes,
        }
    return {"id": sid, "state": inbox_state or "unknown"}
