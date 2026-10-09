"""Applying a validated decision to the store: preparing, writing, committing and recovering (S6).

A decision is atomic. Every new file is computed and scanned in memory first; only then is `applying.json` written, the
files are changed and the commit is made. A crash in between leaves the intent file, and `recover` puts the paths back.
"""

import datetime
import logging
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field, replace
from pathlib import Path

from . import data, ideas, rejected, secrets
from .config import ensure_private, skills_dir, state_dir
from .data import Json, Obj
from .entry import MAX_EVIDENCE, Entry, EntryError, Source, max_trust, min_trust, render_entry, split_rel
from .gitops import Git
from .ops import Decision, DeleteOp, PrivateOp, SetStatusOp, VerifiedOp, WriteOp
from .records import Record
from .scopes import ScopesConfig, scopes_for_cwd
from .store import Store, atomic_write, has_section_heading

log = logging.getLogger("knowledge")

INTENT_FILE = "applying.json"
INTENT_MODE = 0o600
PRIVATE_BACKUP_DIR = "private-backup"  # in the state dir: what a private write replaced
PRIVATE_BACKUP_MODE = 0o600
MAX_SOURCES = 10  # sources an entry keeps: the most recent


class ApplyError(Exception):
    """The decision cannot be applied (a missing entry, a secret, an invalid entry); nothing was written."""


@dataclass(frozen=True)
class Applied:
    paths: tuple[str, ...]  # what the commit covers
    commit: str | None  # None if nothing changed or there was nothing to commit
    notes: tuple[str, ...]


def _no_records() -> Mapping[str, Record]:
    return {}


@dataclass(frozen=True)
class ApplyContext:
    store: Store
    git: Git
    scopes: ScopesConfig
    run_id: str
    records: Mapping[str, Record] = field(default_factory=_no_records)  # the submissions of the run, by id
    today: datetime.date | None = None
    # the trust of the records of the run (a run has records of one trust only; None: the run has none). What an entry
    # written by the run may not exceed, and what lets a decision without a record (weekly maintenance) be refused
    # `private` ops from an untrusted batch.
    batch_trust: str | None = None


def _today(ctx: ApplyContext) -> datetime.date:
    return ctx.today or datetime.datetime.now(datetime.UTC).date()


def _intent_path() -> Path:
    return state_dir() / INTENT_FILE


# preparing


@dataclass
class _Plan:
    entries: dict[str, Entry | None]  # the final entry of every path an op touched; None = deleted
    deleted: dict[str, str]  # path -> the note of a refuted or obsolete entry, for rejected.md
    written: set[str]  # paths of write ops: their content comes from the curator and is scanned
    private: list[PrivateOp]
    ideas: dict[str, str]  # rel -> the text of a skill idea, for the files of skill-ideas/
    notes: list[str]


def _current(ctx: ApplyContext, plan: _Plan, rel: str) -> Entry | None:
    if rel in plan.entries:
        return plan.entries[rel]
    try:
        return ctx.store.read(rel)
    except FileNotFoundError:
        return None
    except (EntryError, OSError) as e:
        raise ApplyError(f"{rel}: cannot read the entry: {e}") from e


def _must_exist(ctx: ApplyContext, plan: _Plan, rel: str, what: str) -> Entry:
    entry = _current(ctx, plan, rel)
    if entry is None:
        raise ApplyError(f"{what} {rel}: no such entry")
    return entry


def _project_slug(ctx: ApplyContext, cwd: str | None) -> str | None:
    """The project whose repo contains the cwd, if it has an `overview.md`."""
    if cwd is None:
        return None
    store = ctx.store
    for scope in scopes_for_cwd(Path(cwd), ctx.scopes, store.projects_index(), store.project_slugs()):
        if scope.startswith("projects/"):
            return scope.split("/")[1]
    return None


def _capped(ctx: ApplyContext, trust: str) -> str:
    """`trust`, but no higher than the trust of the records of the run: what a run writes from untrusted records is not
    more trusted than they are, even if it merges into an entry of an agent."""
    return trust if ctx.batch_trust is None else min_trust([trust, ctx.batch_trust])


def _source(ctx: ApplyContext, record: Record, today: datetime.date) -> Source:
    return Source(
        date=today.isoformat(),
        by=record.origin.agent or record.origin.via,
        project=_project_slug(ctx, record.origin.cwd),
        trust=record.trust,
        submission=record.id,
        evidence=(record.evidence or "")[:MAX_EVIDENCE],
    )


def _written(ctx: ApplyContext, op: WriteOp, existing: Entry | None, source: Source | None, today: str) -> Entry:
    """The entry a write op makes: the curator's fields, the runner's dates, trust and sources.

    The trust is capped at that of the records of the run (and so is that of a maintenance write).
    """
    scope, name = split_rel(op.path)
    sources = (existing.sources if existing is not None else ()) + ((source,) if source is not None else ())
    if source is not None:
        trust = max_trust([s.trust for s in sources] + ([existing.trust] if existing is not None else []))
    elif existing is not None:
        trust = existing.trust  # a maintenance write
    else:
        trust = "agent"
    trust = _capped(ctx, trust)
    sources = sources[-MAX_SOURCES:]  # the most recent: the front matter must not grow for ever
    f = op.entry
    return Entry(
        name=name,
        description=f.description,
        kind=f.kind,
        scope=scope,
        tags=f.tags,
        confidence=f.confidence,
        trust=trust,
        status=f.status,
        created=existing.created if existing is not None else today,
        updated=today,
        last_verified=today,
        verify=f.verify,
        related=f.related,
        sources=sources,
        body=op.body,
    )


def _guard_user_entry(ctx: ApplyContext, record: Record | None, rel: str, entry: Entry | None) -> None:
    """An entry of the user is rewritten or deleted only for a submission of the user (a run curates records of one trust,
    so the model saw nothing less trusted with it).

    What an agent may do to one is `verified` and `set_status` (a dispute); the user has `knowledge drop` for the rest.
    """
    if entry is None or entry.trust != "user":
        return
    if record is not None and record.trust == "user":
        return
    raise ApplyError(
        f"{rel}: an entry of the user; only a submission of the user may rewrite or delete it (`knowledge drop` for you)"
    )


def _guard_private(ctx: ApplyContext, record: Record | None, op: PrivateOp) -> None:
    """A private note is written for a submission that is not untrusted, in a batch that is not either; one that already
    holds text under the section is replaced only for a submission of the user.

    `private/` is gitignored, so `knowledge undo` cannot revert a write there (the backup in the state dir can).
    """
    if (record is not None and record.trust == "untrusted") or ctx.batch_trust == "untrusted":
        raise ApplyError(f"private {op.org}: an untrusted submission may not write a private note")
    if (record is None or record.trust != "user") and ctx.store.private_section(op.org, op.section):
        raise ApplyError(
            f"private {op.org}: the section {op.section!r} is filled; only a submission of the user may replace it"
        )


def _prepare(ctx: ApplyContext, decision: Decision, record: Record | None) -> _Plan:
    """Every new file content, computed and checked in memory; raises ApplyError and writes nothing."""
    today = _today(ctx).isoformat()
    plan = _Plan({}, {}, set(), [], {}, [])
    source = None if record is None else _source(ctx, record, _today(ctx))
    for op in decision.ops:
        if isinstance(op, WriteOp):
            scope, _ = split_rel(op.path)
            parts = scope.split("/")
            if parts[0] == "projects" and parts[1] not in ctx.store.project_slugs():
                raise ApplyError(f"write {op.path}: project {parts[1]!r} has no overview.md")
            existing = _current(ctx, plan, op.path)
            _guard_user_entry(ctx, record, op.path, existing)
            plan.entries[op.path] = _written(ctx, op, existing, source, today)
            plan.written.add(op.path)
        elif isinstance(op, DeleteOp):
            entry = _must_exist(ctx, plan, op.path, "delete")
            _guard_user_entry(ctx, record, op.path, entry)
            plan.entries[op.path] = None
            if op.reason in rejected.NOTED_REASONS:
                plan.deleted[op.path] = f"{op.path} ({op.reason}): {entry.description}"
        elif isinstance(op, VerifiedOp):
            entry = _must_exist(ctx, plan, op.path, "verified")
            plan.entries[op.path] = replace(entry, last_verified=today, updated=today)
        elif isinstance(op, SetStatusOp):
            entry = _must_exist(ctx, plan, op.path, "set_status")
            plan.entries[op.path] = replace(entry, status=op.status, updated=today)
        elif isinstance(op, PrivateOp):
            if has_section_heading(op.body):
                raise ApplyError(f"private {op.org}: the body has a line that starts with '## '")
            _guard_private(ctx, record, op)
            plan.private.append(op)
        else:
            exists = (skills_dir() / op.name / "SKILL.md").is_file()
            plan.ideas[ideas.rel(op.name)] = ideas.render(op, _today(ctx), exists)
    _check_entries(ctx, plan)
    return plan


def _refuse_secrets(what: str, text: str) -> None:
    """A finding of any severity refuses the text; the message carries the masked excerpts only."""
    findings = secrets.scan(text)
    if findings:
        found = ", ".join(f"{f.kind} {f.excerpt}" for f in findings)
        raise ApplyError(f"{what}: looks like it holds a secret or personal data ({found})")


def _repeats_private(body: str, guarded: set[str]) -> bool:
    return any(line.strip() in guarded for line in body.splitlines())


def _check_entries(ctx: ApplyContext, plan: _Plan) -> None:
    """Every entry must render; what the curator wrote must carry no secret, personal data or line of a private note.

    The whole rendered file is scanned, frontmatter included (`verify`, the evidence and `by` of the sources). The text
    of a skill idea is scanned the same way.
    """
    guarded = ctx.store.private_lines() if plan.written or plan.ideas else set[str]()
    for rel, entry in plan.entries.items():
        if entry is None:
            continue
        try:
            text = render_entry(entry)
        except EntryError as e:
            raise ApplyError(str(e)) from e
        if rel not in plan.written:
            continue
        _refuse_secrets(rel, text)
        if _repeats_private(entry.body, guarded):
            raise ApplyError(f"{rel}: the body repeats a line of a private note")
    for rel, text in plan.ideas.items():
        _refuse_secrets(rel, text)
        if _repeats_private(text, guarded):
            raise ApplyError(f"{rel}: the idea repeats a line of a private note")


# writing


def _file_paths(plan: _Plan) -> list[str]:
    return [*plan.entries, *plan.ideas]


def _write_intent(key: str, paths: list[str], created: list[str]) -> None:
    """`created`: the paths that did not exist before; only those are deleted by `recover`."""
    ensure_private(state_dir())
    listed: list[Json] = [p for p in paths]
    made: list[Json] = [p for p in created]
    obj: Obj = {"key": key, "paths": listed, "created": made}
    atomic_write(_intent_path(), data.dumps(obj) + "\n", INTENT_MODE)


def _rejected_notes(plan: _Plan) -> list[str]:
    """The notes of the refuted and obsolete entries the decision leaves deleted; written once the commit is made."""
    return [text for rel, text in plan.deleted.items() if plan.entries.get(rel) is None]


def _backup_private(ctx: ApplyContext, org: str) -> None:
    """What `private/<org>.md` holds now, copied to the state dir (mode 0600) before a write replaces a section of it."""
    text = ctx.store.private_text(org)
    if text is None:
        return
    directory = ensure_private(state_dir() / PRIVATE_BACKUP_DIR)
    stamp = f"{datetime.datetime.now(datetime.UTC):%Y%m%dT%H%M%S%fZ}"
    atomic_write(directory / f"{org}.{stamp}.md", text, PRIVATE_BACKUP_MODE)


def _write_files(ctx: ApplyContext, plan: _Plan) -> None:
    for entry in plan.entries.values():
        if entry is not None:
            ctx.store.write(entry)
    for rel, entry in plan.entries.items():
        if entry is not None:
            continue
        try:
            ctx.store.delete(rel)
        except FileNotFoundError:  # written and deleted by the same decision
            pass
    for rel, text in plan.ideas.items():
        path = ctx.git.repo / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(path, text, ideas.FILE_MODE)
    for op in plan.private:
        _backup_private(ctx, op.org)
        ctx.store.private_write(op.org, op.section, op.body)
        plan.notes.append(f"private note written to private/{op.org}.md ({op.section})")


def _subject(verdict: str, paths: list[str]) -> str:
    more = f" +{len(paths) - 1}" if len(paths) > 1 else ""
    if all(p.startswith(f"{ideas.DIR}/") for p in paths):
        return f"knowledge: skill idea {Path(paths[0]).stem}{more}"
    return f"knowledge: {verdict} {paths[0]}{more}"


def _trailers(ctx: ApplyContext, decision: Decision, record: Record | None) -> dict[str, str]:
    if record is None:
        trust, origin = "agent", "curator/-"
    else:
        trust, origin = record.trust, f"{record.origin.via}/{record.origin.agent or '-'}"
    return {"Submission": decision.submission or "-", "Run": ctx.run_id, "Trust": trust, "Origin": origin}


def apply_decision(ctx: ApplyContext, decision: Decision, *, key: str | None = None) -> Applied:
    """Write, delete and commit what the decision says; `key` names it in `applying.json` (default: its submission).

    Raises ApplyError, with nothing written, if the decision cannot be applied. Any other exception (a failed commit,
    a crash) leaves `applying.json` behind for `recover`.
    """
    record: Record | None = None
    if decision.submission is not None:
        record = ctx.records.get(decision.submission)
        if record is None:
            raise ApplyError(f"submission {decision.submission}: no record of it in this run")
    _refuse_secrets("reason", decision.reason)  # it goes into the commit message
    try:
        plan = _prepare(ctx, decision, record)
    except EntryError as e:  # a path that is not an entry path
        raise ApplyError(str(e)) from e
    paths = _file_paths(plan)
    if paths:
        created = [p for p in paths if not (ctx.git.repo / p).exists(follow_symlinks=False)]
        _write_intent(key or decision.submission or f"m-{ctx.run_id}", paths, created)
    _write_files(ctx, plan)
    commit: str | None = None
    if paths:
        commit = ctx.git.commit(
            paths, _subject(decision.verdict, paths), body=decision.reason, trailers=_trailers(ctx, decision, record)
        )
    for text in _rejected_notes(plan):  # only now: a decision whose commit failed is made again
        rejected.note(text, _today(ctx))
    _intent_path().unlink(missing_ok=True)
    return Applied(tuple(paths), commit, tuple(plan.notes))


# recovery


def begin_intent(git: Git, key: str, paths: Sequence[str]) -> None:
    """For a change made outside `apply_decision` (retention): `recover` puts `paths` back if it is interrupted."""
    listed = list(paths)
    created = [p for p in listed if not (git.repo / p).exists(follow_symlinks=False)]
    _write_intent(key, listed, created)


def end_intent() -> None:
    _intent_path().unlink(missing_ok=True)


def recover(git: Git) -> str | None:
    """Undo an interrupted `apply_decision`: put its paths back to HEAD; the key of the decision, if there was one.

    Only the paths the intent lists as `created` (they did not exist before) are deleted; an intent without that
    field (an older one) deletes nothing.
    """
    path = _intent_path()
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    intent = data.as_obj(data.loads(text), INTENT_FILE)
    key = data.get_str(intent, "key")
    paths = data.str_list(intent, "paths")
    git.restore(paths, created=data.str_list(intent, "created"))
    path.unlink(missing_ok=True)
    log.warning("decision %s was interrupted: put back %s", key, ", ".join(paths) or "nothing")
    return key
