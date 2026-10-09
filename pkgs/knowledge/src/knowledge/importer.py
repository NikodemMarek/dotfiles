"""Importing notes (Claude Code auto-memory files, plain markdown) as submissions straight into the inbox."""

import logging
from collections.abc import Sequence
from dataclasses import dataclass, replace
from pathlib import Path

from . import data, emit, records
from .config import UsageError
from .data import Obj, ParseError
from .entry import EntryError, split_frontmatter
from .inbox import Inbox
from .records import MAX_BODY_BYTES, MAX_TITLE, Origin, Record

log = logging.getLogger("knowledge")

INDEX_NAME = "MEMORY.md"  # the auto-memory index: links, not knowledge
REFERENCE_TYPE = "reference"
UNTRUSTED = "untrusted"


class Skip(Exception):
    """A file that is not imported; the message says why."""


@dataclass(frozen=True)
class ImportResult:
    ids: tuple[str, ...]
    skipped: int


def collect(paths: Sequence[str]) -> list[Path]:
    """The files to import: the given files, and the `*.md` files of the given directories. `MEMORY.md` is left out."""
    files: list[Path] = []
    seen: set[Path] = set()
    for raw in paths:
        path = Path(raw)
        if path.is_dir():
            found = sorted(p for p in path.glob("*.md") if p.is_file())
        elif path.is_file():
            found = [path]
        else:
            raise UsageError(f"{raw}: not a file or directory")
        for p in found:
            full = p.resolve()
            if p.name == INDEX_NAME or full in seen:
                continue
            seen.add(full)
            files.append(full)
    return files


def _text(meta: Obj, key: str) -> str | None:
    value = meta.get(key)
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _heading(body: str) -> str | None:
    for line in body.splitlines():
        if line.startswith("# ") and line[2:].strip():
            return line[2:].strip()
    return None


def _split(text: str) -> tuple[Obj, str]:
    """Frontmatter is optional and its keys are all optional; a broken one is a reason to skip the file."""
    if not text.startswith("---\n"):
        return {}, text.strip("\n")
    try:
        return split_frontmatter(text)
    except EntryError as e:
        end = text.find("\n---\n", 3)
        if end < 0:
            raise Skip(f"unusable frontmatter: {e}") from e
        # Claude Code writes `description: a: b` unquoted, which is not YAML: read such lines as plain `key: value`
        return _loose_frontmatter(text[4:end]), text[end + 5 :].strip("\n")


def _loose_frontmatter(text: str) -> Obj:
    """`key: value` lines, the value taken verbatim; indented lines under a key with no value form a nested mapping."""
    meta: Obj = {}
    nested: Obj | None = None
    for line in text.split("\n"):
        if not line.strip():
            continue
        key, sep, value = line.strip().partition(":")
        if not sep or not key or " " in key:
            continue
        if line[0] in " \t":
            if nested is not None:
                nested[key] = value.strip()
            continue
        if value.strip():
            meta[key] = value.strip()
            nested = None
        else:
            child: Obj = {}
            meta[key] = child
            nested = child
    return meta


def _kind(meta: Obj) -> str | None:
    metadata = meta.get("metadata")
    if isinstance(metadata, dict) and metadata.get("type") == REFERENCE_TYPE:
        return REFERENCE_TYPE
    return None


def capped_trust(trust: str, origin: Origin) -> str:
    """`trust`, except that an import from a context that is not trusted (an event launched it, or it runs in the
    workspace of one) stays `untrusted`: it gets what a cli submission from the same event and cwd would get."""
    ceiling = records.trust_for(replace(origin, via="cli"), via_router=False)
    return UNTRUSTED if ceiling == UNTRUSTED else trust


def load_record(path: Path, trust: str, origin: Origin) -> Record:
    """The submission of one file, with the trust capped by what the origin allows; raises Skip."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        raise Skip(f"cannot read: {e}") from e
    meta, body = _split(text)
    if not body.strip():
        raise Skip("empty body")
    size = len(body.encode("utf-8", "replace"))
    if size > MAX_BODY_BYTES:
        raise Skip(f"body is {size} bytes, over the {MAX_BODY_BYTES} byte limit")
    title = _text(meta, "description") or _text(meta, "name") or _heading(body) or path.stem
    try:
        rec = records.from_event(
            {
                "title": " ".join(title.split())[:MAX_TITLE].rstrip(),
                "body": body,
                "kind": _kind(meta),
                "scope": None,
                "evidence": f"imported from {path.resolve()}",
                "origin": records.origin_obj(origin),
            },
            via_router=False,
        )
    except ParseError as e:
        raise Skip(str(e)) from e
    if (secret := emit.hard_secret(rec)) is not None:
        raise Skip(f"looks like a secret ({secret})")
    return replace(rec, trust=capped_trust(trust, origin))


def import_files(files: Sequence[Path], trust: str, inbox: Inbox, origin: Origin) -> ImportResult:
    """Put each importable file in the inbox, directly; the others are skipped with a warning."""
    ids: list[str] = []
    skipped = 0
    for path in files:
        try:
            rec = load_record(path, trust, origin)
        except Skip as e:
            log.warning("skipping %s: %s", path, e)
            skipped += 1
            continue
        inbox.put(rec)
        ids.append(rec.id)
    return ImportResult(tuple(ids), skipped)


def result_obj(result: ImportResult) -> Obj:
    ids: list[data.Json] = [i for i in result.ids]
    return {"imported": len(result.ids), "skipped": result.skipped, "ids": ids}
