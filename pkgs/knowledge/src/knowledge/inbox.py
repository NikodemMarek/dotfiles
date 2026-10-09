"""The inbox of submissions: one `<id>.json` file per record not yet curated (S4).

A file is written whole by `atomic_write`, so a reader never sees half of one; the same id replaces the file.
A file that cannot be parsed is set aside as `<name>.bad`, one the curator gave up on as `<name>.failed`; a name that
is taken gets a `.1`, `.2` and so on, so nothing is overwritten.
"""

import logging
from pathlib import Path

from . import data, store
from .config import ensure_private, inbox_dir
from .data import ParseError
from .records import ID_RE, Record, from_obj, to_obj

log = logging.getLogger("knowledge")

FILE_MODE = 0o600
SUFFIX = ".json"
BAD = ".bad"
FAILED = ".failed"


class Inbox:
    def __init__(self, directory: Path | None = None) -> None:
        self.dir = inbox_dir() if directory is None else directory

    def _path(self, sid: str) -> Path:
        if ID_RE.fullmatch(sid) is None:
            raise ValueError(f"{sid!r} is not a submission id")
        return self.dir / f"{sid}{SUFFIX}"

    def put(self, rec: Record) -> None:
        """Durable once it returns; a record with the id of a file in the inbox replaces it."""
        path = self._path(rec.id)
        ensure_private(self.dir)
        store.atomic_write(path, data.dumps(to_obj(rec)) + "\n", FILE_MODE, durable=True)

    def remove(self, sid: str) -> None:
        self._path(sid).unlink(missing_ok=True)

    def has(self, sid: str) -> bool:
        try:
            return self._path(sid).is_file()
        except ValueError:
            return False

    def count(self) -> int:
        """The files waiting, unparsable ones included."""
        return sum(1 for _ in self.dir.glob(f"*{SUFFIX}"))

    def fail(self, sid: str) -> None:
        """Set the file aside as `<id>.json.failed`: the record is given up on but kept; `mv` it back to try again."""
        path = self._path(sid)
        if path.is_file():
            _aside(path, FAILED)

    def state(self, sid: str) -> str | None:
        """`pending` if the id has a file in the inbox, else `failed` or `bad` if one was set aside, else None."""
        try:
            path = self._path(sid)
        except ValueError:
            return None
        if path.is_file():
            return "pending"
        for state, suffix in (("failed", FAILED), ("bad", BAD)):
            if any(self.dir.glob(f"{path.name}{suffix}*")):
                return state
        return None

    def _read(self, path: Path, set_aside: bool) -> tuple[Record, int] | None:
        """The record of a file and the size of the file; None if the file is gone, unreadable or unparsable.

        An unparsable file is set aside as `.bad` if `set_aside`.
        """
        try:
            raw = path.read_bytes()
        except FileNotFoundError:
            return None
        except OSError as e:
            log.warning("inbox %s: skipping a file that cannot be read: %s", path.name, e)
            return None
        try:
            rec = from_obj(data.as_obj(data.loads(raw.decode("utf-8", "replace")), path.name))
            if path.name != f"{rec.id}{SUFFIX}":
                raise ParseError(f"the file holds the record {rec.id}")
        except ParseError as e:
            if not set_aside:
                log.warning("inbox %s: skipping an unparsable file: %s", path.name, e)
                return None
            try:
                bad = _aside(path, BAD)
            except OSError as oe:
                log.warning("inbox %s: skipping an unparsable file that cannot be set aside: %s", path.name, oe)
                return None
            log.warning("inbox %s: setting aside an unparsable file as %s: %s", path.name, bad.name, e)
            return None
        return rec, len(raw)

    def pending(self, max_bytes: int, set_aside: bool = True) -> list[Record]:
        """The records by `received`, then id: at least one, then as many more as keep the files within `max_bytes`.

        A file that cannot be read is logged and skipped. One that cannot be parsed is renamed to `.bad` if `set_aside`
        (a read-only run leaves it where it is).
        """
        found = [item for path in self.dir.glob(f"*{SUFFIX}") if (item := self._read(path, set_aside)) is not None]
        found.sort(key=_order)
        records: list[Record] = []
        total = 0
        for rec, size in found:
            if records and total + size > max_bytes:
                break
            records.append(rec)
            total += size
        return records


def _order(item: tuple[Record, int]) -> tuple[str, str]:
    return item[0].received, item[0].id


def _aside(path: Path, suffix: str) -> Path:
    """Rename the file to `<name><suffix>`, or `<name><suffix>.1`, `.2` and so on: the first name that is free."""
    target = path.with_name(f"{path.name}{suffix}")
    n = 0
    while target.exists():
        n += 1
        target = path.with_name(f"{path.name}{suffix}.{n}")
    path.rename(target)
    return target
