"""The entry model: a markdown file with YAML frontmatter at `<scope>/<name>.md` (S2)."""

import datetime
import re
from collections.abc import Iterable
from dataclasses import dataclass

from . import data
from .data import Json, Obj, ParseError

SCOPE_RE = r"global|(lang|topic|org)/[a-z0-9][a-z0-9-]{0,39}|projects/[a-z0-9][a-z0-9-]{0,63}/facts"
NAME_RE = r"[a-z0-9][a-z0-9-]{0,63}"

KINDS = ("fact", "gotcha", "howto", "convention", "preference", "reference")
CONFIDENCES = ("high", "medium", "low")
TRUSTS = ("user", "agent", "untrusted")  # most trusted first
STATUSES = ("active", "disputed")

MAX_DESCRIPTION = 200
MAX_VERIFY = 300
MAX_TAGS = 8
MAX_EVIDENCE = 500
MAX_BODY = 4096
MAX_REFERENCE_BODY = 32768

_SCOPE = re.compile(SCOPE_RE)
_NAME = re.compile(NAME_RE)
_DATE = re.compile(r"\d{4}-\d{2}-\d{2}")

_FENCE = "\n---\n"

# the order of the keys in a rendered file
KEYS = (
    "name",
    "description",
    "kind",
    "scope",
    "tags",
    "confidence",
    "trust",
    "status",
    "created",
    "updated",
    "last_verified",
    "verify",
    "related",
    "sources",
)
SOURCE_KEYS = ("date", "by", "project", "trust", "submission", "evidence")


class EntryError(ParseError):
    """A malformed entry, entry path or frontmatter."""


@dataclass(frozen=True)
class Source:
    date: str  # ISO date
    by: str  # agent name or "user"
    project: str | None
    trust: str
    submission: str  # submission id
    evidence: str


@dataclass(frozen=True)
class Entry:
    name: str
    description: str
    kind: str
    scope: str
    tags: tuple[str, ...]
    confidence: str
    trust: str
    status: str
    created: str  # ISO dates
    updated: str
    last_verified: str
    verify: str | None
    related: tuple[str, ...]  # entry paths
    sources: tuple[Source, ...]
    body: str  # no surrounding blank lines

    @property
    def rel(self) -> str:
        return entry_rel(self.scope, self.name)


# paths


def entry_rel(scope: str, name: str) -> str:
    if _SCOPE.fullmatch(scope) is None:
        raise EntryError(f"invalid scope {scope!r}")
    if _NAME.fullmatch(name) is None:
        raise EntryError(f"invalid entry name {name!r}")
    return f"{scope}/{name}.md"


def split_rel(rel: str) -> tuple[str, str]:
    """`<scope>/<name>.md` into (scope, name). `projects/<slug>/overview.md` is not an entry."""
    if not rel.endswith(".md"):
        raise EntryError(f"{rel!r}: an entry path ends with .md")
    scope, sep, name = rel.removesuffix(".md").rpartition("/")
    if not sep:
        raise EntryError(f"{rel!r}: an entry path is <scope>/<name>.md")
    try:
        entry_rel(scope, name)
    except EntryError as e:
        raise EntryError(f"{rel!r}: {e}") from e
    return scope, name


# small helpers


def max_trust(trusts: Iterable[str]) -> str:
    """The most trusted of them (user > agent > untrusted); `untrusted` for none."""
    best = len(TRUSTS) - 1
    for t in trusts:
        if t not in TRUSTS:
            raise EntryError(f"invalid trust {t!r}")
        best = min(best, TRUSTS.index(t))
    return TRUSTS[best]


def min_trust(trusts: Iterable[str]) -> str:
    """The least trusted of them (untrusted < agent < user); `user` for none."""
    worst = 0
    for t in trusts:
        if t not in TRUSTS:
            raise EntryError(f"invalid trust {t!r}")
        worst = max(worst, TRUSTS.index(t))
    return TRUSTS[worst]


def body_limit(kind: str) -> int:
    """Bytes."""
    return MAX_REFERENCE_BODY if kind == "reference" else MAX_BODY


def _one_of(what: str, value: str, allowed: tuple[str, ...]) -> None:
    if value not in allowed:
        raise EntryError(f"{what}: {value!r} is not one of {', '.join(allowed)}")


def _check_date(what: str, value: str) -> None:
    try:
        if _DATE.fullmatch(value) is None:
            raise ValueError(value)
        datetime.date.fromisoformat(value)
    except ValueError:
        raise EntryError(f"{what}: {value!r} is not an ISO date (YYYY-MM-DD)") from None


# validation


def validate_entry(e: Entry) -> None:
    """Everything the file format promises; raises EntryError."""
    entry_rel(e.scope, e.name)
    if not 1 <= len(e.description) <= MAX_DESCRIPTION:
        raise EntryError(f"description: must be 1..{MAX_DESCRIPTION} chars, got {len(e.description)}")
    if "\n" in e.description or "\r" in e.description:
        raise EntryError("description: must be a single line")
    _one_of("kind", e.kind, KINDS)
    if len(e.tags) > MAX_TAGS:
        raise EntryError(f"tags: at most {MAX_TAGS}, got {len(e.tags)}")
    for tag in e.tags:
        if _NAME.fullmatch(tag) is None:
            raise EntryError(f"tags: invalid tag {tag!r}")
    _one_of("confidence", e.confidence, CONFIDENCES)
    _one_of("trust", e.trust, TRUSTS)
    _one_of("status", e.status, STATUSES)
    _check_date("created", e.created)
    _check_date("updated", e.updated)
    _check_date("last_verified", e.last_verified)
    if e.verify is not None and len(e.verify) > MAX_VERIFY:
        raise EntryError(f"verify: at most {MAX_VERIFY} chars, got {len(e.verify)}")
    for rel in e.related:
        split_rel(rel)
    for i, s in enumerate(e.sources):
        what = f"sources[{i}]"
        _check_date(f"{what}.date", s.date)
        if not s.by:
            raise EntryError(f"{what}.by: empty")
        _one_of(f"{what}.trust", s.trust, TRUSTS)
        if len(s.evidence) > MAX_EVIDENCE:
            raise EntryError(f"{what}.evidence: at most {MAX_EVIDENCE} chars, got {len(s.evidence)}")
    if not e.body.strip():
        raise EntryError("body: empty")
    size = len(e.body.encode("utf-8", "replace"))
    if size > body_limit(e.kind):
        raise EntryError(f"body: {size} bytes exceeds the {body_limit(e.kind)} byte limit for kind {e.kind}")


# parsing


def split_frontmatter(text: str) -> tuple[Obj, str]:
    """The YAML mapping between the `---` fences, and the body with its surrounding blank lines removed."""
    if not text.startswith("---\n"):
        raise EntryError("missing frontmatter: the file must start with ---")
    end = text.find(_FENCE, 3)  # 3: the first fence's newline also ends an empty frontmatter
    if end < 0:
        raise EntryError("unterminated frontmatter: no closing ---")
    try:
        meta = data.as_obj(data.load_yaml(text[4 : end + 1]), "frontmatter")
    except EntryError:
        raise
    except ParseError as e:
        raise EntryError(str(e)) from e
    return meta, text[end + len(_FENCE) :].strip("\n")


def _unknown_keys(o: Obj, allowed: tuple[str, ...], what: str) -> None:
    extra = [k for k in o if k not in allowed]
    if extra:
        raise EntryError(f"{what}: unknown keys {', '.join(extra)}")


def _parse_source(item: Json, what: str) -> Source:
    o = data.as_obj(item, what)
    _unknown_keys(o, SOURCE_KEYS, what)
    return Source(
        date=data.get_str(o, "date"),
        by=data.get_str(o, "by"),
        project=data.opt_str(o, "project"),
        trust=data.get_str(o, "trust"),
        submission=data.str_or(o, "submission"),
        evidence=data.str_or(o, "evidence"),
    )


def _from_meta(rel: str, meta: Obj, body: str) -> Entry:
    scope, name = split_rel(rel)
    _unknown_keys(meta, KEYS, "frontmatter")
    if data.get_str(meta, "name") != name:
        raise EntryError(f"name: {meta.get('name')!r} does not match the file name {name!r}")
    if data.get_str(meta, "scope") != scope:
        raise EntryError(f"scope: {meta.get('scope')!r} does not match the directory {scope!r}")
    e = Entry(
        name=name,
        description=data.get_str(meta, "description"),
        kind=data.get_str(meta, "kind"),
        scope=scope,
        tags=tuple(data.str_list(meta, "tags")),
        confidence=data.get_str(meta, "confidence"),
        trust=data.get_str(meta, "trust"),
        status=data.get_str(meta, "status"),
        created=data.get_str(meta, "created"),
        updated=data.get_str(meta, "updated"),
        last_verified=data.get_str(meta, "last_verified"),
        verify=data.opt_str(meta, "verify"),
        related=tuple(data.str_list(meta, "related")),
        sources=tuple(_parse_source(s, f"sources[{i}]") for i, s in enumerate(data.opt_list(meta, "sources"))),
        body=body,
    )
    validate_entry(e)
    return e


def parse_entry(rel: str, text: str) -> Entry:
    """The entry stored at `rel` (`<scope>/<name>.md`); raises EntryError for anything that is not a valid entry."""
    split_rel(rel)
    try:
        meta, body = split_frontmatter(text)
        return _from_meta(rel, meta, body)
    except ParseError as e:  # includes EntryError
        raise EntryError(f"{rel}: {e}") from e


# rendering


def _source_obj(s: Source) -> Obj:
    return {
        "date": s.date,
        "by": s.by,
        "project": s.project,
        "trust": s.trust,
        "submission": s.submission,
        "evidence": s.evidence,
    }


def _sources_json(sources: Iterable[Source]) -> list[Json]:
    return [_source_obj(s) for s in sources]


def render_entry(e: Entry) -> str:
    """The file text; the entry must be valid."""
    try:
        validate_entry(e)
    except EntryError as err:
        raise EntryError(f"{e.scope}/{e.name}: {err}") from err
    meta: Obj = {
        "name": e.name,
        "description": e.description,
        "kind": e.kind,
        "scope": e.scope,
        "tags": data.strs(e.tags),
        "confidence": e.confidence,
        "trust": e.trust,
        "status": e.status,
        "created": e.created,
        "updated": e.updated,
        "last_verified": e.last_verified,
        "verify": e.verify,
        "related": data.strs(e.related),
        "sources": _sources_json(e.sources),
    }
    body = e.body.strip("\n")
    return f"---\n{data.dump_yaml(meta)}---\n\n{body}\n"
