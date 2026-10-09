import datetime
import io
import json
import subprocess
from dataclasses import replace
from pathlib import Path

import pytest

from knowledge import cli, locks, rejected
from knowledge.apply import ApplyContext, apply_decision
from knowledge.config import UsageError
from knowledge.data import ParseError
from knowledge.entry import Entry, Source
from knowledge.gitops import Git, GitError
from knowledge.manual import Manual
from knowledge.ops import Decision, DeleteOp, EntryFields, Op, SkillOp, WriteOp
from knowledge.records import Origin, Record
from knowledge.scopes import load_scopes
from knowledge.store import Store

S1 = "s-20261006T153201Z-a1b2c3"
S2 = "s-20261006T153202Z-d4e5f6"
NOW = datetime.datetime(2026, 10, 6, 16, 0, tzinfo=datetime.UTC)
TODAY = "2026-10-06"
OLD = "2026-09-01"
PATH = "lang/typescript/no-enums.md"
IDEA = "skill-ideas/strings.md"


def sh(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-c", "core.hooksPath=/dev/null", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )
    return proc.stdout.strip()


def commit_count(repo: Path) -> int:
    return int(sh(repo, "rev-list", "--count", "HEAD"))


def trailer(repo: Path, key: str) -> str:
    return sh(repo, "log", "-n1", f"--format=%(trailers:key={key},valueonly)")


def record(sid: str = S1, trust: str = "agent", **origin: str | None) -> Record:
    fields: dict[str, str | None] = {"via": "subagent-stop", "agent": "coder", "cwd": None, "event": None, "session": None}
    fields.update(origin)
    return Record(
        id=sid,
        received="2026-10-06T15:32:01Z",
        trust=trust,
        attempt=0,
        title="no enums",
        body="Use string unions.",
        kind=None,
        scope=None,
        evidence="saw it in review",
        origin=Origin(**fields),
    )


def write(path: str = PATH, body: str = "Prefer string unions.") -> WriteOp:
    fields = EntryFields(
        description="Use string unions, not enums",
        kind="convention",
        tags=("typescript",),
        confidence="medium",
        status="active",
        verify=None,
        related=(),
    )
    return WriteOp(path=path, entry=fields, body=body)


def skill_idea(name: str = "strings") -> SkillOp:
    return SkillOp(name, "Use when choosing string unions.", "Prefer unions.", "add strings", ())


def decision(ops: list[Op], sid: str | None = S1, verdict: str = "create", reason: str = "worth keeping") -> Decision:
    return Decision(submission=sid, verdict=verdict, reason=reason, ops=tuple(ops))


def existing(**changes: object) -> Entry:
    base = Entry(
        name="no-enums",
        description="Old description",
        kind="convention",
        scope="lang/typescript",
        tags=("typescript",),
        confidence="medium",
        trust="agent",
        status="active",
        created=OLD,
        updated=OLD,
        last_verified=OLD,
        verify=None,
        related=(),
        sources=(Source(OLD, "architect", None, "agent", "s-20260901T000000Z-000000", "first"),),
        body="Old body.",
    )
    return replace(base, **changes)


@pytest.fixture
def ctx(memory_repo: Path) -> ApplyContext:
    return ApplyContext(
        store=Store(memory_repo),
        git=Git(memory_repo, locks.memory_lock(), lock_timeout=1.0),
        scopes=load_scopes(memory_repo),
        run_id="r-20261006T153300Z",
        records={S1: record(S1), S2: record(S2, trust="user", via="user", agent=None)},
        today=datetime.date(2026, 10, 6),
    )


@pytest.fixture
def manual(ctx: ApplyContext) -> Manual:
    return Manual(ctx.git, now=NOW)


def keep(ctx: ApplyContext, entry: Entry) -> None:
    """An entry that is already in the store and committed."""
    ctx.store.write(entry)
    ctx.git.commit([entry.rel], "seed")


# undo


def test_undo_of_a_merge_brings_the_previous_content_back(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    keep(ctx, existing())
    before = (memory_repo / PATH).read_text()
    apply_decision(ctx, decision([write(body="Merged body.")], verdict="merge"))
    assert (memory_repo / PATH).read_text() != before
    count = commit_count(memory_repo)
    out = manual.undo(S1)
    assert (memory_repo / PATH).read_text() == before
    assert out["commit"] == ctx.git.head()
    assert len(out["reverted"]) == 1
    assert commit_count(memory_repo) == count + 1
    assert sh(memory_repo, "log", "-n1", "--format=%s") == f"knowledge: undo {S1}"
    assert trailer(memory_repo, "Undo") == S1
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_undo_of_a_create_removes_the_entry(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    apply_decision(ctx, decision([write()]))
    manual.undo(S1)
    assert not (memory_repo / PATH).exists()
    assert sh(memory_repo, "ls-files", "lang") == ""


def test_undo_reverts_every_commit_of_the_submission(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    apply_decision(ctx, decision([write()]))
    apply_decision(ctx, decision([write("global/prefs.md")]))  # the same submission twice, e.g. a retry
    out = manual.undo(S1)
    assert len(out["reverted"]) == 2
    assert not (memory_repo / PATH).exists()
    assert not (memory_repo / "global" / "prefs.md").exists()


def test_undo_of_a_skill_idea_removes_its_file(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    apply_decision(ctx, decision([skill_idea()], verdict="skill"))
    assert (memory_repo / IDEA).is_file()
    manual.undo(S1)
    assert not (memory_repo / IDEA).exists()
    assert sh(memory_repo, "ls-files", "skill-ideas") == ""
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_undo_with_a_conflict_fails_and_leaves_the_repo_clean(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    keep(ctx, existing())
    apply_decision(ctx, decision([write(body="First change.")], verdict="merge"))
    apply_decision(ctx, decision([write(body="Second change.")], sid=S2, verdict="merge"))
    head = ctx.git.head()
    with pytest.raises(GitError):
        manual.undo(S1)
    assert ctx.git.head() == head
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert "Second change." in (memory_repo / PATH).read_text()


def test_undo_of_an_unknown_or_malformed_id(manual: Manual):
    with pytest.raises(UsageError, match="no commit"):
        manual.undo(S1)
    with pytest.raises(UsageError, match="not a submission id"):
        manual.undo("-")  # the trailer of every maintenance commit


def test_undo_twice_is_an_error(ctx: ApplyContext, manual: Manual):
    apply_decision(ctx, decision([write()]))
    manual.undo(S1)
    with pytest.raises(GitError):
        manual.undo(S1)


# restore


def test_restore_after_an_eviction(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    keep(ctx, existing())
    apply_decision(ctx, decision([DeleteOp(PATH, "evicted")], sid=None, verdict="maintain"))
    assert not (memory_repo / "lang").exists()
    out = manual.restore(PATH)
    e = ctx.store.read(PATH)
    assert (e.updated, e.created, e.last_verified) == (TODAY, OLD, TODAY)  # looked at today: not stale again at once
    assert (e.description, e.body, e.sources) == ("Old description", "Old body.", existing().sources)
    assert out["commit"] == ctx.git.head()
    assert sh(memory_repo, "log", "-n1", "--format=%s") == f"knowledge: restore {PATH}"
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_restore_takes_the_last_deletion(ctx: ApplyContext, manual: Manual):
    keep(ctx, existing())
    apply_decision(ctx, decision([DeleteOp(PATH, "obsolete")], sid=None, verdict="maintain"))
    manual.restore(PATH)
    ctx.store.write(replace(ctx.store.read(PATH), body="Second life."))
    ctx.git.commit([PATH], "edit")
    apply_decision(ctx, decision([DeleteOp(PATH, "obsolete")], sid=None, verdict="maintain"))
    manual.restore(PATH)
    assert ctx.store.read(PATH).body == "Second life."


def test_restore_refuses_what_exists_or_was_never_deleted(ctx: ApplyContext, manual: Manual):
    with pytest.raises(UsageError, match="no commit deleted"):
        manual.restore(PATH)
    keep(ctx, existing())
    with pytest.raises(UsageError, match="exists"):
        manual.restore(PATH)
    with pytest.raises(ParseError):
        manual.restore("not-an-entry.txt")


# drop


def test_drop_deletes_an_entry_of_the_user_and_notes_it(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    keep(ctx, existing(trust="user"))
    out = manual.drop(PATH, "it was wrong")
    assert not (memory_repo / "lang").exists()
    assert sh(memory_repo, "ls-files", "lang") == ""
    assert out == {"path": PATH, "commit": ctx.git.head()}
    assert sh(memory_repo, "log", "-n1", "--format=%s") == f"knowledge: drop {PATH} (by user)"
    assert sh(memory_repo, "log", "-n1", "--format=%b", "--no-notes").startswith("it was wrong")
    assert rejected.recent() == [f"- {TODAY} {PATH} (dropped by the user: it was wrong): Old description"]
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_drop_without_a_reason_notes_only_who_dropped_it(ctx: ApplyContext, manual: Manual):
    keep(ctx, existing())
    manual.drop(PATH)
    assert rejected.recent() == [f"- {TODAY} {PATH} (dropped by the user): Old description"]


def test_drop_of_a_missing_entry(ctx: ApplyContext, manual: Manual):
    with pytest.raises(UsageError, match="no such entry"):
        manual.drop(PATH)
    assert rejected.recent() == []


def test_drop_of_a_damaged_entry(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    (memory_repo / "lang" / "typescript").mkdir(parents=True)
    (memory_repo / PATH).write_text("not an entry")
    ctx.git.commit([PATH], "damaged")
    manual.drop(PATH)
    assert not (memory_repo / PATH).exists()
    assert rejected.recent() == [f"- {TODAY} {PATH} (dropped by the user):"]


def test_drop_of_a_skill_idea_deletes_the_file_and_notes_it(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    apply_decision(ctx, decision([skill_idea(), skill_idea("other")], verdict="skill"))
    out = manual.drop(IDEA, "not useful")
    assert not (memory_repo / IDEA).exists()
    assert (memory_repo / "skill-ideas" / "other.md").is_file()  # only the one
    assert out == {"path": IDEA, "commit": ctx.git.head()}
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: drop skill idea strings (by user)"
    assert sh(memory_repo, "log", "-n1", "--format=%b", "--no-notes").startswith("not useful")
    assert rejected.recent() == [f"- {TODAY} {IDEA} (dropped by the user: not useful): skill idea strings"]
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_drop_of_a_skill_idea_without_a_reason(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    apply_decision(ctx, decision([skill_idea()], verdict="skill"))
    manual.drop(IDEA)
    assert not (memory_repo / IDEA).exists()
    assert rejected.recent() == [f"- {TODAY} {IDEA} (dropped by the user): skill idea strings"]


def test_drop_taken_deletes_the_idea_and_writes_no_note(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    apply_decision(ctx, decision([skill_idea(), skill_idea("other")], verdict="skill"))
    out = manual.drop(IDEA, "now a skill", taken=True)
    assert not (memory_repo / IDEA).exists()
    assert (memory_repo / "skill-ideas" / "other.md").is_file()  # only the one
    assert out == {"path": IDEA, "commit": ctx.git.head()}
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: skill idea strings taken (by user)"
    assert sh(memory_repo, "log", "-n1", "--format=%b", "--no-notes").startswith("now a skill")
    assert rejected.recent() == []  # not rejected: the curator may go on improving the skill
    assert not rejected.path().exists()
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_plain_drop_of_an_idea_is_a_rejection(ctx: ApplyContext, manual: Manual):
    apply_decision(ctx, decision([skill_idea()], verdict="skill"))
    manual.drop(IDEA)
    assert rejected.recent() == [f"- {TODAY} {IDEA} (dropped by the user): skill idea strings"]


def test_drop_taken_is_for_skill_ideas_only(ctx: ApplyContext, manual: Manual, memory_repo: Path):
    keep(ctx, existing())
    with pytest.raises(UsageError, match="--taken is for a skill idea"):
        manual.drop(PATH, taken=True)
    assert (memory_repo / PATH).is_file()  # untouched
    assert rejected.recent() == []


def test_drop_taken_of_a_missing_or_malformed_skill_idea(ctx: ApplyContext, manual: Manual):
    with pytest.raises(UsageError, match="no such skill idea"):
        manual.drop(IDEA, taken=True)
    with pytest.raises(UsageError, match="not a skill idea path"):
        manual.drop("skill-ideas/Bad Name.md", taken=True)
    assert rejected.recent() == []


def test_a_failed_taken_commit_puts_the_idea_back(ctx: ApplyContext, manual: Manual, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    apply_decision(ctx, decision([skill_idea()], verdict="skill"))

    def fail(*args: object, **kwargs: object) -> str:
        raise GitError("commit", "boom")

    monkeypatch.setattr(ctx.git, "commit", fail)
    with pytest.raises(GitError):
        manual.drop(IDEA, taken=True)
    assert (memory_repo / IDEA).is_file()
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_drop_of_a_missing_or_malformed_skill_idea(ctx: ApplyContext, manual: Manual):
    with pytest.raises(UsageError, match="no such skill idea"):
        manual.drop(IDEA)
    for bad in ("skill-ideas/Bad Name.md", "skill-ideas/a/b.md", "skill-ideas/x.txt", "skill-ideas/.md"):
        with pytest.raises(UsageError, match="not a skill idea path"):
            manual.drop(bad)
    assert rejected.recent() == []


def test_a_failed_drop_commit_puts_the_idea_back(ctx: ApplyContext, manual: Manual, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    apply_decision(ctx, decision([skill_idea()], verdict="skill"))

    def fail(*args: object, **kwargs: object) -> str:
        raise GitError("commit", "boom")

    monkeypatch.setattr(ctx.git, "commit", fail)
    with pytest.raises(GitError):
        manual.drop(IDEA)
    assert (memory_repo / IDEA).is_file()
    assert rejected.recent() == []
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_a_failed_drop_commit_puts_the_entry_back(ctx: ApplyContext, manual: Manual, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    keep(ctx, existing())

    def fail(*args: object, **kwargs: object) -> str:
        raise GitError("commit", "boom")

    monkeypatch.setattr(ctx.git, "commit", fail)
    with pytest.raises(GitError):
        manual.drop(PATH)
    assert ctx.store.read(PATH).description == "Old description"
    assert rejected.recent() == []
    assert sh(memory_repo, "status", "--porcelain") == ""


# the command line


def run(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], *argv: str) -> tuple[int, str]:
    monkeypatch.setattr("sys.argv", ["knowledge", *argv])
    monkeypatch.setattr("sys.stdin", io.StringIO(""))
    code = 0
    try:
        cli.main()
    except SystemExit as e:
        code = int(e.code or 0)
    return code, capsys.readouterr().out


def test_cli_undo_restore_and_drop(ctx: ApplyContext, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]):
    apply_decision(ctx, decision([write()]))
    code, out = run(monkeypatch, capsys, "undo", S1)
    assert code == 0 and json.loads(out)["reverted"]
    assert not (ctx.git.repo / PATH).exists()
    assert run(monkeypatch, capsys, "undo", S1)[0] == 1  # nothing left to revert
    assert run(monkeypatch, capsys, "undo", "s-20261006T000000Z-000000")[0] == 2

    keep(ctx, existing())
    code, out = run(monkeypatch, capsys, "drop", PATH, "--reason", "wrong")
    assert code == 0 and json.loads(out)["path"] == PATH
    assert run(monkeypatch, capsys, "drop", PATH)[0] == 2  # no such entry

    code, out = run(monkeypatch, capsys, "restore", PATH)
    assert code == 0 and json.loads(out)["path"] == PATH
    assert ctx.store.read(PATH).body == "Old body."
    assert run(monkeypatch, capsys, "restore", PATH)[0] == 2  # exists

    apply_decision(ctx, decision([skill_idea()], sid=S2, verdict="skill"))
    code, out = run(monkeypatch, capsys, "drop", IDEA)
    assert code == 0 and json.loads(out)["path"] == IDEA
    assert not (ctx.git.repo / IDEA).exists()
    assert run(monkeypatch, capsys, "drop", IDEA)[0] == 2  # no such skill idea
    assert run(monkeypatch, capsys, "drop", "skill-ideas/Bad.md")[0] == 2


def test_cli_drop_taken(ctx: ApplyContext, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]):
    apply_decision(ctx, decision([skill_idea()], sid=S2, verdict="skill"))
    code, out = run(monkeypatch, capsys, "drop", "--taken", IDEA)
    assert code == 0 and json.loads(out)["path"] == IDEA
    assert not (ctx.git.repo / IDEA).exists()
    assert rejected.recent() == []
    assert sh(ctx.git.repo, "log", "-n1", "--format=%s") == "knowledge: skill idea strings taken (by user)"
    assert run(monkeypatch, capsys, "drop", "--taken", IDEA)[0] == 2  # no such skill idea
    keep(ctx, existing())
    assert run(monkeypatch, capsys, "drop", "--taken", PATH) == (2, "")  # an entry: not for --taken
    assert (ctx.git.repo / PATH).is_file()


def test_cli_undo_with_a_conflict_exits_1(ctx: ApplyContext, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]):
    keep(ctx, existing())
    apply_decision(ctx, decision([write(body="First change.")], verdict="merge"))
    apply_decision(ctx, decision([write(body="Second change.")], sid=S2, verdict="merge"))
    assert run(monkeypatch, capsys, "undo", S1) == (1, "")
    assert sh(ctx.git.repo, "status", "--porcelain") == ""
