"""The curator's answer: parsing the response document and validating its decisions (S5).

`parse_response` is lenient about what is wrong inside one decision (a wrong type, an unknown key): that decision keeps
the messages in `Decision.errors` and the others stay usable. `validate` adds the checks that need the run (pending ids,
project slugs, mode) and returns the errors per decision key.
"""

import re
from collections.abc import Collection
from dataclasses import dataclass

from . import data
from .data import Json, Obj, ParseError
from .entry import CONFIDENCES, KINDS, MAX_DESCRIPTION, MAX_TAGS, MAX_VERIFY, NAME_RE, EntryError, body_limit, split_rel
from .store import has_section_heading

VERDICTS = ("reject", "create", "merge", "supersede", "playbook", "skill", "dispute", "maintain")
MODES = ("intake", "weekly")
WRITE_STATUSES = ("active", "disputed")
DELETE_REASONS = ("merged", "superseded", "refuted", "evicted", "obsolete")

MAX_REASON = 300
MAX_PRIVATE_SECTION = 80
MAX_PRIVATE_BODY = 16384
MAX_SKILL_DESCRIPTION = 1024
MAX_SKILL_BODY = 16384
MAX_SKILL_SUMMARY = 200

_JSON_BLOCK = re.compile(r"^```json[ \t]*\n(.*?)\n```[ \t]*$", re.MULTILINE | re.DOTALL)
_NAME = re.compile(NAME_RE)

_DECISION_KEYS = ("submission", "verdict", "reason", "ops")
_ENTRY_KEYS = ("description", "kind", "tags", "confidence", "status", "verify", "related")
_OP_KEYS: dict[str, tuple[str, ...]] = {
    "write": ("op", "path", "entry", "body"),
    "delete": ("op", "path", "reason"),
    "verified": ("op", "path"),
    "set_status": ("op", "path", "status"),
    "private": ("op", "org", "section", "body"),
    "skill": ("op", "name", "description", "body", "summary", "sources"),
}


@dataclass(frozen=True)
class EntryFields:
    """What the curator sets of an entry; the runner sets name, scope, dates, trust, sources."""

    description: str
    kind: str
    tags: tuple[str, ...]
    confidence: str
    status: str
    verify: str | None
    related: tuple[str, ...]


@dataclass(frozen=True)
class WriteOp:
    path: str
    entry: EntryFields
    body: str


@dataclass(frozen=True)
class DeleteOp:
    path: str
    reason: str


@dataclass(frozen=True)
class VerifiedOp:
    path: str


@dataclass(frozen=True)
class SetStatusOp:
    path: str
    status: str


@dataclass(frozen=True)
class PrivateOp:
    org: str
    section: str
    body: str


@dataclass(frozen=True)
class SkillOp:
    """A draft of a skill for the user: `ideas.render` makes the file of it."""

    name: str
    description: str
    body: str
    summary: str  # one line: why this skill is worth having
    sources: tuple[str, ...]  # entry paths


type Op = WriteOp | DeleteOp | VerifiedOp | SetStatusOp | PrivateOp | SkillOp


@dataclass(frozen=True)
class Decision:
    submission: str | None
    verdict: str
    reason: str
    ops: tuple[Op, ...]
    errors: tuple[str, ...] = ()  # found while parsing; the ops that could not be parsed are missing from `ops`


@dataclass(frozen=True)
class Response:
    decisions: tuple[Decision, ...]


@dataclass(frozen=True)
class ValidationContext:
    pending_ids: Collection[str]
    project_slugs: Collection[str]
    mode: str  # intake | weekly
    run_id: str = ""  # only names the keys of decisions without a submission


# parsing


def _unknown_keys(o: Obj, allowed: tuple[str, ...], what: str) -> None:
    extra = [k for k in o if k not in allowed]
    if extra:
        raise ParseError(f"{what}: unknown keys {', '.join(extra)}")


def _parse_fields(o: Obj) -> EntryFields:
    _unknown_keys(o, _ENTRY_KEYS, "entry")
    return EntryFields(
        description=data.get_str(o, "description"),
        kind=data.get_str(o, "kind"),
        tags=tuple(data.str_list(o, "tags")),
        confidence=data.get_str(o, "confidence"),
        status=data.get_str(o, "status"),
        verify=data.opt_str(o, "verify"),
        related=tuple(data.str_list(o, "related")),
    )


def _parse_op(o: Obj) -> Op:
    name = data.get_str(o, "op")
    allowed = _OP_KEYS.get(name)
    if allowed is None:
        raise ParseError(f"unknown op {name!r}")
    _unknown_keys(o, allowed, f"op {name}")
    if name == "write":
        return WriteOp(path=data.get_str(o, "path"), entry=_parse_fields(data.get_obj(o, "entry")), body=data.get_str(o, "body"))
    if name == "delete":
        return DeleteOp(path=data.get_str(o, "path"), reason=data.get_str(o, "reason"))
    if name == "verified":
        return VerifiedOp(path=data.get_str(o, "path"))
    if name == "set_status":
        return SetStatusOp(path=data.get_str(o, "path"), status=data.get_str(o, "status"))
    if name == "private":
        return PrivateOp(org=data.get_str(o, "org"), section=data.get_str(o, "section"), body=data.get_str(o, "body"))
    return SkillOp(
        name=data.get_str(o, "name"),
        description=data.get_str(o, "description"),
        body=data.get_str(o, "body"),
        summary=data.get_str(o, "summary"),
        sources=tuple(data.str_list(o, "sources")),
    )


def _parse_decision(o: Obj) -> Decision:
    errors: list[str] = []
    submission: str | None = None
    verdict = ""
    reason = ""
    ops: list[Op] = []
    extra = [k for k in o if k not in _DECISION_KEYS]
    if extra:
        errors.append(f"unknown keys {', '.join(extra)}")
    try:
        submission = data.opt_str(o, "submission")
        verdict = data.get_str(o, "verdict")
        reason = data.str_or(o, "reason")
    except ParseError as e:
        errors.append(str(e))
    try:
        items = data.opt_list(o, "ops")
    except ParseError as e:
        errors.append(str(e))
        items = []
    for i, item in enumerate(items):
        try:
            ops.append(_parse_op(data.as_obj(item, "op")))
        except ParseError as e:
            errors.append(f"ops[{i}]: {e}")
    return Decision(submission=submission, verdict=verdict, reason=reason, ops=tuple(ops), errors=tuple(errors))


def _document(text: str) -> str:
    """The last ```json block, else the whole text."""
    last: re.Match[str] | None = None
    for m in _JSON_BLOCK.finditer(text):
        last = m
    block = None if last is None else data.group(last, 1)
    return text if block is None else block


def parse_response(text: str) -> Response:
    """The response document of the curator; raises ParseError when there is none."""
    doc = _document(text).strip()
    if not doc:
        raise ParseError("empty response")
    root = data.as_obj(data.loads(doc), "response")
    _unknown_keys(root, ("decisions",), "response")
    return Response(
        decisions=tuple(_parse_decision(data.as_obj(d, f"decisions[{i}]")) for i, d in enumerate(data.get_list(root, "decisions")))
    )


# the decision as JSON, in the format of the response (`--dry-run` shows it)


def _fields_obj(f: EntryFields) -> Obj:
    return {
        "description": f.description,
        "kind": f.kind,
        "tags": data.strs(f.tags),
        "confidence": f.confidence,
        "status": f.status,
        "verify": f.verify,
        "related": data.strs(f.related),
    }


def op_obj(op: Op) -> Obj:
    """An op as the response document spells it."""
    if isinstance(op, WriteOp):
        return {"op": "write", "path": op.path, "entry": _fields_obj(op.entry), "body": op.body}
    if isinstance(op, DeleteOp):
        return {"op": "delete", "path": op.path, "reason": op.reason}
    if isinstance(op, VerifiedOp):
        return {"op": "verified", "path": op.path}
    if isinstance(op, SetStatusOp):
        return {"op": "set_status", "path": op.path, "status": op.status}
    if isinstance(op, PrivateOp):
        return {"op": "private", "org": op.org, "section": op.section, "body": op.body}
    return {
        "op": "skill",
        "name": op.name,
        "description": op.description,
        "body": op.body,
        "summary": op.summary,
        "sources": data.strs(op.sources),
    }


def decision_obj(d: Decision) -> Obj:
    ops: list[Json] = [op_obj(op) for op in d.ops]
    return {"submission": d.submission, "verdict": d.verdict, "reason": d.reason, "ops": ops}


# validation


def _size(text: str) -> int:
    return len(text.encode("utf-8", "replace"))


def _single_line(text: str) -> bool:
    return "\n" not in text and "\r" not in text


def _path_error(rel: str, slugs: Collection[str]) -> str | None:
    """Whether `rel` is an entry path; facts need an existing project."""
    try:
        scope, _ = split_rel(rel)
    except EntryError as e:
        return str(e)
    parts = scope.split("/")
    if parts[0] == "projects" and parts[1] not in slugs:
        return f"{rel!r}: unknown project {parts[1]!r}"
    return None


def _paths_errors(what: str, paths: Collection[str], slugs: Collection[str]) -> list[str]:
    errors: list[str] = []
    for rel in paths:
        err = _path_error(rel, slugs)
        if err is not None:
            errors.append(f"{what}: {err}")
    return errors


def _write_errors(op: WriteOp, slugs: Collection[str]) -> list[str]:
    errors = _paths_errors("path", [op.path], slugs)
    f = op.entry
    if not 1 <= len(f.description) <= MAX_DESCRIPTION:
        errors.append(f"description: must be 1..{MAX_DESCRIPTION} chars, got {len(f.description)}")
    if not _single_line(f.description):
        errors.append("description: must be a single line")
    if f.kind not in KINDS:
        errors.append(f"kind: {f.kind!r} is not one of {', '.join(KINDS)}")
    if len(f.tags) > MAX_TAGS:
        errors.append(f"tags: at most {MAX_TAGS}, got {len(f.tags)}")
    for tag in f.tags:
        if _NAME.fullmatch(tag) is None:
            errors.append(f"tags: invalid tag {tag!r}")
    if f.confidence not in CONFIDENCES:
        errors.append(f"confidence: {f.confidence!r} is not one of {', '.join(CONFIDENCES)}")
    if f.status not in WRITE_STATUSES:
        errors.append(f"status: {f.status!r} is not one of {', '.join(WRITE_STATUSES)}")
    if f.verify is not None and len(f.verify) > MAX_VERIFY:
        errors.append(f"verify: at most {MAX_VERIFY} chars, got {len(f.verify)}")
    errors.extend(_paths_errors("related", f.related, slugs))
    if not op.body.strip():
        errors.append("body: empty")
    elif f.kind in KINDS and _size(op.body) > body_limit(f.kind):
        errors.append(f"body: {_size(op.body)} bytes exceeds the {body_limit(f.kind)} byte limit for kind {f.kind}")
    return errors


def _private_errors(op: PrivateOp) -> list[str]:
    errors: list[str] = []
    if _NAME.fullmatch(op.org) is None:
        errors.append(f"org: invalid org {op.org!r}")
    if not op.section.strip() or len(op.section) > MAX_PRIVATE_SECTION:
        errors.append(f"section: must be 1..{MAX_PRIVATE_SECTION} chars, got {len(op.section)}")
    if not _single_line(op.section):
        errors.append("section: must be a single line")
    if not op.body.strip():
        errors.append("body: empty")
    elif _size(op.body) > MAX_PRIVATE_BODY:
        errors.append(f"body: {_size(op.body)} bytes exceeds the {MAX_PRIVATE_BODY} byte limit")
    if has_section_heading(op.body):
        errors.append("body: no line may start with '## ' (it would start another section)")
    return errors


def _skill_errors(op: SkillOp, slugs: Collection[str]) -> list[str]:
    errors: list[str] = []
    if _NAME.fullmatch(op.name) is None:
        errors.append(f"name: invalid skill name {op.name!r}")
    if not op.description.strip() or len(op.description) > MAX_SKILL_DESCRIPTION:
        errors.append(f"description: must be 1..{MAX_SKILL_DESCRIPTION} chars, got {len(op.description)}")
    if not _single_line(op.description):
        errors.append("description: must be a single line")
    if not op.body.strip():
        errors.append("body: empty")
    else:
        if _size(op.body) > MAX_SKILL_BODY:
            errors.append(f"body: {_size(op.body)} bytes exceeds the {MAX_SKILL_BODY} byte limit")
        if op.body.lstrip().startswith("---"):
            errors.append("body: must not start with ---")
    if not op.summary.strip() or len(op.summary) > MAX_SKILL_SUMMARY:
        errors.append(f"summary: must be 1..{MAX_SKILL_SUMMARY} chars, got {len(op.summary)}")
    if not _single_line(op.summary):
        errors.append("summary: must be a single line")
    errors.extend(_paths_errors("sources", op.sources, slugs))
    return errors


def _op_errors(op: Op, slugs: Collection[str]) -> list[str]:
    if isinstance(op, WriteOp):
        return _write_errors(op, slugs)
    if isinstance(op, DeleteOp):
        errors = _paths_errors("path", [op.path], slugs)
        if op.reason not in DELETE_REASONS:
            errors.append(f"reason: {op.reason!r} is not one of {', '.join(DELETE_REASONS)}")
        return errors
    if isinstance(op, VerifiedOp):
        return _paths_errors("path", [op.path], slugs)
    if isinstance(op, SetStatusOp):
        errors = _paths_errors("path", [op.path], slugs)
        if op.status not in WRITE_STATUSES:
            errors.append(f"status: {op.status!r} is not one of {', '.join(WRITE_STATUSES)}")
        return errors
    if isinstance(op, PrivateOp):
        return _private_errors(op)
    return _skill_errors(op, slugs)


def _intake_errors(d: Decision, ctx: ValidationContext, seen: set[str]) -> list[str]:
    """The checks on the submission of a decision; `seen` holds the ids decided before it."""
    if d.submission is None:
        if ctx.mode != "weekly":
            return ["submission: missing"]
        if d.verdict not in ("maintain", "skill"):
            return [f"submission: missing, only maintain and skill decisions have none (verdict {d.verdict!r})"]
        return []
    errors: list[str] = []
    if d.verdict == "maintain":
        errors.append("maintain: must have no submission")
    if d.submission not in ctx.pending_ids:
        errors.append(f"submission: {d.submission!r} is not pending")
    elif d.submission in seen:
        errors.append(f"submission: {d.submission!r} is decided more than once")
    return errors


def _reason_errors(reason: str) -> list[str]:
    """The reason goes into a commit message and the decision log: one short line, nothing git or a terminal would trip on."""
    errors: list[str] = []
    if len(reason) > MAX_REASON:
        errors.append(f"reason: at most {MAX_REASON} chars, got {len(reason)}")
    if any(c < " " or c == "\x7f" for c in reason):
        errors.append("reason: must be one line without control characters")
    return errors


def _decision_errors(d: Decision, ctx: ValidationContext, seen: set[str]) -> list[str]:
    errors = list(d.errors)
    if d.verdict not in VERDICTS:
        errors.append(f"verdict: {d.verdict!r} is not one of {', '.join(VERDICTS)}")
    if d.verdict == "maintain" and ctx.mode != "weekly":
        errors.append("maintain: only valid in weekly mode")
    errors.extend(_intake_errors(d, ctx, seen))
    errors.extend(_reason_errors(d.reason))
    if d.verdict == "reject" and d.ops:
        errors.append("reject: must have no ops")
    if d.verdict in VERDICTS and d.verdict != "reject" and not d.ops:
        errors.append(f"{d.verdict}: must have at least one op")
    for i, op in enumerate(d.ops):
        errors.extend(f"ops[{i}]: {e}" for e in _op_errors(op, ctx.project_slugs))
    return errors


def decision_keys(resp: Response, run_id: str = "") -> list[str]:
    """One key per decision, in order: its submission id; `<id>#<n>` for the n-th decision of the same id; `m-<run>-<n>`
    (or `m-<n>` without a run id) for the n-th decision without a submission."""
    counts: dict[str, int] = {}
    unnamed = 0
    keys: list[str] = []
    for d in resp.decisions:
        if d.submission is None:
            unnamed += 1
            keys.append(f"m-{run_id}-{unnamed}" if run_id else f"m-{unnamed}")
            continue
        n = counts.get(d.submission, 0) + 1
        counts[d.submission] = n
        keys.append(d.submission if n == 1 else f"{d.submission}#{n}")
    return keys


def validate(resp: Response, ctx: ValidationContext) -> dict[str, list[str]]:
    """The errors per decision key (see `decision_keys`); only decisions with errors are present.

    A pending id no decision names is reported under its own id as `undecided`.
    """
    problems: dict[str, list[str]] = {}
    seen: set[str] = set()
    for key, d in zip(decision_keys(resp, ctx.run_id), resp.decisions, strict=True):
        errors = _decision_errors(d, ctx, seen)
        if errors:
            problems[key] = errors
        if d.submission is not None:
            seen.add(d.submission)
    for pending in sorted(ctx.pending_ids):
        if pending not in seen:
            problems[pending] = ["undecided"]
    return problems
