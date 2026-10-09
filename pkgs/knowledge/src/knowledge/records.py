"""Submission records: the wire event, its validation, trust and the inbox file (S4)."""

import datetime
import hashlib
import os
import re
from dataclasses import dataclass, replace

from . import data, secrets
from .data import Obj, ParseError
from .entry import KINDS, SCOPE_RE, TRUSTS

RECORD_VERSION = 1
MAX_TITLE = 200
MAX_BODY_BYTES = 65536
MAX_EVIDENCE = 2000
MAX_ORIGIN_FIELD = 1000
MAX_SHOWN = 40  # chars of a wire value an error message may carry
USER_AGENT = "user"  # an agent name only the user's own submissions carry

ID_RE = re.compile(r"s-\d{8}T\d{6}Z-[0-9a-f]{6}")
_SCOPE = re.compile(SCOPE_RE)
_AGENT_WORKSPACE = re.compile(r"/[^/]+\.agents/gl-")  # the workspace of an agent that an event launched
_DIRECT_VIA = ("user", "import")  # only trusted when not relayed by the router


class RecordError(ParseError):
    """A submission that is not valid."""


@dataclass(frozen=True)
class Origin:
    via: str  # cli, subagent-stop, user, import
    agent: str | None
    cwd: str | None
    event: str | None  # e.g. event:gitlab.note, set when an event launched the agent
    session: str | None


@dataclass(frozen=True)
class Record:
    id: str
    received: str  # ISO timestamp, UTC
    trust: str
    attempt: int
    title: str
    body: str
    kind: str | None
    scope: str | None  # a hint
    evidence: str | None
    origin: Origin
    last_errors: tuple[str, ...] = ()  # why the curator's last decision about it was refused; set when it is retried


# ids and times


def _utcnow() -> datetime.datetime:
    return datetime.datetime.now(datetime.UTC)


def new_id(now: datetime.datetime | None = None) -> str:
    return f"s-{(now or _utcnow()):%Y%m%dT%H%M%SZ}-{os.urandom(3).hex()}"


_ID_DIGITS = 14  # the YYYYmmddTHHMMSS of an id: 8 digits, `T`, 6 digits


def stable_id(*parts: str) -> str:
    """An id derived from the parts, so that the same parts always give the same id (a block posted twice dedupes).

    It has the form of `new_id`, but its 14 digits are not a time: they come from the hash, with the 6 hex, so that
    two different submissions rarely share an id.
    """
    digest = hashlib.sha256("\0".join(parts).encode("utf-8", "replace")).hexdigest()
    digits = str(int(digest[6:26], 16)).zfill(_ID_DIGITS)[-_ID_DIGITS:]  # the low digits; `**` is typed Any
    return f"s-{digits[:8]}T{digits[8:]}Z-{digest[:6]}"


def _timestamp(now: datetime.datetime) -> str:
    return f"{now:%Y-%m-%dT%H:%M:%SZ}"


# validation


def _shown(value: str) -> str:
    """A wire value for an error message: the messages are logged, and the value may be a secret."""
    return secrets.mask(value[:MAX_SHOWN])


def _no_controls(what: str, value: str) -> None:
    """A control character (below 0x20, a tab excepted) in a field that git or a log line carries cannot be sanitized."""
    if any(c < " " and c != "\t" for c in value):
        raise RecordError(f"{what}: must not hold control characters")


def _title(o: Obj) -> str:
    title = " ".join(data.get_str(o, "title").split())
    if not 1 <= len(title) <= MAX_TITLE:
        raise RecordError(f"title: must be 1..{MAX_TITLE} chars, got {len(title)}")
    _no_controls("title", title)
    return title


def _body(o: Obj) -> str:
    body = data.get_str(o, "body")
    size = len(body.encode("utf-8", "replace"))
    if not body.strip():
        raise RecordError("body: empty")
    if size > MAX_BODY_BYTES:
        raise RecordError(f"body: {size} bytes exceeds the {MAX_BODY_BYTES} byte limit")
    return body


def _kind(o: Obj) -> str | None:
    kind = data.opt_str(o, "kind")
    if kind is not None and kind not in KINDS:
        raise RecordError(f"kind: {_shown(kind)!r} is not one of {', '.join(KINDS)}")
    return kind


def _scope(o: Obj) -> str | None:
    """Only a hint: one that is not a valid scope is dropped."""
    scope = data.opt_str(o, "scope")
    return scope if scope is not None and _SCOPE.fullmatch(scope) is not None else None


def _evidence(o: Obj) -> str | None:
    evidence = data.opt_str(o, "evidence")
    if evidence is None or not evidence.strip():
        return None
    if len(evidence) > MAX_EVIDENCE:
        raise RecordError(f"evidence: at most {MAX_EVIDENCE} chars, got {len(evidence)}")
    _no_controls("evidence", evidence)
    return evidence


def _origin_field(o: Obj, key: str) -> str | None:
    value = data.opt_str(o, key)
    if value is not None and len(value) > MAX_ORIGIN_FIELD:
        raise RecordError(f"origin.{key}: at most {MAX_ORIGIN_FIELD} chars, got {len(value)}")
    if value is not None:
        _no_controls(f"origin.{key}", value)
    return value or None


def _origin(o: Obj) -> Origin:
    ob = data.get_obj(o, "origin")
    via = _origin_field(ob, "via")
    if via is None:
        raise RecordError("origin.via: missing")
    return Origin(
        via=via,
        agent=_origin_field(ob, "agent"),
        cwd=_origin_field(ob, "cwd"),
        event=_origin_field(ob, "event"),
        session=_origin_field(ob, "session"),
    )


def _checked_id(value: str) -> str:
    if ID_RE.fullmatch(value) is None:
        raise RecordError(f"id: {_shown(value)!r} is not of the form s-YYYYmmddTHHMMSSZ-<6 hex>")
    return value


# trust


def in_agent_workspace(cwd: str | None) -> bool:
    """True for the workspace of an agent that an event launched (`<repo>.agents/gl-...`)."""
    return cwd is not None and _AGENT_WORKSPACE.search(cwd) is not None


def trust_for(origin: Origin, via_router: bool) -> str:
    """What the submitter may be believed: `user` only for a direct user or import, `untrusted` for event-driven agents."""
    if origin.via in _DIRECT_VIA and not via_router:
        return "user"
    if origin.event or in_agent_workspace(origin.cwd):
        return "untrusted"
    return "agent"


# conversion


def _relayed(origin: Origin) -> Origin:
    """The origin of an event that came through the router, which cannot vouch for a user or an import."""
    via = "cli" if origin.via in _DIRECT_VIA else origin.via
    agent = None if origin.agent == USER_AGENT else origin.agent
    return replace(origin, via=via, agent=agent)


def from_event(obj: Obj, via_router: bool, now: datetime.datetime | None = None) -> Record:
    """A record from a `knowledge.submit` event (the `type` key is not looked at); raises ParseError.

    `via_router`: the event came over the wire, so its origin is only a claim; it is not believed to be the user
    (`via` user or import becomes `cli`, the agent name `user` is dropped) and its trust is never `user`.
    """
    now = now or _utcnow()
    origin = _origin(obj)
    if via_router:
        origin = _relayed(origin)
    raw_id = data.opt_str(obj, "id")
    return Record(
        id=new_id(now) if raw_id is None else _checked_id(raw_id),
        received=_timestamp(now),
        trust=trust_for(origin, via_router),
        attempt=0,
        title=_title(obj),
        body=_body(obj),
        kind=_kind(obj),
        scope=_scope(obj),
        evidence=_evidence(obj),
        origin=origin,
    )


def from_obj(obj: Obj) -> Record:
    """A record from an inbox file; raises ParseError."""
    version = data.get_int(obj, "v")
    if version != RECORD_VERSION:
        raise RecordError(f"v: unsupported record version {version}")
    trust = data.get_str(obj, "trust")
    if trust not in TRUSTS:
        raise RecordError(f"trust: {trust!r} is not one of {', '.join(TRUSTS)}")
    attempt = data.get_int(obj, "attempt")
    if attempt < 0:
        raise RecordError(f"attempt: must not be negative, got {attempt}")
    return Record(
        id=_checked_id(data.get_str(obj, "id")),
        received=data.get_str(obj, "received"),
        trust=trust,
        attempt=attempt,
        title=_title(obj),
        body=_body(obj),
        kind=_kind(obj),
        scope=_scope(obj),
        evidence=_evidence(obj),
        origin=_origin(obj),
        last_errors=tuple(data.str_list(obj, "last_errors")),
    )


def origin_obj(origin: Origin) -> Obj:
    return {
        "via": origin.via,
        "agent": origin.agent,
        "cwd": origin.cwd,
        "event": origin.event,
        "session": origin.session,
    }


def to_obj(rec: Record) -> Obj:
    """The inbox file."""
    return {
        "v": RECORD_VERSION,
        "id": rec.id,
        "received": rec.received,
        "trust": rec.trust,
        "attempt": rec.attempt,
        "title": rec.title,
        "body": rec.body,
        "kind": rec.kind,
        "scope": rec.scope,
        "evidence": rec.evidence,
        "origin": origin_obj(rec.origin),
        "last_errors": data.strs(rec.last_errors),
    }
