"""One curator run (S8): read the pending submissions, ask the model once, apply its decisions, remove their files.

A run reads the pending files of the inbox (up to the byte cap) and makes ONE model call. The order of the effects is what
makes a crash harmless: the file of a record is removed last, after its decision is applied and logged, so an interrupted
run is simply run again. What the next run does about what the interrupted one left:
- a half-written decision: `apply.recover` puts its paths back to HEAD, and the record is decided again;
- a commit without its decision line: the `Submission` trailer says it is done, and the line is written then;
- a decision line without the removed file: the id is in the decision log, so the file is removed without a second effect.
Either way a submission has one effect.

Every valid decision that is not a `reject` is applied. A call gets the records of ONE trust (the user's if any are pending,
else the trust of the oldest record): the model must not see a record of the user beside one of an agent, whose text could
steer it into rewriting what the user wrote. The records of the other trusts stay in the inbox for the next run (the
summary counts them as `waiting`, and `run_pending` goes on while there are some). `apply` refuses to let anything but a
submission of the user rewrite or delete an entry of the user. A failed call counts as an attempt of every record of the
batch: their files are rewritten with one more attempt like those of an invalid decision, and one that is out of attempts
ends `failed`. A record that is retried because its decision was refused carries the errors (`Record.last_errors`), which
the model sees in the next call.

A skill op is written as a draft to `skill-ideas/<name>.md` in the memory repo (`ideas.py`), in the commit of its decision;
the run never changes a skill. The model may read the skills of the Claude config (`config.skills_dir()`), and sees the ideas that wait in
`skill-ideas/` so that it does not draft them again.

Retention (`retention.py`) runs twice, after the recovery and after the decisions: what lost its place to a
budget is dropped, in one commit. A weekly run with no submissions asks the model only if something needs it.
"""

import datetime
import logging
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, replace
from pathlib import Path

from . import config, data, decisions, emit, ideas, index, locks, ops, prompt, rejected, retention
from .apply import ApplyContext, ApplyError, apply_decision, begin_intent, end_intent, recover
from .data import Json, Obj, ParseError
from .entry import TRUSTS, Entry
from .gitops import Git, GitError
from .inbox import Inbox
from .llm import ClaudeCli, Llm, LlmError
from .locks import FileLock, LockTimeout
from .notify import notify
from .prompt import StaleLine
from .records import Record
from .scopes import ScopesConfig, load_scopes
from .store import Store

log = logging.getLogger("knowledge")

LOCK_WAIT = 600.0  # seconds a run waits for another one to finish (without --if-idle)
MAX_RETRIES = 2  # how often a record that came back invalid or undecided, or whose call failed, is put back in the inbox
MAX_LAST_ERRORS = 5  # errors of a refused decision a record carries to the next call
MAX_ERROR_CHARS = 500  # of each of them
MAX_RUNS = len(TRUSTS)  # `run_pending`: a run for the records of each trust
MAX_STALE_REPOS = 5  # repos the model may read to re-check stale entries (each is an --add-dir)
CHANGED_DAYS = 7  # a weekly run looks at the store again if an entry changed this lately
ENTRY_DIRS = ("global", "lang", "topic", "org")  # and projects/<slug>/facts
USER_OVERFLOW_LISTED = 10  # entries per scope the overflow notification names

SKIPPED_BUSY = "busy"
SKIPPED_IDLE = "idle"  # nothing needed the model
SKIPPED_LLM = "llm-failure"
SKIPPED_RESPONSE = "bad-response"
FAILURES = (SKIPPED_LLM, SKIPPED_RESPONSE)  # `knowledge curate` exits 1 for these

_NOT_A_DECISION = "-"  # the verdict of a line that records a fact about a submission, not a decision of the model


@dataclass(frozen=True)
class RunSummary:
    run: str
    mode: str
    records: int = 0  # submissions read from the inbox
    applied: int = 0
    rejected: int = 0
    invalid: int = 0  # decisions that were invalid or applied with an error; their records are retried
    failed: int = 0  # records given up on after MAX_RETRIES
    waiting: int = 0  # records of another trust that this run left in the inbox for the next one
    skipped: str | None = None
    text: str | None = None  # what the command prints instead of the summary (--print-prompt, --dry-run)


def summary_obj(s: RunSummary) -> Obj:
    return {
        "run": s.run,
        "mode": s.mode,
        "records": s.records,
        "applied": s.applied,
        "rejected": s.rejected,
        "invalid": s.invalid,
        "failed": s.failed,
        "waiting": s.waiting,
        "skipped": s.skipped,
    }


def make_llm() -> Llm:
    """The model of a run; replaced in the tests, which never run the real claude."""
    return ClaudeCli()


@dataclass(frozen=True)
class _Failed:
    """A call that gave nothing to apply: why (a SKIPPED_ reason) and what the model or its answer was wrong with."""

    reason: str
    error: str


@dataclass(frozen=True)
class _Stale:
    """The stale entries a weekly run asks the model to re-check, and the repos it may read to do so."""

    lines: tuple[StaleLine, ...] = ()
    repos: tuple[Path, ...] = ()


def _stamp(at: datetime.datetime) -> str:
    return f"{at:%Y-%m-%dT%H:%M:%SZ}"


def _is_repo(path: Path) -> bool:
    """A repo the model may read (an --add-dir): a git or jj checkout, and not the home directory or above it.

    The INDEX is edited by the architect, an agent: a row pointing at `~` or `/` would hand the model the whole home.
    """
    if not (path / ".git").exists() and not (path / ".jj").exists():
        return False
    home = Path.home().resolve()
    here = path.resolve()
    return here != home and here not in home.parents


def _one_trust(records: Sequence[Record]) -> list[Record]:
    """The records of one trust: the user's if there are any, else the trust of the oldest (`records` come oldest first)."""
    if not records:
        return []
    trust = "user" if any(r.trust == "user" for r in records) else records[0].trust
    return [r for r in records if r.trust == trust]


def _last_errors(errors: Sequence[str]) -> tuple[str, ...]:
    """What a retried record carries to the next call: a few errors, each cut short (a crash may carry a long text)."""
    return tuple(e[:MAX_ERROR_CHARS] for e in errors[:MAX_LAST_ERRORS])


def _listed(rels: Sequence[str]) -> list[str]:
    """The `knowledge drop` lines of the first USER_OVERFLOW_LISTED paths, and how many more there are."""
    lines = [f"  knowledge drop {rel}" for rel in rels[:USER_OVERFLOW_LISTED]]
    if len(rels) > USER_OVERFLOW_LISTED:
        lines.append(f"  ... and {len(rels) - USER_OVERFLOW_LISTED} more")
    return lines


def _user_text(overflow: Mapping[str, Sequence[str]]) -> str:
    """The notification about the user's own entries, which the curator never drops by itself: the scopes that are over
    budget with nothing else left to drop."""
    lines = ["Over budget, and only your own entries are left to drop; the curator never drops those. Drop some with:"]
    for scope, rels in overflow.items():
        lines.append(f"{scope}:")
        lines.extend(_listed(rels))
    return "\n".join(lines)


class _Run:
    """The state of one run; `execute` is the run itself."""

    def __init__(self, weekly: bool, read_only: bool, dry_run: bool, now: datetime.datetime) -> None:
        self.mode = "weekly" if weekly else "intake"
        self.read_only = read_only  # --dry-run and --print-prompt: no writes, no commits, no notifications
        self.dry_run = dry_run
        self.now = now
        self.run_id = f"r-{now:%Y%m%dT%H%M%SZ}"
        self.skills_dir = config.skills_dir()  # the model may read it, if it exists
        self.memory = config.memory_dir()
        self.tun = config.tunables()
        self.git = Git(self.memory, locks.memory_lock())
        self.inbox = Inbox()
        self.decided = decisions.Decisions()
        self.counts: dict[str, int] = {}
        self.seen = 0
        self.waiting = 0  # records of another trust left for the next run
        self.batch_trust: str | None = None  # the trust of the records the model is shown; None without any

    # the run

    def execute(self, llm: Llm | None, print_prompt: bool) -> RunSummary:
        self.git.ensure_repo()
        if not self.read_only:
            recover(self.git)
        if not self.read_only:
            self._maintain()  # the prompt shows the store as retention leaves it
        pending = self.inbox.pending(self.tun.max_batch_bytes, set_aside=not self.read_only)
        self.seen = len(pending)
        candidates = self._gate(self._open(pending))
        fresh = _one_trust(candidates)  # the others wait in the inbox for the next run
        self.waiting = 0 if self.read_only else len(candidates) - len(fresh)
        self.batch_trust = fresh[0].trust if fresh else None
        store = Store(self.memory)
        scopes = load_scopes(self.memory)
        entries = store.entries()
        sizes = index.file_sizes(store, entries)
        weekly = self.mode == "weekly"
        stale = self._stale(store, entries) if weekly else _Stale()
        if not (fresh or print_prompt or (weekly and entries and self._weekly_work(entries, scopes, sizes, stale))):
            return self._finish(SKIPPED_IDLE)
        system, message = self._prompts(store, scopes, fresh, entries, sizes, stale)
        if print_prompt:
            return self.summary(text=f"=== system prompt ===\n{system}\n=== message ===\n{message}")
        skills_dirs = [self.skills_dir] if self.skills_dir.is_dir() else []
        response = self._ask(llm or make_llm(), system, message, [self.memory, *skills_dirs, *stale.repos])
        if isinstance(response, _Failed):
            if self.read_only:
                return self.summary(response.reason)
            for rec in fresh:
                self._retry(rec, rec.id, _NOT_A_DECISION, "the curator call failed", [response.error])
            return self._finish(response.reason)
        vctx = ops.ValidationContext(
            pending_ids=[r.id for r in fresh], project_slugs=store.project_slugs(), mode=self.mode, run_id=self.run_id
        )
        problems = ops.validate(response, vctx)
        keys = ops.decision_keys(response, self.run_id)
        by_id = {r.id: r for r in fresh}
        if self.dry_run:
            return self.summary(text=self._preview(response, keys, problems, by_id))
        ctx = ApplyContext(
            store=store,
            git=self.git,
            scopes=scopes,
            run_id=self.run_id,
            records=by_id,
            today=self.now.date(),
            batch_trust=self.batch_trust,
        )
        self._decide_all(ctx, response, keys, problems, fresh)
        self._maintain()  # the new entries may have put a scope over its budget; before the index is rewritten
        return self._finish()

    # what to curate

    def _open(self, records: Sequence[Record]) -> list[Record]:
        """The records nobody decided yet: the decision log and the commit trailers know the others.

        The file of a record that is decided already is a leftover of a run that died before removing it.
        """
        done = self.decided.decided_ids()
        committed = self.git.trailer_values("Submission")
        fresh: list[Record] = []
        for rec in records:
            if rec.id in done:
                log.info("submission %s is decided already", rec.id)
                if not self.read_only:
                    self.inbox.remove(rec.id)
            elif rec.id in committed:
                self._committed(rec)
            else:
                fresh.append(rec)
        return fresh

    def _committed(self, rec: Record) -> None:
        """A commit of a previous run carries this id but its decision was never logged: log it now."""
        log.info("submission %s is committed already", rec.id)
        if self.read_only:
            return
        shas = self.git.commits_with_trailer("Submission", rec.id)
        self._note(
            rec.id, rec.id, _NOT_A_DECISION, "committed by an earlier run", "applied",
            commit=shas[0] if shas else None,
            notes=("found by its commit trailer; the run was interrupted before the decision was logged",),
        )  # fmt: skip

    def _gate(self, records: Sequence[Record]) -> list[Record]:
        """A hard secret in a submission is rejected here: the model never sees it."""
        kept: list[Record] = []
        for rec in records:
            kind = emit.hard_secret(rec)
            if kind is None:
                kept.append(rec)
                continue
            log.warning("rejecting submission %s: looks like a secret (%s)", rec.id, kind)
            if not self.read_only:
                self._note(rec.id, rec.id, "reject", f"hard secret ({kind})", "rejected")
        return kept

    def _weekly_work(
        self, entries: Sequence[Entry], scopes: ScopesConfig, sizes: Mapping[str, int], stale: _Stale
    ) -> bool:
        """A weekly run without submissions asks the model only if something needs it."""
        return bool(stale.lines or retention.crowded(entries, scopes, sizes) or self._changed_lately())

    def _changed_lately(self) -> bool:
        """An entry changed lately: the files of the architect (`projects/<slug>/overview.md` and the like) do not count."""
        facts = [f"projects/{slug}/facts" for slug in Store(self.memory).project_slugs()]
        try:
            out = self.git.run("log", f"--since={CHANGED_DAYS}.days.ago", "--name-only", "--format=", "--", *ENTRY_DIRS, *facts)
        except GitError as e:  # no commit yet
            log.debug("cannot tell what changed lately: %s", e)
            return False
        return bool(out.strip())

    def _stale(self, store: Store, entries: Sequence[Entry]) -> _Stale:
        """The stale entries with a verify hint, with the repos of their projects (INDEX repo paths that exist).

        At most MAX_STALE_REPOS repos in all; the entries that have been unverified the longest get them first.
        """
        rows = store.projects_index()
        today = self.now.date()
        repo_of = {r.slug: Path(r.repo).expanduser() for r in rows}
        chosen: list[Path] = []
        lines: list[StaleLine] = []
        for e in retention.stale_entries(entries, today, retention.done_slugs(rows)):
            if not e.verify:
                continue
            repos: list[Path] = []
            for src in e.sources:
                repo = repo_of.get(src.project) if src.project else None
                if repo is None or repo in repos or not _is_repo(repo):
                    continue
                if repo not in chosen:
                    if len(chosen) >= MAX_STALE_REPOS:
                        continue
                    chosen.append(repo)
                repos.append(repo)
            lines.append(StaleLine(e.rel, e.verify, tuple(str(r) for r in repos)))
        return _Stale(tuple(lines), tuple(chosen))

    def _prompts(
        self,
        store: Store,
        scopes: ScopesConfig,
        fresh: Sequence[Record],
        entries: Sequence[Entry],
        sizes: Mapping[str, int],
        stale: _Stale,
    ) -> tuple[str, str]:
        today = self.now.date()
        flags = retention.stale_flags(entries, today, retention.done_slugs(store.projects_index()))
        index_text = index.render_index(entries, scopes, flags, sizes)
        system = prompt.system_prompt(self.memory, self.skills_dir)
        message = prompt.user_message(
            run_id=self.run_id,
            mode=self.mode,
            today=today,
            slugs=store.project_slugs(),
            budgets=prompt.budget_lines(store, scopes),
            skill_ideas=self._skill_ideas(),
            rejected=rejected.recent(),
            stale=stale.lines,
            index=index_text,
            records=fresh,
        )
        return system, message

    def _skill_ideas(self) -> list[str]:
        """The skill ideas that wait in `skill-ideas/`, one line each: the model may improve one, not draft it again."""
        return [f"- {ideas.DIR}/{name}.md" for name in ideas.names(self.memory)]

    # the model

    def _ask(self, llm: Llm, system: str, message: str, add_dirs: Sequence[Path]) -> ops.Response | _Failed:
        """The one call. Whatever goes wrong, nothing is applied; `execute` counts it as an attempt of the records."""
        try:
            text = llm.run(system, message, add_dirs)
        except LlmError as e:
            log.error("the curator call failed: %s", e)
            self._alert("knowledge: curator call failed", str(e), "llm-failure")
            return _Failed(SKIPPED_LLM, str(e))
        try:
            response = ops.parse_response(text)
        except ParseError as e:
            log.error("the curator's answer cannot be used: %s", e)
            self._alert("knowledge: curator answer unusable", str(e), "llm-failure")
            return _Failed(SKIPPED_RESPONSE, f"unusable answer: {e}")
        return response

    def _alert(self, title: str, body: str, key: str) -> None:
        if not self.read_only:
            notify(title, body, key, self.now.date())

    # the decisions

    def _decide_all(
        self,
        ctx: ApplyContext,
        response: ops.Response,
        keys: Sequence[str],
        problems: dict[str, list[str]],
        fresh: Sequence[Record],
    ) -> None:
        by_id = {r.id: r for r in fresh}
        handled: set[str] = set()
        for key, d in zip(keys, response.decisions, strict=True):
            rec = by_id.get(d.submission) if d.submission is not None else None
            # a second decision about the same record has the key `<id>#2` and is invalid; it does not retry the record
            owner = rec if rec is not None and key == d.submission else None
            if owner is not None:
                handled.add(owner.id)
            errors = problems.get(key, [])
            if errors:
                self._invalid(key, d, owner, errors)
            else:
                self._decide(ctx, key, d, rec)
        for rec in fresh:
            if rec.id not in handled:
                self._retry(rec, rec.id, "undecided", "the curator did not decide it", ["undecided"])

    def _decide(self, ctx: ApplyContext, key: str, d: ops.Decision, rec: Record | None) -> None:
        if d.verdict == "reject":
            self._note(d.submission, key, d.verdict, d.reason, "rejected")
            return
        try:
            applied = apply_decision(ctx, d, key=key)
        except ApplyError as e:
            log.warning("decision %s cannot be applied: %s", key, e)
            self._invalid(key, d, rec, [str(e)])
            return
        except Exception as e:  # a crash (e.g. a git error): put back what it left half-done now, and count a try
            log.exception("decision %s crashed", key)
            recover(self.git)
            self._invalid(key, d, rec, [f"crashed: {type(e).__name__}: {e}"])
            return
        self._note(d.submission, key, d.verdict, d.reason, "applied", applied.paths, applied.commit, applied.notes)

    def _invalid(self, key: str, d: ops.Decision, owner: Record | None, errors: Sequence[str]) -> None:
        """An invalid decision: its record is tried again; one without a record (or a second one) is only logged."""
        if owner is None:
            self._note(None, key, d.verdict, d.reason, "invalid", notes=errors)
        else:
            self._retry(owner, key, d.verdict, d.reason, errors)

    def _retry(self, rec: Record, key: str, verdict: str, reason: str, errors: Sequence[str]) -> None:
        """Put the record back in the inbox, at most MAX_RETRIES times, then give up on it. A failed call counts too.

        `deferred` is not a final outcome (`decided_ids` ignores it, and `_note` keeps the file), so it is curated again.
        The record carries the errors of a refused decision, so that the model does not repeat it; a failed call says nothing
        about the decision, so it leaves them as they were.
        """
        last = rec.last_errors if verdict == _NOT_A_DECISION else _last_errors(errors)
        if rec.attempt < MAX_RETRIES:
            self.inbox.put(replace(rec, attempt=rec.attempt + 1, last_errors=last))
            self._note(rec.id, key, verdict, reason, "deferred", notes=[f"attempt {rec.attempt + 1} of {MAX_RETRIES}", *errors])
        else:
            self.inbox.put(replace(rec, last_errors=last))  # the `.failed` file says why, for the user who moves it back
            self._note(rec.id, key, verdict, reason, "failed", notes=errors)

    def _note(
        self,
        sid: str | None,
        key: str,
        verdict: str,
        reason: str,
        outcome: str,
        paths: Sequence[str] = (),
        commit: str | None = None,
        notes: Sequence[str] = (),
    ) -> None:
        self.decided.append(
            decisions.Decision(
                id=sid,
                key=key,
                run=self.run_id,
                at=_stamp(self.now),
                verdict=verdict,
                reason=reason,
                paths=tuple(paths),
                commit=commit,
                outcome=outcome,
                notes=tuple(notes),
            )
        )
        self.counts[outcome] = self.counts.get(outcome, 0) + 1
        # last: a crash before this leaves a file that `_open` removes if it was decided, else curates again
        if sid is not None and outcome == "failed":
            self.inbox.fail(sid)
        elif sid is not None and outcome != "deferred":
            self.inbox.remove(sid)

    def _preview(
        self,
        response: ops.Response,
        keys: Sequence[str],
        problems: dict[str, list[str]],
        by_id: dict[str, Record],
    ) -> str:
        """--dry-run: what the model decided and what would become of it."""
        items: list[Json] = []
        decided: set[str] = set()
        for key, d in zip(keys, response.decisions, strict=True):
            if d.submission is not None:
                decided.add(d.submission)
            errors = problems.get(key, [])
            if errors:
                what = "invalid"
            elif d.verdict == "reject":
                what = "rejected"
            else:
                what = "apply"
            items.append({"key": key, "outcome": what, "errors": data.strs(errors), "decision": ops.decision_obj(d)})
        undecided = [r for r in by_id if r not in decided]
        doc: Obj = {"summary": summary_obj(self.summary()), "decisions": items, "undecided": data.strs(undecided)}
        return data.dumps(doc)

    # retention

    def _maintain(self) -> None:
        """Drop what lost its place to a budget, in one commit; tell the user what only they can drop
        (their own entries, when a budget is over).

        The deletions are in `applying.json` until the commit is made, so a crash puts the files back and the next
        run plans again. An eviction is not noted in rejected.md: the entry was not wrong, it only lost its place.
        """
        store = Store(self.memory)
        entries = store.entries()
        today = self.now.date()
        plan = retention.plan(
            entries,
            load_scopes(self.memory),
            today,
            retention.done_slugs(store.projects_index()),
            index.file_sizes(store, entries),
        )
        drops = list(plan.evict)
        if drops:
            paths = [d.rel for d in drops]
            begin_intent(self.git, f"retention-{self.run_id}", paths)
            for d in drops:
                store.delete(d.rel)
            subject = f"knowledge: drop {len(drops)} entries (evicted)"
            self.git.commit(paths, subject, "\n".join(retention.drop_line(d) for d in drops), {"Run": self.run_id})
            end_intent()
            log.info("%s", subject)
        if plan.user_overflow:
            self._alert("knowledge: store over budget", _user_text(plan.user_overflow), "user-overflow")

    # the end

    def _finish(self, skipped: str | None = None) -> RunSummary:
        """Everything is decided: the housekeeping, which the next run repeats if this one dies."""
        if not self.read_only:
            store = Store(self.memory)
            flags = retention.stale_flags(store.entries(), self.now.date(), retention.done_slugs(store.projects_index()))
            index.regenerate(self.memory, flags)
            self.git.commit([index.INDEX_FILE], "knowledge: update index")
            self.decided.trim(now=self.now)
        return self.summary(skipped)

    def summary(self, skipped: str | None = None, text: str | None = None) -> RunSummary:
        c = self.counts
        return RunSummary(
            run=self.run_id,
            mode=self.mode,
            records=self.seen,
            applied=c.get("applied", 0),
            rejected=c.get("rejected", 0),
            invalid=c.get("invalid", 0) + c.get("deferred", 0),
            failed=c.get("failed", 0),
            waiting=self.waiting,
            skipped=skipped,
            text=text,
        )


def run(
    weekly: bool = False,
    if_idle: bool = False,
    dry_run: bool = False,
    print_prompt: bool = False,
    llm: Llm | None = None,
    now: datetime.datetime | None = None,
) -> RunSummary:
    """One curator run. `if_idle`: return `skipped: busy` instead of waiting for a run that is going.

    `llm` defaults to `make_llm()`. `--dry-run` calls the model but changes nothing;
    `--print-prompt` does not call it. Neither changes the inbox, commits, notifies or writes a decision.
    """
    at =(now or datetime.datetime.now(datetime.UTC)).astimezone(datetime.UTC)
    r = _Run(weekly, dry_run or print_prompt, dry_run, at)
    lock = FileLock(locks.curator_lock(), 0.0 if if_idle else LOCK_WAIT)
    if not lock.acquire():
        if if_idle:
            log.info("another curator run is going")
            return r.summary(SKIPPED_BUSY)
        raise LockTimeout(f"{lock.path}: still locked after {LOCK_WAIT:g}s")
    try:
        return r.execute(llm, print_prompt)
    finally:
        lock.release()


def run_pending(weekly: bool = False, if_idle: bool = False) -> RunSummary:
    """`run`, and again while a run leaves records of another trust waiting (a run curates records of one trust only).

    At most MAX_RUNS runs, and none after one that was skipped (busy, a failed call). The runs after the first are intake
    runs: a weekly one looks at the store once.
    """
    summary = run(weekly=weekly, if_idle=if_idle)
    for _ in range(MAX_RUNS - 1):
        if summary.skipped is not None or not summary.waiting:
            break
        log.info("curator run %s: %s; running again for the records that wait", summary.run, data.dumps(summary_obj(summary)))
        summary = run(if_idle=if_idle)
    return summary
