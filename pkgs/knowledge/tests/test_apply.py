import datetime
import json
import stat
import subprocess
from dataclasses import replace
from pathlib import Path

import pytest

from knowledge import locks, rejected
from knowledge.apply import ApplyContext, ApplyError, apply_decision, recover
from knowledge.config import ai_repo, state_dir
from knowledge.entry import Entry, Source
from knowledge.gitops import Git, GitError
from knowledge.ops import (
    Decision,
    DeleteOp,
    EntryFields,
    Op,
    PrivateOp,
    SetStatusOp,
    SkillOp,
    VerifiedOp,
    WriteOp,
)
from knowledge.records import Origin, Record
from knowledge.scopes import load_scopes
from knowledge.store import Store

S1 = "s-20261006T153201Z-a1b2c3"
S2 = "s-20261006T153202Z-d4e5f6"
TODAY = "2026-10-06"
OLD = "2026-09-01"


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


def fields(**changes: object) -> EntryFields:
    base = EntryFields(
        description="Use string unions, not enums",
        kind="convention",
        tags=("typescript",),
        confidence="medium",
        status="active",
        verify=None,
        related=(),
    )
    return replace(base, **changes)


def write(path: str = "lang/typescript/no-enums.md", body: str = "Prefer string unions.", **changes: object) -> WriteOp:
    return WriteOp(path=path, entry=fields(**changes), body=body)


def decision(ops: list[Op], sid: str | None = S1, verdict: str = "create", reason: str = "worth keeping") -> Decision:
    return Decision(submission=sid, verdict=verdict, reason=reason, ops=tuple(ops))


def existing(scope: str = "lang/typescript", name: str = "no-enums", **changes: object) -> Entry:
    base = Entry(
        name=name,
        description="Old description",
        kind="convention",
        scope=scope,
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


def keep(ctx: ApplyContext, entry: Entry) -> None:
    """An entry that is already in the store and committed."""
    ctx.store.write(entry)
    ctx.git.commit([entry.rel], "seed")


def intent() -> Path:
    return state_dir() / "applying.json"


def trailer(repo: Path, key: str) -> str:
    return sh(repo, "log", "-n1", f"--format=%(trailers:key={key},valueonly)")


# create


def test_create_sets_dates_source_trust_and_commit(ctx: ApplyContext, memory_repo: Path):
    applied = apply_decision(ctx, decision([write()]))
    assert applied.paths == ("lang/typescript/no-enums.md",)
    assert applied.commit == ctx.git.head()
    assert applied.notes == ()
    e = ctx.store.read("lang/typescript/no-enums.md")
    assert (e.created, e.updated, e.last_verified) == (TODAY, TODAY, TODAY)
    assert e.trust == "agent"
    assert e.status == "active"
    assert e.description == "Use string unions, not enums"
    assert e.sources == (Source(TODAY, "coder", None, "agent", S1, "saw it in review"),)
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: create lang/typescript/no-enums.md"
    assert sh(memory_repo, "log", "-n1", "--format=%b", "--no-notes").startswith("worth keeping")
    assert trailer(memory_repo, "Submission") == S1
    assert trailer(memory_repo, "Run") == "r-20261006T153300Z"
    assert trailer(memory_repo, "Trust") == "agent"
    assert trailer(memory_repo, "Origin") == "subagent-stop/coder"
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert not intent().exists()


def test_the_subject_counts_the_other_paths(ctx: ApplyContext, memory_repo: Path):
    apply_decision(ctx, decision([write(), write("topic/jj/absorb.md"), write("global/prefs.md")]))
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: create lang/typescript/no-enums.md +2"


def test_the_source_has_the_project_of_the_cwd(ctx: ApplyContext, memory_repo: Path):
    (memory_repo / "INDEX.md").write_text("| slug | status | repo path |\n|---|---|---|\n| dotfiles | active | /work/dotfiles |\n")
    (memory_repo / "projects" / "dotfiles").mkdir(parents=True)
    (memory_repo / "projects" / "dotfiles" / "overview.md").write_text("# dotfiles\n")
    rec = record(cwd="/work/dotfiles/src", via="cli", agent=None)
    ctx = replace(ctx, records={S1: rec})
    apply_decision(ctx, decision([write("projects/dotfiles/facts/f.md")]))
    e = ctx.store.read("projects/dotfiles/facts/f.md")
    assert e.sources[0].project == "dotfiles"
    assert e.sources[0].by == "cli"  # no agent: the way it came in


def test_a_long_evidence_is_cut_to_the_limit(ctx: ApplyContext):
    ctx = replace(ctx, records={S1: replace(record(S1), evidence="e" * 900)})
    apply_decision(ctx, decision([write()]))
    assert len(ctx.store.read("lang/typescript/no-enums.md").sources[0].evidence) == 500


def test_facts_of_a_project_without_overview_are_refused(ctx: ApplyContext, memory_repo: Path):
    before = commit_count(memory_repo)
    with pytest.raises(ApplyError, match="overview"):
        apply_decision(ctx, decision([write("projects/ghost/facts/f.md")]))
    assert commit_count(memory_repo) == before
    assert not (memory_repo / "projects").exists()


# merge


def test_merge_keeps_created_appends_the_source_and_takes_the_max_trust(ctx: ApplyContext):
    keep(ctx, existing())
    ctx = replace(ctx, records={S2: record(S2, trust="user", via="user", agent=None)})
    apply_decision(ctx, decision([write(body="Merged body.")], sid=S2, verdict="merge"))
    e = ctx.store.read("lang/typescript/no-enums.md")
    assert e.created == OLD
    assert (e.updated, e.last_verified) == (TODAY, TODAY)
    assert e.trust == "user"
    assert e.body == "Merged body."
    assert e.description == "Use string unions, not enums"
    assert [s.submission for s in e.sources] == ["s-20260901T000000Z-000000", S2]
    assert e.sources[1].by == "user"


def test_an_entry_keeps_only_its_ten_most_recent_sources(ctx: ApplyContext):
    old = tuple(Source(OLD, "architect", None, "agent", f"s-20260901T0000{i:02d}Z-000000", "first") for i in range(10))
    keep(ctx, existing(sources=old))
    apply_decision(ctx, decision([write()], verdict="merge"))
    e = ctx.store.read("lang/typescript/no-enums.md")
    assert [s.submission for s in e.sources] == [*[s.submission for s in old[1:]], S1]


def test_merge_never_lowers_the_trust(ctx: ApplyContext):
    keep(ctx, existing(trust="user"))
    ctx = replace(ctx, records={S2: record(S2, trust="agent")})  # an agent's merge into the user's entry is refused
    with pytest.raises(ApplyError, match="an entry of the user"):
        apply_decision(ctx, decision([write()], sid=S2, verdict="merge"))
    ctx = replace(ctx, records={S2: record(S2, trust="user", via="user", agent=None)})
    apply_decision(ctx, decision([write()], sid=S2, verdict="merge"))
    assert ctx.store.read("lang/typescript/no-enums.md").trust == "user"


def test_a_maintenance_write_keeps_the_trust_and_adds_no_source(ctx: ApplyContext):
    keep(ctx, existing(trust="untrusted"))  # not "agent": a write that reset the trust would show
    apply_decision(ctx, decision([write()], sid=None, verdict="maintain"))
    e = ctx.store.read("lang/typescript/no-enums.md")
    assert e.trust == "untrusted"
    assert len(e.sources) == 1
    assert trailer(ctx.git.repo, "Submission") == "-"
    assert trailer(ctx.git.repo, "Origin") == "curator/-"


def test_a_new_maintenance_entry_is_agent_trust(ctx: ApplyContext):
    apply_decision(ctx, decision([write()], sid=None, verdict="maintain"))
    e = ctx.store.read("lang/typescript/no-enums.md")
    assert e.trust == "agent"
    assert e.sources == ()


# delete, verified, set_status


def test_a_merged_delete_commits_the_removal_and_writes_no_note(ctx: ApplyContext, memory_repo: Path):
    keep(ctx, existing())
    apply_decision(ctx, decision([DeleteOp("lang/typescript/no-enums.md", "merged")], verdict="merge"))
    assert not (memory_repo / "lang").exists()
    assert sh(memory_repo, "ls-files", "lang") == ""
    assert rejected.recent() == []
    assert not rejected.path().exists()
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: merge lang/typescript/no-enums.md"


@pytest.mark.parametrize("reason", ["refuted", "obsolete"])
def test_a_delete_that_says_the_entry_is_wrong_writes_a_note_after_the_commit(ctx: ApplyContext, reason: str):
    keep(ctx, existing())
    apply_decision(ctx, decision([DeleteOp("lang/typescript/no-enums.md", reason)], verdict="reject"))
    assert rejected.recent() == [f"- {TODAY} lang/typescript/no-enums.md ({reason}): Old description"]


def test_a_failed_commit_writes_no_note(ctx: ApplyContext, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    keep(ctx, existing())
    real = ctx.git.commit

    def fail(*args: object, **kwargs: object) -> str:
        raise GitError("commit", "boom")

    monkeypatch.setattr(ctx.git, "commit", fail)
    with pytest.raises(GitError):
        apply_decision(ctx, decision([DeleteOp("lang/typescript/no-enums.md", "refuted")], verdict="reject"))
    assert rejected.recent() == []  # the deletion is rolled back by `recover`, and made again by the next run
    assert recover(ctx.git) == S1
    assert (memory_repo / "lang/typescript/no-enums.md").is_file()
    monkeypatch.setattr(ctx.git, "commit", real)
    apply_decision(ctx, decision([DeleteOp("lang/typescript/no-enums.md", "refuted")], verdict="reject"))
    assert rejected.recent() == [f"- {TODAY} lang/typescript/no-enums.md (refuted): Old description"]


def test_a_path_written_again_after_its_delete_gets_no_note(ctx: ApplyContext):
    keep(ctx, existing())
    path = "lang/typescript/no-enums.md"
    apply_decision(ctx, decision([DeleteOp(path, "obsolete"), write(path)], verdict="supersede"))
    assert rejected.recent() == []
    assert ctx.store.read(path).description == "Use string unions, not enums"


def test_merge_into_another_entry_and_delete_the_source_in_one_commit(ctx: ApplyContext, memory_repo: Path):
    keep(ctx, existing())
    keep(ctx, existing(name="strings"))
    before = commit_count(memory_repo)
    ops: list[Op] = [write("lang/typescript/strings.md"), DeleteOp("lang/typescript/no-enums.md", "merged")]
    applied = apply_decision(ctx, decision(ops, verdict="merge"))
    assert commit_count(memory_repo) == before + 1
    assert applied.paths == ("lang/typescript/strings.md", "lang/typescript/no-enums.md")
    assert [e.rel for e in ctx.store.entries()] == ["lang/typescript/strings.md"]


def test_delete_of_a_missing_entry_is_refused(ctx: ApplyContext):
    with pytest.raises(ApplyError, match="no such entry"):
        apply_decision(ctx, decision([DeleteOp("lang/typescript/nope.md", "obsolete")]))
    assert rejected.recent() == []
    assert not intent().exists()


def test_verified_updates_last_verified(ctx: ApplyContext):
    keep(ctx, existing())
    apply_decision(ctx, decision([VerifiedOp("lang/typescript/no-enums.md")], sid=None, verdict="maintain"))
    e = ctx.store.read("lang/typescript/no-enums.md")
    assert (e.last_verified, e.updated, e.created) == (TODAY, TODAY, OLD)
    assert e.description == "Old description"
    assert e.sources == existing().sources


def test_verified_of_a_missing_entry_is_refused(ctx: ApplyContext):
    with pytest.raises(ApplyError, match="no such entry"):
        apply_decision(ctx, decision([VerifiedOp("lang/typescript/nope.md")], sid=None, verdict="maintain"))


def test_set_status(ctx: ApplyContext):
    keep(ctx, existing())
    apply_decision(ctx, decision([SetStatusOp("lang/typescript/no-enums.md", "disputed")], sid=None, verdict="maintain"))
    e = ctx.store.read("lang/typescript/no-enums.md")
    assert e.status == "disputed"
    assert e.body == "Old body."


def test_later_ops_see_the_earlier_ones(ctx: ApplyContext):
    ops: list[Op] = [write(), SetStatusOp("lang/typescript/no-enums.md", "disputed")]
    applied = apply_decision(ctx, decision(ops))
    assert applied.paths == ("lang/typescript/no-enums.md",)
    assert ctx.store.read("lang/typescript/no-enums.md").status == "disputed"


# private


def test_private_is_not_committed_and_has_mode_0600(ctx: ApplyContext, memory_repo: Path):
    (memory_repo / ".gitignore").write_text("private/\n")
    ctx.git.commit([".gitignore"], "ignore private")
    before = commit_count(memory_repo)
    op = PrivateOp(org="acme", section="sandbox db", body="user: a\npassword: b")  # not scanned
    applied = apply_decision(ctx, decision([op]))
    assert applied.paths == ()
    assert applied.commit is None
    assert any("private/acme.md" in n for n in applied.notes)
    path = memory_repo / "private" / "acme.md"
    assert "password: b" in path.read_text()
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    assert commit_count(memory_repo) == before
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert sh(memory_repo, "check-ignore", "private/acme.md") == "private/acme.md"
    assert sh(memory_repo, "ls-files", "private") == ""
    assert not intent().exists()


# secrets


def test_a_secret_in_the_body_is_refused_and_nothing_is_written(ctx: ApplyContext, memory_repo: Path):
    before = commit_count(memory_repo)
    ops: list[Op] = [write("global/fine.md"), write(body="Connect with\npassword: hunter2")]
    with pytest.raises(ApplyError, match="password-assignment"):
        apply_decision(ctx, decision(ops))
    assert not (memory_repo / "lang").exists()
    assert not (memory_repo / "global").exists()
    assert not intent().exists()
    assert commit_count(memory_repo) == before
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_a_secret_in_the_description_is_refused(ctx: ApplyContext):
    with pytest.raises(ApplyError, match="password-assignment"):
        apply_decision(ctx, decision([write(description="the password: is in vault")]))
    assert not intent().exists()


def test_a_secret_in_the_frontmatter_is_refused(ctx: ApplyContext, memory_repo: Path):
    before = commit_count(memory_repo)
    with pytest.raises(ApplyError, match="password-assignment"):
        apply_decision(ctx, decision([write(verify="log in with password=hunter2")]))
    leaky = replace(record(S1), evidence="PGPASSWORD=hunter2 psql -h db")
    with pytest.raises(ApplyError, match="pgpassword"):
        apply_decision(replace(ctx, records={S1: leaky}), decision([write()]))
    assert not (memory_repo / "lang").exists()
    assert not intent().exists()
    assert commit_count(memory_repo) == before


def test_a_secret_in_the_reason_is_refused(ctx: ApplyContext, memory_repo: Path):
    before = commit_count(memory_repo)
    with pytest.raises(ApplyError, match="reason.*url-credentials"):
        apply_decision(ctx, decision([write()], reason="found it in postgres://admin:s3cret@db.local/app"))
    assert not (memory_repo / "lang").exists()
    assert not intent().exists()
    assert commit_count(memory_repo) == before


def test_a_body_that_repeats_a_line_of_a_private_note_is_refused(ctx: ApplyContext, memory_repo: Path):
    ctx.store.private_write("acme", "db", "host: sandbox.internal.example\nshort")
    before = commit_count(memory_repo)
    with pytest.raises(ApplyError, match="private note"):
        apply_decision(ctx, decision([write(body="Connect to\n   host: sandbox.internal.example  \nand go")]))
    assert not (memory_repo / "lang").exists()
    assert not intent().exists()
    assert commit_count(memory_repo) == before
    apply_decision(ctx, decision([write(body="short\nsandbox.internal is only a part of it")]))  # no whole line, or too short
    assert (memory_repo / "lang/typescript/no-enums.md").is_file()


def test_a_private_body_with_a_section_heading_is_refused(ctx: ApplyContext, memory_repo: Path):
    ctx.store.private_write("acme", "db", "user: a")
    before = (memory_repo / "private" / "acme.md").read_text()
    with pytest.raises(ApplyError, match="'## '"):
        apply_decision(ctx, decision([PrivateOp("acme", "vpn", "pass\n## db\nuser: overwritten")]))
    assert (memory_repo / "private" / "acme.md").read_text() == before
    assert not intent().exists()


def test_a_private_write_keeps_a_copy_of_the_file_it_replaces(ctx: ApplyContext, memory_repo: Path):
    apply_decision(ctx, decision([PrivateOp("acme", "db", "user: a")]))
    assert not (state_dir() / "private-backup").exists()  # nothing was there to lose
    before = (memory_repo / "private" / "acme.md").read_text()
    apply_decision(ctx, decision([PrivateOp("acme", "db", "user: b")], sid=S2))  # replacing is for the user
    [backup] = (state_dir() / "private-backup").glob("acme.*.md")
    assert backup.read_text() == before
    assert stat.S_IMODE(backup.stat().st_mode) == 0o600
    assert "user: b" in (memory_repo / "private" / "acme.md").read_text()
    apply_decision(ctx, decision([PrivateOp("acme", "vpn", "pass"), PrivateOp("acme", "db", "user: c")], sid=S2))
    assert len(list((state_dir() / "private-backup").glob("acme.*.md"))) == 3  # one per write


def test_an_invalid_entry_is_refused(ctx: ApplyContext, memory_repo: Path):
    with pytest.raises(ApplyError, match="body"):
        apply_decision(ctx, decision([write(body="x" * 5000)]))
    assert not (memory_repo / "lang").exists()
    assert not intent().exists()


def test_a_decision_without_a_record_is_refused(ctx: ApplyContext):
    with pytest.raises(ApplyError, match="no record"):
        apply_decision(ctx, decision([write()], sid="s-20261006T153299Z-ffffff"))


# the entries of the user


USER_ENTRY = "lang/typescript/no-enums.md"


def test_an_agent_may_not_rewrite_an_entry_of_the_user(ctx: ApplyContext, memory_repo: Path):
    keep(ctx, existing(trust="user"))
    before = commit_count(memory_repo)
    for rec, sid in ((record(), S1), (record(trust="untrusted"), S1), (None, None)):
        verdict = "create" if sid is not None else "maintain"
        d = decision([write(body="Changed.")], sid=sid, verdict=verdict)
        with pytest.raises(ApplyError, match=f"{USER_ENTRY}: an entry of the user.*knowledge drop"):
            apply_decision(replace(ctx, records={S1: rec} if rec is not None else {}), d)
    assert ctx.store.read(USER_ENTRY).body == "Old body."
    assert commit_count(memory_repo) == before
    assert not intent().exists()


def test_an_agent_may_not_delete_an_entry_of_the_user(ctx: ApplyContext, memory_repo: Path):
    keep(ctx, existing(trust="user"))
    before = commit_count(memory_repo)
    with pytest.raises(ApplyError, match="an entry of the user"):
        apply_decision(ctx, decision([DeleteOp(USER_ENTRY, "refuted")], verdict="reject"))
    with pytest.raises(ApplyError, match="an entry of the user"):
        apply_decision(ctx, decision([DeleteOp(USER_ENTRY, "evicted")], sid=None, verdict="maintain"))
    assert (memory_repo / USER_ENTRY).is_file()
    assert rejected.recent() == []
    assert commit_count(memory_repo) == before
    assert not intent().exists()


def test_a_refused_op_writes_nothing_of_the_rest_of_the_decision(ctx: ApplyContext, memory_repo: Path):
    keep(ctx, existing(trust="user"))
    with pytest.raises(ApplyError, match="an entry of the user"):
        apply_decision(ctx, decision([write("global/fine.md"), write()]))
    assert not (memory_repo / "global").exists()


def test_an_agent_may_verify_and_dispute_an_entry_of_the_user(ctx: ApplyContext):
    keep(ctx, existing(trust="user"))
    apply_decision(ctx, decision([VerifiedOp(USER_ENTRY)], sid=None, verdict="maintain"))
    e = ctx.store.read(USER_ENTRY)
    assert (e.last_verified, e.trust, e.status) == (TODAY, "user", "active")
    apply_decision(ctx, decision([SetStatusOp(USER_ENTRY, "disputed")], verdict="dispute"))
    e = ctx.store.read(USER_ENTRY)
    assert (e.status, e.trust, e.body) == ("disputed", "user", "Old body.")


def test_a_submission_of_the_user_may_rewrite_and_delete_an_entry_of_the_user(ctx: ApplyContext):
    keep(ctx, existing(trust="user"))
    apply_decision(ctx, decision([write(body="Mine, changed.")], sid=S2, verdict="merge"))
    e = ctx.store.read(USER_ENTRY)
    assert (e.body, e.trust) == ("Mine, changed.", "user")
    apply_decision(replace(ctx, batch_trust="user"), decision([DeleteOp(USER_ENTRY, "obsolete")], sid=S2))
    assert ctx.store.entries() == []


def test_an_entry_of_an_agent_is_rewritten_and_deleted_as_before(ctx: ApplyContext):
    keep(ctx, existing())
    apply_decision(ctx, decision([write(body="Changed.")], verdict="merge"))
    assert ctx.store.read(USER_ENTRY).body == "Changed."
    apply_decision(ctx, decision([DeleteOp(USER_ENTRY, "merged")], verdict="merge"))
    assert ctx.store.entries() == []


# the trust of what a run writes


def test_an_entry_a_record_writes_has_its_trust(ctx: ApplyContext):
    apply_decision(replace(ctx, batch_trust="user"), decision([write("global/own.md")], sid=S2))
    e = ctx.store.read("global/own.md")
    assert (e.trust, [s.trust for s in e.sources]) == ("user", ["user"])
    apply_decision(ctx, decision([write("global/alone.md")], sid=S2))  # no batch trust: the record's own
    assert ctx.store.read("global/alone.md").trust == "user"


def test_an_untrusted_record_leaves_the_entry_it_merges_into_untrusted(ctx: ApplyContext):
    keep(ctx, existing())
    ctx = replace(ctx, records={S1: record(trust="untrusted")}, batch_trust="untrusted")
    apply_decision(ctx, decision([write(body="Changed.")], verdict="merge"))
    e = ctx.store.read(USER_ENTRY)
    assert (e.body, e.trust) == ("Changed.", "untrusted")
    assert [s.trust for s in e.sources] == ["agent", "untrusted"]  # the sources keep their own
    assert trailer(ctx.git.repo, "Trust") == "untrusted"


def test_a_maintenance_write_in_an_untrusted_run_is_capped(ctx: ApplyContext):
    apply_decision(replace(ctx, batch_trust="untrusted"), decision([write()], sid=None, verdict="maintain"))
    assert ctx.store.read("lang/typescript/no-enums.md").trust == "untrusted"


def test_an_untrusted_record_is_applied_with_its_trust(ctx: ApplyContext):
    ctx = replace(ctx, records={S1: record(trust="untrusted")}, batch_trust="untrusted")
    apply_decision(ctx, decision([write()]))
    assert ctx.store.read("lang/typescript/no-enums.md").trust == "untrusted"
    assert trailer(ctx.git.repo, "Trust") == "untrusted"


# the private notes: no untrusted writer, and only the user replaces what is there


def test_an_untrusted_record_may_not_write_a_private_note(ctx: ApplyContext, memory_repo: Path):
    ctx = replace(ctx, records={S1: record(trust="untrusted")})
    with pytest.raises(ApplyError, match="private acme: an untrusted submission"):
        apply_decision(ctx, decision([write(), PrivateOp("acme", "db", "user: a")]))
    assert not (memory_repo / "private").exists()
    assert not (memory_repo / "lang").exists()  # nothing of the decision is written
    assert not intent().exists()


def test_a_decision_without_a_record_may_not_write_a_private_note_in_an_untrusted_run(ctx: ApplyContext, memory_repo: Path):
    d = decision([PrivateOp("acme", "db", "user: a")], sid=None, verdict="maintain")
    with pytest.raises(ApplyError, match="an untrusted submission"):
        apply_decision(replace(ctx, batch_trust="untrusted"), d)
    assert not (memory_repo / "private").exists()
    apply_decision(replace(ctx, batch_trust="agent"), d)  # a new section is fine
    assert ctx.store.private_section("acme", "db") == "user: a"


def test_an_agent_may_not_replace_a_filled_private_section(ctx: ApplyContext, memory_repo: Path):
    ctx.store.private_write("acme", "db", "user: a")
    before = (memory_repo / "private" / "acme.md").read_text()
    with pytest.raises(ApplyError, match="private acme: the section 'db' is filled; only a submission of the user"):
        apply_decision(ctx, decision([PrivateOp("acme", "db", "new")]))
    with pytest.raises(ApplyError, match="is filled"):
        apply_decision(ctx, decision([PrivateOp("acme", "db", "new")], sid=None, verdict="maintain"))
    assert (memory_repo / "private" / "acme.md").read_text() == before
    assert not (state_dir() / "private-backup").exists()
    assert not intent().exists()


def test_an_agent_may_add_a_section_or_fill_an_empty_one(ctx: ApplyContext):
    ctx.store.private_write("acme", "db", "user: a")
    ctx.store.private_write("acme", "empty", "")
    apply_decision(ctx, decision([PrivateOp("acme", "vpn", "pass"), PrivateOp("acme", "empty", "now filled")]))
    assert ctx.store.private_section("acme", "vpn") == "pass"
    assert ctx.store.private_section("acme", "empty") == "now filled"
    assert ctx.store.private_section("acme", "db") == "user: a"


def test_a_private_write_over_a_filled_section_is_applied_and_backed_up_for_the_user(ctx: ApplyContext, memory_repo: Path):
    ctx.store.private_write("acme", "db", "user: a")
    before = (memory_repo / "private" / "acme.md").read_text()
    applied = apply_decision(ctx, decision([PrivateOp("acme", "db", "new")], sid=S2))
    assert any("private/acme.md" in n for n in applied.notes)
    assert "new" in (memory_repo / "private" / "acme.md").read_text()
    [backup] = (state_dir() / "private-backup").glob("acme.*.md")
    assert backup.read_text() == before


# recover


def test_recover_without_an_intent_does_nothing(ctx: ApplyContext):
    assert recover(ctx.git) is None


def test_recover_puts_half_written_files_back(ctx: ApplyContext, memory_repo: Path):
    keep(ctx, existing())
    kept = memory_repo / "lang" / "typescript" / "no-enums.md"
    original = kept.read_text()
    kept.write_text("half written")
    (memory_repo / "global").mkdir()
    (memory_repo / "global" / "new.md").write_text("half")
    (memory_repo / "global" / "other.md").write_text("not mine")
    intent().parent.mkdir(parents=True, exist_ok=True)
    intent().write_text(
        json.dumps({"key": S1, "paths": ["lang/typescript/no-enums.md", "global/new.md"], "created": ["global/new.md"]})
    )

    assert recover(ctx.git) == S1
    assert kept.read_text() == original
    assert not (memory_repo / "global" / "new.md").exists()
    assert (memory_repo / "global" / "other.md").read_text() == "not mine"
    assert not intent().exists()
    assert recover(ctx.git) is None


def test_recover_deletes_only_what_the_intent_says_was_created(ctx: ApplyContext, memory_repo: Path):
    (memory_repo / "global").mkdir()
    (memory_repo / "global" / "mine.md").write_text("made by the decision")
    (memory_repo / "global" / "yours.md").write_text("was there before, untracked")
    intent().parent.mkdir(parents=True, exist_ok=True)
    intent().write_text(json.dumps({"key": S1, "paths": ["global/mine.md", "global/yours.md"], "created": ["global/mine.md"]}))
    assert recover(ctx.git) == S1
    assert not (memory_repo / "global" / "mine.md").exists()
    assert (memory_repo / "global" / "yours.md").read_text() == "was there before, untracked"


def test_recover_of_an_intent_without_created_deletes_nothing(ctx: ApplyContext, memory_repo: Path):
    (memory_repo / "global").mkdir()
    (memory_repo / "global" / "new.md").write_text("half")
    intent().parent.mkdir(parents=True, exist_ok=True)
    intent().write_text(json.dumps({"key": S1, "paths": ["global/new.md"]}))  # the format before `created`
    assert recover(ctx.git) == S1
    assert (memory_repo / "global" / "new.md").read_text() == "half"
    assert not intent().exists()


def test_a_failed_commit_leaves_the_intent_and_recover_cleans_up(
    ctx: ApplyContext, memory_repo: Path, monkeypatch: pytest.MonkeyPatch
):
    keep(ctx, existing())
    keep(ctx, existing(scope="topic/jj", name="gone"))

    def fail(*args: object, **kwargs: object) -> str:
        raise GitError("commit", "boom")

    monkeypatch.setattr(ctx.git, "commit", fail)
    ops: list[Op] = [write("global/new.md"), write(), DeleteOp("topic/jj/gone.md", "obsolete")]
    with pytest.raises(GitError):
        apply_decision(ctx, decision(ops), key=S1)
    saved = json.loads(intent().read_text())
    assert saved == {
        "key": S1,
        "paths": ["global/new.md", "lang/typescript/no-enums.md", "topic/jj/gone.md"],
        "created": ["global/new.md"],  # the others existed before
    }
    assert (memory_repo / "global" / "new.md").exists()
    assert not (memory_repo / "topic").exists()

    assert recover(ctx.git) == S1
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert [e.rel for e in ctx.store.entries()] == ["lang/typescript/no-enums.md", "topic/jj/gone.md"]
    assert ctx.store.read("lang/typescript/no-enums.md").description == "Old description"


# skills


IDEA = "skill-ideas/strings.md"


def skill_op(sources: tuple[str, ...] = (), name: str = "strings", body: str = "Steps.") -> SkillOp:
    return SkillOp(
        name=name,
        description="Use when choosing string unions",
        body=body,
        summary="add strings",
        sources=sources,
    )


def test_a_skill_op_writes_the_idea_and_commits_it(ctx: ApplyContext, memory_repo: Path):
    applied = apply_decision(ctx, decision([skill_op(("lang/typescript/no-enums.md",))], verdict="skill"))
    assert applied.paths == (IDEA,)
    assert applied.commit == ctx.git.head()
    assert applied.notes == ()
    path = memory_repo / IDEA
    assert path.read_text() == (
        "---\nname: strings\ndescription: Use when choosing string unions\n---\n\nSteps.\n\n"
        "<!-- skill idea of the knowledge curator, 2026-10-06: new skill\n"
        "why: add strings\n"
        "sources: lang/typescript/no-enums.md\n"
        "Copy to ~/projects/ai/skills/strings/SKILL.md without this comment, "
        "then `knowledge drop --taken skill-ideas/strings.md`; or `knowledge drop skill-ideas/strings.md` to reject the idea. -->\n"
    )
    assert stat.S_IMODE(path.stat().st_mode) == 0o644
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: skill idea strings"
    assert trailer(memory_repo, "Submission") == S1
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert ctx.store.entries() == []  # an idea is not an entry
    assert not intent().exists()


def test_the_idea_is_committed_with_the_other_ops_of_the_decision(ctx: ApplyContext, memory_repo: Path):
    applied = apply_decision(ctx, decision([write(), skill_op()]))
    assert applied.paths == ("lang/typescript/no-enums.md", IDEA)
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: create lang/typescript/no-enums.md +1"
    shown = sh(memory_repo, "show", "--name-only", "--format=")
    assert [line for line in shown.splitlines() if line] == ["lang/typescript/no-enums.md", IDEA]
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_the_subject_of_several_ideas_counts_the_others(ctx: ApplyContext, memory_repo: Path):
    apply_decision(ctx, decision([skill_op(), skill_op(name="more-strings")], verdict="skill"))
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: skill idea strings +1"


def test_a_later_idea_of_the_same_name_overwrites_the_file(ctx: ApplyContext, memory_repo: Path):
    apply_decision(ctx, decision([skill_op(body="First.")], verdict="skill"))
    apply_decision(ctx, decision([skill_op(body="Better.")], sid=S2, verdict="skill"))
    text = (memory_repo / IDEA).read_text()
    assert "Better." in text and "First." not in text
    assert commit_count(memory_repo) == 3
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: skill idea strings"


def test_an_existing_skill_makes_the_idea_an_update(ctx: ApplyContext, memory_repo: Path):
    skill = ai_repo() / "skills" / "strings" / "SKILL.md"
    skill.parent.mkdir(parents=True)
    skill.write_text("---\nname: strings\ndescription: Use when x.\n---\n\nDo x.\n")
    apply_decision(ctx, decision([skill_op()], verdict="skill"))
    text = (memory_repo / IDEA).read_text()
    assert "2026-10-06: update of the existing skill skills/strings\n" in text
    assert "new skill" not in text
    (skill.parent / "SKILL.md").unlink()  # a directory without a SKILL.md is not a skill
    apply_decision(ctx, decision([skill_op(body="Again.")], sid=S2, verdict="skill"))
    assert "2026-10-06: new skill\n" in (memory_repo / IDEA).read_text()


def test_a_secret_in_an_idea_refuses_the_whole_decision(ctx: ApplyContext, memory_repo: Path):
    before = commit_count(memory_repo)
    token = "glpat-" + "a" * 20
    with pytest.raises(ApplyError, match="skill-ideas/strings.md: looks like it holds a secret"):
        apply_decision(ctx, decision([write(), skill_op(body=f"Use {token} for the login.")]))
    assert not (memory_repo / "skill-ideas").exists()
    assert not (memory_repo / "lang").exists()
    assert commit_count(memory_repo) == before
    assert not intent().exists()


def test_a_line_of_a_private_note_in_an_idea_refuses_the_decision(ctx: ApplyContext, memory_repo: Path):
    ctx.store.private_write("acme", "db", "the sandbox login is dbuser1")
    with pytest.raises(ApplyError, match="the idea repeats a line of a private note"):
        apply_decision(ctx, decision([skill_op(body="Steps.\nthe sandbox login is dbuser1\n")], verdict="skill"))
    assert not (memory_repo / "skill-ideas").exists()


def test_an_idea_with_a_bad_name_is_refused(ctx: ApplyContext, memory_repo: Path):
    with pytest.raises(ApplyError, match="invalid skill name"):
        apply_decision(ctx, decision([skill_op(name="Bad Name")], verdict="skill"))
    assert not (memory_repo / "skill-ideas").exists()


def test_a_crash_before_the_commit_puts_the_idea_back(ctx: ApplyContext, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    def fail(*args: object, **kwargs: object) -> str:
        raise GitError("commit", "boom")

    monkeypatch.setattr(ctx.git, "commit", fail)
    with pytest.raises(GitError):
        apply_decision(ctx, decision([skill_op()], verdict="skill"), key=S1)
    assert json.loads(intent().read_text()) == {"key": S1, "paths": [IDEA], "created": [IDEA]}
    assert (memory_repo / IDEA).exists()
    assert recover(ctx.git) == S1
    assert not (memory_repo / IDEA).exists()
