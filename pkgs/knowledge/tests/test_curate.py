import datetime
import io
import json
import subprocess
from collections.abc import Mapping, Sequence
from dataclasses import replace
from pathlib import Path

import pytest

from fake_router import serve
from fakes import FakeLlm, submission_ids
from knowledge import cli, config, curate, locks, rejected
from knowledge.config import state_dir
from knowledge.decisions import Decision, Decisions, status
from knowledge.entry import Entry, Source
from knowledge.gitops import Git, GitError
from knowledge.inbox import Inbox
from knowledge.llm import LlmError
from knowledge.locks import FileLock, LockTimeout
from knowledge.records import Record, from_event, to_obj
from knowledge.store import Store

NOW = datetime.datetime(2026, 10, 6, 16, 0, tzinfo=datetime.UTC)
TOKEN = "glpat-" + "a" * 20


def sid(n: int) -> str:
    return f"s-20261006T1532{n:02d}Z-a1b2c{n}"


def sh(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-c", "core.hooksPath=/dev/null", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )
    return proc.stdout.strip()


def commits(repo: Path, submission: str) -> list[str]:
    """The commits that carry `Submission: <id>`."""
    return Git(repo, locks.memory_lock()).commits_with_trailer("Submission", submission)


def commit_count(repo: Path) -> int:
    return int(sh(repo, "rev-list", "--count", "HEAD"))


def intent() -> Path:
    return state_dir() / "applying.json"


# the inbox and the model


def submit(n: int, event: str | None = None, body: str = "Rule, why, example.") -> Record:
    """A submission as `receive` stores it."""
    origin = {"via": "subagent-stop", "agent": "coder", "cwd": None, "event": event, "session": None}
    rec = from_event({"id": sid(n), "title": f"note {n}", "body": body, "origin": origin}, via_router=True, now=NOW)
    Inbox().put(rec)
    return rec


def submit_user(n: int, body: str = "Rule, why, example.") -> Record:
    """A submission of the user at a terminal: trust `user`."""
    origin = {"via": "user", "agent": None, "cwd": None, "event": None, "session": None}
    rec = from_event({"id": sid(n), "title": f"note {n}", "body": body, "origin": origin}, via_router=False, now=NOW)
    assert rec.trust == "user"
    Inbox().put(rec)
    return rec


def entry_op(path: str, kind: str = "convention") -> dict:
    return {
        "op": "write",
        "path": path,
        "entry": {
            "description": f"About {path}",
            "kind": kind,
            "tags": [],
            "confidence": "medium",
            "status": "active",
            "verify": None,
            "related": [],
        },
        "body": "Rule. Why. Example.",
    }


def decision(submission: str | None, verdict: str = "create", ops: list[dict] | None = None, reason: str = "worth keeping") -> dict:
    return {"submission": submission, "verdict": verdict, "reason": reason, "ops": ops or []}


def answer(*decisions: dict) -> str:
    return "```json\n" + json.dumps({"decisions": list(decisions)}) + "\n```"


def path_of(submission: str) -> str:
    return f"topic/jj/note-{submission[-6:]}.md"


def keep_all(message: str) -> str:
    return answer(*[decision(s, ops=[entry_op(path_of(s))]) for s in submission_ids(message)])


def invalid_all(message: str) -> str:
    return answer(*[decision(s, ops=[entry_op(path_of(s), kind="nonsense")]) for s in submission_ids(message)])


def first_only(message: str) -> str:
    s = submission_ids(message)[0]
    return answer(decision(s, ops=[entry_op(path_of(s))]))


def run(llm: FakeLlm, **kwargs: bool) -> curate.RunSummary:
    return curate.run(llm=llm, now=NOW, **kwargs)


def seed_entry(repo: Path) -> None:
    Store(repo).write(
        Entry(
            name="seed", description="Seed entry", kind="convention", scope="topic/jj", tags=(), confidence="medium",
            trust="agent", status="active", created="2026-09-01", updated="2026-09-01", last_verified="2026-09-01",
            verify="jj --help", related=(),
            sources=(Source("2026-09-01", "architect", None, "agent", "s-20260901T000000Z-000000", "first"),),
            body="Old body.",
        )  # fmt: skip
    )
    Git(repo, locks.memory_lock()).commit(["topic/jj/seed.md"], "seed")


# a run


def test_a_run_applies_the_decisions_and_moves_on(memory_repo: Path):
    submit(1)
    submit(2)
    llm = FakeLlm(keep_all)
    summary = run(llm)
    assert (summary.records, summary.applied, summary.skipped) == (2, 2, None)
    assert len(llm.calls) == 1  # one call for the whole batch
    call = llm.calls[0]
    assert call.add_dirs == (memory_repo,)
    assert "# Curator run r-20261006T160000Z" in call.message
    assert "mode: intake" in call.message
    for n in (1, 2):
        assert len(commits(memory_repo, sid(n))) == 1
        assert (memory_repo / path_of(sid(n))).is_file()
    lines = Decisions().all()
    assert [(d.id, d.key, d.outcome, d.run) for d in lines] == [
        (sid(1), sid(1), "applied", "r-20261006T160000Z"),
        (sid(2), sid(2), "applied", "r-20261006T160000Z"),
    ]
    assert lines[0].commit == commits(memory_repo, sid(1))[0]
    assert lines[0].paths == (path_of(sid(1)),)
    assert Inbox().count() == 0
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: update index"
    assert sh(memory_repo, "ls-files", "KNOWLEDGE.md") == "KNOWLEDGE.md"
    assert path_of(sid(1)) in (memory_repo / "KNOWLEDGE.md").read_text()
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert not intent().exists()


def test_the_summary_is_the_documented_object():
    obj = curate.summary_obj(curate.RunSummary("r-1", "intake", records=3, applied=2))
    assert obj == {
        "run": "r-1", "mode": "intake", "records": 3, "applied": 2, "rejected": 0, "invalid": 0,
        "failed": 0, "waiting": 0, "skipped": None,
    }  # fmt: skip


def test_untrusted_input_is_applied_with_trust_untrusted_and_nobody_is_told(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1, event="event:gitlab.note")
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        summary = run(FakeLlm(keep_all))
    assert summary.applied == 1
    e = Store(memory_repo).read(path_of(sid(1)))
    assert (e.trust, [s.trust for s in e.sources]) == ("untrusted", ["untrusted"])
    assert [(d.id, d.outcome) for d in Decisions().all()] == [(sid(1), "applied")]
    [sha] = commits(memory_repo, sid(1))
    assert sh(memory_repo, "show", "-s", "--format=%(trailers:key=Trust,valueonly)", sha) == "untrusted"
    assert router.events == []
    assert Inbox().count() == 0


def test_a_dispute_decision_is_applied(memory_repo: Path):
    seed_entry(memory_repo)
    submit(1)
    flag = {"op": "set_status", "path": "topic/jj/seed.md", "status": "disputed"}
    summary = run(FakeLlm(lambda m: answer(decision(sid(1), "dispute", [flag], reason="contradicts note 1"))))
    assert (summary.applied, summary.invalid) == (1, 0)
    assert Store(memory_repo).read("topic/jj/seed.md").status == "disputed"
    [d] = Decisions().all()
    assert (d.id, d.verdict, d.outcome) == (sid(1), "dispute", "applied")
    assert Inbox().count() == 0


def test_an_agent_decision_over_an_entry_of_the_user_is_refused_and_retried(memory_repo: Path):
    seed_entry(memory_repo)
    store = Store(memory_repo)
    store.write(replace(store.read("topic/jj/seed.md"), trust="user"))
    Git(memory_repo, locks.memory_lock()).commit(["topic/jj/seed.md"], "make it the user's")
    submit(1)
    summary = run(FakeLlm(lambda m: answer(decision(sid(1), "merge", [entry_op("topic/jj/seed.md")]))))
    assert (summary.applied, summary.invalid) == (0, 1)
    [d] = Decisions().all()
    assert d.outcome == "deferred"
    assert "an entry of the user" in " ".join(d.notes)
    assert store.read("topic/jj/seed.md").body == "Old body."
    assert commits(memory_repo, sid(1)) == []


def test_a_reject_is_only_recorded(memory_repo: Path):
    submit(1)
    summary = run(FakeLlm(lambda m: answer(decision(sid(1), "reject", reason="task status"))))
    assert (summary.rejected, summary.applied) == (1, 0)
    [d] = Decisions().all()
    assert (d.id, d.outcome, d.reason, d.commit) == (sid(1), "rejected", "task status", None)
    assert commits(memory_repo, sid(1)) == []
    assert Inbox().count() == 0


def test_an_invalid_decision_is_retried_twice_and_then_fails(memory_repo: Path):
    submit(1)
    llm = FakeLlm(invalid_all)
    first = run(llm)
    assert (first.invalid, first.failed) == (1, 0)
    [rec] = Inbox().pending(10**6)
    assert (rec.id, rec.attempt) == (sid(1), 1)
    second = run(llm)
    assert (second.invalid, second.failed) == (1, 0)
    [rec] = Inbox().pending(10**6)
    assert (rec.id, rec.attempt) == (sid(1), 2)
    third = run(llm)
    assert (third.invalid, third.failed) == (0, 1)
    assert Inbox().count() == 0
    assert [d.outcome for d in Decisions().all()] == ["deferred", "deferred", "failed"]
    assert "kind" in " ".join(Decisions().all()[0].notes)
    assert Decisions().decided_ids() == set()  # a failed record is not decided: it waits as `.failed`
    assert Inbox().state(sid(1)) == "failed"
    assert len(llm.calls) == 3
    assert commits(memory_repo, sid(1)) == []
    assert run(llm).skipped == "idle"  # it is not asked again
    assert len(llm.calls) == 3


def test_a_decision_that_cannot_be_applied_is_retried(memory_repo: Path):
    submit(1)
    ghost = {"op": "delete", "path": "topic/jj/ghost.md", "reason": "obsolete"}
    summary = run(FakeLlm(lambda m: answer(decision(sid(1), "supersede", [ghost]))))
    assert summary.invalid == 1
    [d] = Decisions().all()
    assert d.outcome == "deferred"
    assert "no such entry" in " ".join(d.notes)
    assert commit_count(memory_repo) == 2  # the index only
    [rec] = Inbox().pending(10**6)
    assert rec.attempt == 1


def test_undecided_records_are_retried(memory_repo: Path):
    submit(1)
    submit(2)
    summary = run(FakeLlm(first_only))
    assert (summary.applied, summary.invalid) == (1, 1)
    assert [(d.id, d.outcome) for d in Decisions().all()] == [(sid(1), "applied"), (sid(2), "deferred")]
    assert "undecided" in Decisions().all()[1].notes
    [rec] = Inbox().pending(10**6)
    assert (rec.id, rec.attempt) == (sid(2), 1)


def test_a_decision_about_an_unknown_submission_is_only_logged(memory_repo: Path):
    submit(1)
    stranger = "s-20261006T159999Z-ffffff"
    summary = run(FakeLlm(lambda m: answer(decision(sid(1), "reject"), decision(stranger, "reject"))))
    assert (summary.rejected, summary.invalid) == (1, 1)
    lines = Decisions().all()
    assert [(d.id, d.key, d.outcome) for d in lines] == [(sid(1), sid(1), "rejected"), (None, stranger, "invalid")]
    assert Inbox().count() == 0


def test_a_second_decision_about_a_record_does_not_retry_it(memory_repo: Path):
    submit(1)
    summary = run(FakeLlm(lambda m: answer(decision(sid(1), "reject"), decision(sid(1), "reject"))))
    assert (summary.rejected, summary.invalid) == (1, 1)
    assert [(d.id, d.key, d.outcome) for d in Decisions().all()] == [
        (sid(1), sid(1), "rejected"),
        (None, f"{sid(1)}#2", "invalid"),
    ]
    assert Inbox().count() == 0


# what stops a run


def test_a_failed_call_changes_no_entry(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        first = run(FakeLlm(error=LlmError("claude exited with status 1")))
        again = run(FakeLlm(error=LlmError("boom")))
    assert (first.skipped, again.skipped) == ("llm-failure", "llm-failure")
    assert [d.outcome for d in Decisions().all()] == ["deferred", "deferred"]  # the index commit is the only one
    assert commits(memory_repo, sid(1)) == [] and not (memory_repo / "topic").exists()
    assert len(router.events) == 1  # told once a day


def test_an_answer_that_cannot_be_parsed_changes_no_entry(memory_repo: Path):
    submit(1)
    summary = run(FakeLlm(lambda m: "I could not decide."))
    assert summary.skipped == "bad-response"
    assert [d.outcome for d in Decisions().all()] == ["deferred"]
    assert commits(memory_repo, sid(1)) == [] and not (memory_repo / "topic").exists()


def test_a_hard_secret_is_rejected_without_a_call(memory_repo: Path, caplog: pytest.LogCaptureFixture):
    submit(1, body=f"the token is {TOKEN}")
    llm = FakeLlm(keep_all)
    summary = run(llm)
    assert llm.calls == []
    assert (summary.rejected, summary.skipped) == (1, "idle")
    [d] = Decisions().all()
    assert (d.id, d.outcome) == (sid(1), "rejected")
    assert TOKEN not in json.dumps(d.notes) and TOKEN not in d.reason and TOKEN not in caplog.text
    assert Inbox().count() == 0


def test_a_hard_secret_does_not_reach_the_model(memory_repo: Path):
    submit(1, body=f"the token is {TOKEN}")
    submit(2)
    llm = FakeLlm(keep_all)
    summary = run(llm)
    assert (summary.rejected, summary.applied) == (1, 1)
    assert TOKEN not in llm.calls[0].message
    assert sid(1) not in llm.calls[0].message


def test_if_idle_gives_way_to_a_run_that_is_going(memory_repo: Path):
    submit(1)
    llm = FakeLlm(keep_all)
    with FileLock(locks.curator_lock(), 0.0):
        summary = run(llm, if_idle=True)
    assert summary.skipped == "busy"
    assert llm.calls == []
    assert Inbox().count() == 1
    assert run(llm, if_idle=True).applied == 1  # the lock is free again


def test_a_run_waits_for_the_lock_and_then_gives_up(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(curate, "LOCK_WAIT", 0.1)
    llm = FakeLlm(keep_all)
    with FileLock(locks.curator_lock(), 0.0), pytest.raises(LockTimeout):
        run(llm)
    assert llm.calls == []


def test_the_files_of_records_decided_already_are_removed_without_a_call(memory_repo: Path):
    submit(1)
    Decisions().append(
        Decision(sid(1), sid(1), "r-0", "2026-10-05T10:00:00Z", "create", "", ("a.md",), None, "applied", ())
    )
    llm = FakeLlm(keep_all)
    summary = run(llm)
    assert (summary.skipped, summary.records) == ("idle", 1)
    assert llm.calls == []
    assert Inbox().count() == 0  # consumed


def test_a_deferred_record_is_asked_again(memory_repo: Path):
    submit(1)
    Decisions().append(
        Decision(sid(1), sid(1), "r-0", "2026-10-05T10:00:00Z", "create", "", (), None, "deferred", ())
    )
    llm = FakeLlm(keep_all)
    assert run(llm).applied == 1


# no call, or no change


def test_dry_run_calls_the_model_and_changes_nothing(memory_repo: Path):
    submit(1)
    head = sh(memory_repo, "rev-parse", "HEAD")
    llm = FakeLlm(keep_all)
    summary = run(llm, dry_run=True)
    assert len(llm.calls) == 1
    assert summary.text is not None
    doc = json.loads(summary.text)
    assert [(d["key"], d["outcome"]) for d in doc["decisions"]] == [(sid(1), "apply")]
    assert doc["decisions"][0]["decision"]["ops"][0]["path"] == path_of(sid(1))
    assert doc["undecided"] == []
    assert sh(memory_repo, "rev-parse", "HEAD") == head
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert Decisions().all() == []
    assert Inbox().count() == 1


def test_dry_run_leaves_a_hard_secret_alone(memory_repo: Path):
    submit(1, body=f"the token is {TOKEN}")
    assert run(FakeLlm(keep_all), dry_run=True).rejected == 0
    assert Decisions().all() == []


def test_dry_run_shows_invalid_and_undecided(memory_repo: Path):
    submit(1)
    submit(2)
    summary = run(FakeLlm(lambda m: answer(decision(sid(1), ops=[entry_op("topic/jj/x.md", kind="nonsense")]))), dry_run=True)
    assert summary.text is not None
    doc = json.loads(summary.text)
    assert [(d["key"], d["outcome"]) for d in doc["decisions"]] == [(sid(1), "invalid")]
    assert "kind" in doc["decisions"][0]["errors"][0]
    assert doc["undecided"] == [sid(2)]
    assert Inbox().count() == 2


def test_print_prompt_does_not_call_the_model(memory_repo: Path):
    submit(1)
    llm = FakeLlm(keep_all)
    summary = run(llm, print_prompt=True)
    assert llm.calls == []
    assert summary.text is not None
    assert "# You are the knowledge curator" in summary.text
    assert "# Curator run r-20261006T160000Z" in summary.text
    assert sid(1) in summary.text
    assert "@@" not in summary.text
    assert Inbox().count() == 1
    assert Decisions().all() == []


def test_print_prompt_works_without_submissions(memory_repo: Path):
    summary = run(FakeLlm(), print_prompt=True, weekly=True)
    assert summary.text is not None and "mode: weekly" in summary.text


# weekly


def test_a_weekly_run_asks_even_without_submissions(memory_repo: Path):
    seed_entry(memory_repo)
    verify = decision(None, "maintain", [{"op": "verified", "path": "topic/jj/seed.md"}], reason="still true")
    llm = FakeLlm(lambda m: answer(verify))
    summary = run(llm, weekly=True)
    assert (summary.mode, summary.applied, summary.skipped) == ("weekly", 1, None)
    assert "mode: weekly" in llm.calls[0].message
    assert Store(memory_repo).read("topic/jj/seed.md").last_verified == "2026-10-06"
    assert sh(memory_repo, "log", "-n2", "--format=%(trailers:key=Submission,valueonly)").split() == ["-"]
    [d] = Decisions().all()
    assert (d.id, d.key, d.outcome) == (None, "m-r-20261006T160000Z-1", "applied")


def test_an_intake_run_without_submissions_is_idle(memory_repo: Path):
    seed_entry(memory_repo)
    llm = FakeLlm(keep_all)
    assert run(llm).skipped == "idle"
    assert llm.calls == []


def test_a_weekly_run_of_an_empty_store_is_idle(memory_repo: Path):
    llm = FakeLlm(keep_all)
    assert run(llm, weekly=True).skipped == "idle"
    assert llm.calls == []


def test_maintain_is_invalid_in_an_intake_run(memory_repo: Path):
    submit(1)
    summary = run(FakeLlm(lambda m: answer(decision(None, "maintain"))))
    assert summary.invalid == 2  # the maintain decision, and the record it left undecided
    assert [d.outcome for d in Decisions().all()] == ["invalid", "deferred"]


# retention


def aged(name: str, **changes: object) -> Entry:
    """An entry of topic/jj, created long ago and verified five days before NOW; `changes` replace fields."""
    base = Entry(
        name=name, description=f"About {name}", kind="convention", scope="topic/jj", tags=(), confidence="medium",
        trust="agent", status="active", created="2026-01-01", updated="2026-01-01", last_verified="2026-10-01",
        verify=None, related=(),
        sources=(Source("2026-01-01", "architect", None, "agent", "s-20260101T000000Z-000000", "first"),),
        body="Old body.",
    )  # fmt: skip
    return replace(base, **changes)


def seed(repo: Path, *entries: Entry) -> None:
    for e in entries:
        Store(repo).write(e)
    Git(repo, locks.memory_lock()).commit([e.rel for e in entries], "seed")


def seed_long_ago(monkeypatch: pytest.MonkeyPatch, repo: Path, *entries: Entry) -> None:
    """Seed with commits from 2020, so that nothing in the store 'changed in the last 7 days'."""
    for var in ("GIT_AUTHOR_DATE", "GIT_COMMITTER_DATE"):
        monkeypatch.setenv(var, "2020-01-01T00:00:00Z")
    seed(repo, *entries)
    for var in ("GIT_AUTHOR_DATE", "GIT_COMMITTER_DATE"):
        monkeypatch.delenv(var)


def budget(repo: Path, **pairs: str) -> None:
    (repo / "SCOPES.toml").write_text("[budget]\n" + "".join(f"{k} = {v}\n" for k, v in pairs.items()))


def drop_commits(repo: Path) -> list[str]:
    return sh(repo, "log", "--grep=^knowledge: drop", "--format=%s").splitlines()


def tracked(repo: Path, scope: str) -> list[str]:
    return sh(repo, "ls-files", scope).splitlines()


def test_a_long_stale_entry_is_kept_and_flagged(memory_repo: Path):
    seed(memory_repo, aged("old", kind="fact", last_verified="2026-01-01"), aged("fine"))  # 278 days: stale after 120
    llm = FakeLlm(keep_all)
    assert run(llm).skipped == "idle"
    assert llm.calls == []
    assert tracked(memory_repo, "topic") == ["topic/jj/fine.md", "topic/jj/old.md"]
    assert drop_commits(memory_repo) == []
    index_text = (memory_repo / "KNOWLEDGE.md").read_text()
    assert "(fact, medium, stale)" in index_text
    assert "(convention, medium)" in index_text
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert not intent().exists()


def test_a_scope_over_its_budget_is_evicted_down_to_90_percent(memory_repo: Path):
    budget(memory_repo, topic="[3, 1000000]")
    dates = ["2026-09-30", "2026-09-20", "2026-09-10", "2026-08-30"]
    seed(memory_repo, *[aged(f"e{i}", last_verified=d) for i, d in enumerate(dates)])
    assert run(FakeLlm(keep_all)).skipped == "idle"
    assert tracked(memory_repo, "topic") == ["topic/jj/e0.md", "topic/jj/e1.md"]  # 4 -> 2: 3 is over 90 % of 3
    assert drop_commits(memory_repo) == ["knowledge: drop 2 entries (evicted)"]
    lines = sh(memory_repo, "log", "--grep=^knowledge: drop", "-n1", "--format=%b").splitlines()
    assert [ln.rsplit(" ", 1)[0] for ln in lines[:2]] == ["topic/jj/e3.md", "topic/jj/e2.md"]
    assert not rejected.path().exists()  # an eviction is not a verdict on the entry


def test_retention_runs_again_after_the_decisions(memory_repo: Path):
    budget(memory_repo, topic="[3, 1000000]")
    seed(memory_repo, *[aged(f"e{i}", last_verified=d) for i, d in enumerate(["2026-09-30", "2026-09-20", "2026-09-10"])])
    submit(1)
    summary = run(FakeLlm(keep_all))
    assert summary.applied == 1
    assert len(commits(memory_repo, sid(1))) == 1
    assert tracked(memory_repo, "topic") == ["topic/jj/e0.md", path_of(sid(1))]  # the new entry is in grace: the old ones go
    assert drop_commits(memory_repo) == ["knowledge: drop 2 entries (evicted)"]
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: update index"
    assert path_of(sid(1)) in (memory_repo / "KNOWLEDGE.md").read_text()


def test_the_entries_of_the_user_are_reported_and_kept(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    budget(memory_repo, topic="[2, 1000000]")
    seed(memory_repo, *[aged(f"u{i}", trust="user") for i in range(3)])
    submit(1)
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        summary = run(FakeLlm(keep_all))
    assert summary.applied == 1
    assert drop_commits(memory_repo) == []
    assert len(tracked(memory_repo, "topic")) == 4
    [event] = router.events  # told once: the second look after the decisions is the same day
    assert event["title"] == "knowledge: store over budget"
    for i in range(3):
        assert f"knowledge drop topic/jj/u{i}.md" in event["body"]


def test_a_crash_while_dropping_is_recovered_and_the_drop_made_once(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    budget(memory_repo, topic="[1, 1000000]")
    seed(memory_repo, aged("old", last_verified="2026-01-01"), aged("fine"))  # over budget: both go, the old one first
    fail_once(monkeypatch, Git, "commit")
    with pytest.raises(Crash):
        run(FakeLlm())
    assert intent().exists()
    assert not (memory_repo / "topic/jj/old.md").exists()  # deleted, not committed
    assert run(FakeLlm()).skipped == "idle"
    assert not intent().exists()
    assert not (memory_repo / "topic/jj/old.md").exists()
    assert drop_commits(memory_repo) == ["knowledge: drop 2 entries (evicted)"]  # once
    assert not rejected.path().exists()  # evictions leave no note
    assert sh(memory_repo, "status", "--porcelain", "--", ":!SCOPES.toml") == ""  # the budget is set up uncommitted


def test_the_index_marks_the_stale_entries(memory_repo: Path):
    seed(memory_repo, aged("old", kind="fact", last_verified="2026-05-01"), aged("fine"))
    run(FakeLlm())
    index_text = (memory_repo / "KNOWLEDGE.md").read_text()
    assert "(fact, medium, stale)" in index_text
    assert "(convention, medium)" in index_text


# weekly runs: when the model is asked, and with what


def test_a_quiet_store_is_not_worth_a_weekly_call(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    budget(memory_repo, topic="[10, 1000000]")
    seed_long_ago(monkeypatch, memory_repo, aged("a"), aged("b"))
    llm = FakeLlm()
    assert run(llm, weekly=True).skipped == "idle"
    assert llm.calls == []


def test_a_recently_changed_store_is_worth_a_weekly_call(memory_repo: Path):
    seed(memory_repo, aged("a"))
    llm = FakeLlm()
    assert run(llm, weekly=True).skipped is None
    assert len(llm.calls) == 1


def commit_architect(repo: Path, *rels: str) -> None:
    """The overview of the project dotfiles and the given files, as the architect writes them, committed now."""
    for rel in ("projects/dotfiles/overview.md", *rels):
        (repo / rel).parent.mkdir(parents=True, exist_ok=True)
        (repo / rel).write_text("# dotfiles\n")
    Git(repo, locks.memory_lock()).commit(["projects/dotfiles/overview.md", *rels], "architect")


def test_a_recent_change_of_the_architects_files_is_not_worth_a_weekly_call(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    budget(memory_repo, topic="[10, 1000000]")
    seed_long_ago(monkeypatch, memory_repo, aged("a"))
    commit_architect(memory_repo, "projects/dotfiles/notes/plan.md", "projects/dotfiles/log.md")
    llm = FakeLlm()
    assert run(llm, weekly=True).skipped == "idle"
    assert llm.calls == []


def test_a_recent_change_of_the_facts_of_a_project_is_worth_a_weekly_call(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    budget(memory_repo, topic="[10, 1000000]")
    seed_long_ago(monkeypatch, memory_repo, aged("a"))
    commit_architect(memory_repo)
    seed(memory_repo, aged("f", scope="projects/dotfiles/facts"))
    llm = FakeLlm()
    assert run(llm, weekly=True).skipped is None
    assert len(llm.calls) == 1


def test_a_stale_entry_with_a_verify_hint_is_worth_a_weekly_call(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    seed_long_ago(monkeypatch, memory_repo, aged("old", kind="fact", last_verified="2026-05-01", verify="jj --help"))
    llm = FakeLlm()
    assert run(llm, weekly=True).skipped is None
    assert "- topic/jj/old.md (verify: jj --help)" in llm.calls[0].message


def test_a_stale_entry_without_a_hint_is_not(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    seed_long_ago(monkeypatch, memory_repo, aged("old", kind="fact", last_verified="2026-05-01"))
    llm = FakeLlm()
    assert run(llm, weekly=True).skipped == "idle"
    assert llm.calls == []


def test_a_crowded_scope_is_worth_a_weekly_call(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    budget(memory_repo, topic="[5, 1000000]")
    seed_long_ago(monkeypatch, memory_repo, *[aged(f"e{i}") for i in range(4)])  # 4 of 5 is 80 %
    llm = FakeLlm()
    assert run(llm, weekly=True).skipped is None
    assert "| topic/jj | 4/5 |" in llm.calls[0].message


def test_submissions_are_worth_a_weekly_call(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    budget(memory_repo, topic="[10, 1000000]")
    seed_long_ago(monkeypatch, memory_repo, aged("a"))
    submit(1)
    llm = FakeLlm(keep_all)
    assert run(llm, weekly=True).applied == 1


def index_file(memory: Path, rows: list[tuple[str, Path]]) -> None:
    lines = ["| Slug | Status | Repo |", "|---|---|---|", *(f"| {slug} | active | {repo} |" for slug, repo in rows)]
    (memory / "INDEX.md").write_text("\n".join(lines) + "\n")


def test_the_weekly_prompt_lists_the_stale_entries_with_their_repos(memory_repo: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    repo = tmp_path / "repos" / "dotfiles"
    (repo / ".git").mkdir(parents=True)
    index_file(memory_repo, [("dotfiles", repo), ("gone", tmp_path / "repos" / "gone")])
    mine = Source("2026-05-01", "coder", "dotfiles", "agent", "s-20260501T000000Z-aaaaaa", "x")
    lost = Source("2026-05-01", "coder", "gone", "agent", "s-20260501T000000Z-bbbbbb", "x")
    seed_long_ago(
        monkeypatch, memory_repo,
        aged("a", kind="fact", last_verified="2026-05-01", verify="jj --help", sources=(mine, lost)),
        aged("b", kind="fact", last_verified="2026-05-02", verify="git status", sources=()),
        aged("c", kind="fact", last_verified="2026-05-03"),
    )  # fmt: skip
    llm = FakeLlm()
    run(llm, weekly=True)
    [call] = llm.calls
    assert call.add_dirs == (memory_repo, repo)  # a repo that does not exist is left out
    assert f"- topic/jj/a.md (verify: jj --help) repos: {repo}\n- topic/jj/b.md (verify: git status)\n" in call.message
    assert "topic/jj/c.md (verify" not in call.message  # no hint, nothing to re-check
    assert "(fact, medium, stale)" in call.message  # the index shows the flag


def test_at_most_five_repos_are_offered(memory_repo: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    rows = [(f"p{i}", tmp_path / "repos" / f"p{i}") for i in range(7)]
    for _, path in rows:
        (path / ".git").mkdir(parents=True)
    index_file(memory_repo, rows)
    seed_long_ago(
        monkeypatch, memory_repo,
        *[
            aged(
                f"s{i}", kind="fact", last_verified=f"2026-05-0{i + 1}", verify="v",
                sources=(Source("2026-05-01", "coder", f"p{i}", "agent", f"s-2026050100000{i}Z-aaaaaa", "x"),),
            )
            for i in range(7)
        ],
    )  # fmt: skip
    llm = FakeLlm()
    run(llm, weekly=True)
    [call] = llm.calls
    assert call.add_dirs == (memory_repo, *[path for _, path in rows[:5]])  # the longest unverified come first
    assert f"- topic/jj/s4.md (verify: v) repos: {rows[4][1]}\n" in call.message
    assert "- topic/jj/s5.md (verify: v)\n" in call.message  # listed, without a repo
    assert "topic/jj/s6.md (verify: v)\n" in call.message


def test_only_a_checkout_that_is_not_the_home_or_above_it_is_offered(memory_repo: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    home = tmp_path / "h" / "user"
    monkeypatch.setenv("HOME", str(home))
    git_repo, jj_repo, plain = tmp_path / "git", tmp_path / "jj", tmp_path / "plain"
    (git_repo / ".git").mkdir(parents=True)
    (jj_repo / ".jj").mkdir(parents=True)
    plain.mkdir()
    (home / ".git").mkdir(parents=True)
    (tmp_path / "h" / ".git").mkdir()  # above the home
    names = {"git": git_repo, "jj": jj_repo, "plain": plain, "home": home, "above": tmp_path / "h"}
    index_file(memory_repo, list(names.items()))
    seed_long_ago(
        monkeypatch, memory_repo,
        *[
            aged(
                f"s-{slug}", kind="fact", last_verified="2026-05-01", verify="v",
                sources=(Source("2026-05-01", "coder", slug, "agent", f"s-2026050100000{i}Z-aaaaaa", "x"),),
            )
            for i, slug in enumerate(names)
        ],
    )  # fmt: skip
    llm = FakeLlm()
    run(llm, weekly=True)
    [call] = llm.calls
    assert call.add_dirs == (memory_repo, git_repo, jj_repo)


def test_an_intake_prompt_has_no_stale_lines(memory_repo: Path):
    seed(memory_repo, aged("old", kind="fact", last_verified="2026-05-01", verify="jj --help"))
    submit(1)
    llm = FakeLlm(keep_all)
    run(llm)
    assert "(verify:" not in llm.calls[0].message
    assert llm.calls[0].add_dirs == (memory_repo,)


# crashes: whatever dies where, a submission has exactly one effect


class Crash(BaseException):  # not an Exception: a run does not survive it (an Exception in a decision is handled)
    pass


def fail_once(monkeypatch: pytest.MonkeyPatch, owner: type, name: str, on_call: int = 1) -> list[int]:
    """Make the `on_call`-th call of `owner.name` raise Crash, once. The returned list counts the calls."""
    real = getattr(owner, name)
    calls: list[int] = []

    def wrapper(*args: object, **kwargs: object) -> object:
        calls.append(1)
        if len(calls) == on_call:
            raise Crash(name)
        return real(*args, **kwargs)

    monkeypatch.setattr(owner, name, wrapper)
    return calls


def test_a_crash_before_the_commit_is_recovered_and_the_record_decided_again(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    fail_once(monkeypatch, Git, "commit")
    llm = FakeLlm(keep_all)
    with pytest.raises(Crash):
        run(llm)
    assert intent().exists()  # the decision was half-way
    assert (memory_repo / path_of(sid(1))).exists()
    assert Inbox().has(sid(1))
    assert Decisions().all() == []
    summary = run(llm)
    assert summary.applied == 1
    assert len(llm.calls) == 2  # decided again
    assert len(commits(memory_repo, sid(1))) == 1
    assert not intent().exists()
    assert [(d.id, d.outcome) for d in Decisions().all()] == [(sid(1), "applied")]
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert Inbox().count() == 0


def test_a_crash_after_the_commit_is_found_by_its_trailer(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    fail_once(monkeypatch, Decisions, "append")
    llm = FakeLlm(keep_all)
    with pytest.raises(Crash):
        run(llm)
    assert len(commits(memory_repo, sid(1))) == 1
    assert Decisions().all() == []
    assert Inbox().has(sid(1))
    summary = run(llm)
    assert len(llm.calls) == 1  # not asked again
    assert (summary.skipped, summary.applied) == ("idle", 1)
    assert len(commits(memory_repo, sid(1))) == 1
    [d] = Decisions().all()
    assert (d.id, d.outcome, d.commit) == (sid(1), "applied", commits(memory_repo, sid(1))[0])
    assert "trailer" in " ".join(d.notes)
    assert Inbox().count() == 0


def test_a_crash_before_the_inbox_file_is_removed_does_not_apply_twice(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    fail_once(monkeypatch, Inbox, "remove")
    llm = FakeLlm(keep_all)
    with pytest.raises(Crash):
        run(llm)
    assert len(commits(memory_repo, sid(1))) == 1
    assert [(d.id, d.outcome) for d in Decisions().all()] == [(sid(1), "applied")]  # decided, but the file is left
    assert Inbox().has(sid(1))
    summary = run(llm)
    assert summary.skipped == "idle"
    assert len(llm.calls) == 1
    assert len(commits(memory_repo, sid(1))) == 1
    assert [(d.id, d.outcome) for d in Decisions().all()] == [(sid(1), "applied")]
    assert Inbox().count() == 0


def test_a_crash_in_the_second_decision_keeps_the_first(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    submit(2)
    fail_once(monkeypatch, Git, "commit", on_call=2)
    llm = FakeLlm(keep_all)
    with pytest.raises(Crash):
        run(llm)
    assert len(commits(memory_repo, sid(1))) == 1
    assert commits(memory_repo, sid(2)) == []
    summary = run(llm)
    assert summary.applied == 1
    assert sid(1) not in llm.calls[1].message  # only the record that is left
    assert sid(2) in llm.calls[1].message
    for n in (1, 2):
        assert len(commits(memory_repo, sid(n))) == 1
    assert [(d.id, d.outcome) for d in Decisions().all()] == [(sid(1), "applied"), (sid(2), "applied")]
    assert Inbox().count() == 0


def test_a_crash_after_a_retry_was_queued_curates_the_record_once(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    fail_once(monkeypatch, Decisions, "append")  # the line of the deferred decision
    with pytest.raises(Crash):
        run(FakeLlm(invalid_all))
    assert [(r.id, r.attempt) for r in Inbox().pending(10**6)] == [(sid(1), 1)]  # the file holds the retry, only one
    llm = FakeLlm(keep_all)
    assert run(llm).applied == 1
    assert llm.calls[0].message.count(sid(1)) == 1
    assert len(commits(memory_repo, sid(1))) == 1


# the trust of the batch: a call gets the records of one trust


def test_a_run_curates_the_records_of_one_trust_and_leaves_the_others_for_the_next(memory_repo: Path):
    submit(1, event="event:gitlab.note")  # untrusted, and the oldest
    submit(2)
    llm = FakeLlm(keep_all)
    first = run(llm)
    assert (first.records, first.applied, first.waiting) == (2, 1, 1)
    assert sid(1) in llm.calls[0].message and sid(2) not in llm.calls[0].message
    e = Store(memory_repo).read(path_of(sid(1)))
    assert (e.trust, [s.trust for s in e.sources]) == ("untrusted", ["untrusted"])
    assert [(r.id, r.attempt) for r in Inbox().pending(10**6)] == [(sid(2), 0)]  # untouched
    second = run(llm)
    assert (second.records, second.applied, second.waiting) == (1, 1, 0)
    assert sid(1) not in llm.calls[1].message and sid(2) in llm.calls[1].message
    assert Store(memory_repo).read(path_of(sid(2))).trust == "agent"
    assert Inbox().count() == 0
    assert run(llm).skipped == "idle"


def test_the_records_of_the_user_are_curated_first_and_alone(memory_repo: Path):
    seed(memory_repo, aged("mine", trust="user"))
    submit(1)  # the oldest, and an agent's
    submit_user(2)
    submit(3)
    llm = FakeLlm(lambda m: answer(decision(sid(2), "merge", [entry_op("topic/jj/mine.md")])))
    first = run(llm)
    assert (first.applied, first.invalid, first.waiting) == (1, 0, 2)
    assert sid(2) in llm.calls[0].message
    assert sid(1) not in llm.calls[0].message and sid(3) not in llm.calls[0].message
    e = Store(memory_repo).read("topic/jj/mine.md")  # the user's record rewrote the user's entry
    assert (e.trust, e.body) == ("user", "Rule. Why. Example.")
    assert [(r.id, r.attempt) for r in Inbox().pending(10**6)] == [(sid(1), 0), (sid(3), 0)]
    second = run(FakeLlm(keep_all))
    assert (second.applied, second.waiting) == (2, 0)
    assert Inbox().count() == 0


def test_a_failed_call_is_an_attempt_of_the_curated_records_only(memory_repo: Path):
    submit_user(1)
    submit(2)
    summary = run(failing())
    assert (summary.skipped, summary.invalid, summary.waiting) == ("llm-failure", 1, 1)
    assert attempts() == [(sid(1), 1), (sid(2), 0)]


def test_a_weekly_maintain_decision_is_applied_with_an_untrusted_record_in_the_batch(memory_repo: Path):
    seed_entry(memory_repo)
    submit(1, event="event:gitlab.note")
    verify = decision(None, "maintain", [{"op": "verified", "path": "topic/jj/seed.md"}], reason="still true")
    summary = run(FakeLlm(lambda m: answer(decision(sid(1), "reject"), verify)), weekly=True)
    assert (summary.applied, summary.rejected) == (1, 1)
    assert Store(memory_repo).read("topic/jj/seed.md").last_verified == "2026-10-06"


def test_a_weekly_maintain_decision_is_applied_without_an_untrusted_record(memory_repo: Path):
    seed_entry(memory_repo)
    submit(1)
    verify = decision(None, "maintain", [{"op": "verified", "path": "topic/jj/seed.md"}], reason="still true")
    summary = run(FakeLlm(lambda m: answer(decision(sid(1), "reject"), verify)), weekly=True)
    assert summary.applied == 1
    assert Store(memory_repo).read("topic/jj/seed.md").last_verified == "2026-10-06"


def test_a_user_record_may_rewrite_an_entry_of_the_user(memory_repo: Path):
    seed(memory_repo, aged("mine", trust="user"))
    submit_user(1)
    summary = run(FakeLlm(lambda m: answer(decision(sid(1), "merge", [entry_op("topic/jj/mine.md")]))))
    assert summary.applied == 1
    assert Store(memory_repo).read("topic/jj/mine.md").trust == "user"


def test_an_entry_a_user_record_makes_is_the_users_even_with_an_agent_record_pending(memory_repo: Path):
    submit_user(1)
    submit(2)
    summary = run(FakeLlm(keep_all))
    assert (summary.applied, summary.waiting) == (1, 1)
    made = Store(memory_repo).read(path_of(sid(1)))
    assert (made.trust, [s.trust for s in made.sources]) == ("user", ["user"])


def test_a_record_rejected_for_a_secret_does_not_decide_the_trust_of_the_batch(memory_repo: Path):
    submit_user(1)
    submit(2, body=f"the token is {TOKEN}")  # rejected as a secret: the model never sees it
    summary = run(FakeLlm(keep_all))
    assert (summary.applied, summary.rejected, summary.waiting) == (1, 1, 0)
    assert Store(memory_repo).read(path_of(sid(1))).trust == "user"


# a refused decision comes back with its errors


def test_a_refused_decision_comes_back_with_its_errors(memory_repo: Path):
    seed(memory_repo, aged("mine", trust="user"))
    submit(1)
    llm = FakeLlm(lambda m: answer(decision(sid(1), "merge", [entry_op("topic/jj/mine.md")])))
    run(llm)
    [rec] = Inbox().pending(10**6)
    assert rec.attempt == 1
    assert len(rec.last_errors) == 1 and "an entry of the user" in rec.last_errors[0]
    assert "last_errors" not in llm.calls[0].message  # nothing was refused yet
    run(llm)
    assert "last_errors" in llm.calls[1].message
    assert "an entry of the user" in llm.calls[1].message  # the model is told what was wrong
    [rec] = Inbox().pending(10**6)
    assert rec.attempt == 2 and len(rec.last_errors) == 1


def test_a_record_that_is_out_of_attempts_keeps_the_last_errors_in_its_failed_file(memory_repo: Path):
    submit(1)
    llm = FakeLlm(invalid_all)
    for _ in range(3):
        run(llm)
    failed = json.loads((Inbox().dir / f"{sid(1)}.json.failed").read_text())
    assert failed["attempt"] == 2
    assert "kind" in " ".join(failed["last_errors"])


def test_an_undecided_record_is_told_so(memory_repo: Path):
    submit(1)
    submit(2)
    run(FakeLlm(first_only))
    [rec] = Inbox().pending(10**6)
    assert (rec.id, rec.last_errors) == (sid(2), ("undecided",))


def test_a_failed_call_leaves_the_last_errors_of_a_record_as_they_were(memory_repo: Path):
    rec = submit(1)
    Inbox().put(replace(rec, last_errors=("an earlier refusal",)))
    run(failing())
    [after] = Inbox().pending(10**6)
    assert (after.attempt, after.last_errors) == (1, ("an earlier refusal",))


def test_a_long_error_is_cut_short(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    real = Git.commit

    def commit(
        self: Git, paths: Sequence[str], subject: str, body: str = "", trailers: Mapping[str, str] | None = None
    ) -> str | None:
        if subject.startswith("knowledge: create"):
            raise ValueError("x" * 5000)
        return real(self, paths, subject, body, trailers)

    monkeypatch.setattr(Git, "commit", commit)
    run(FakeLlm(keep_all))
    [rec] = Inbox().pending(10**6)
    assert all(len(e) <= curate.MAX_ERROR_CHARS for e in rec.last_errors)
    assert "ValueError" in rec.last_errors[0]


# records and decisions that must not make a run fail again and again


def break_creates(monkeypatch: pytest.MonkeyPatch) -> None:
    """Every commit of a `create` decision fails; the others (index, retention) work."""
    real = Git.commit

    def commit(
        self: Git, paths: Sequence[str], subject: str, body: str = "", trailers: Mapping[str, str] | None = None
    ) -> str | None:
        if subject.startswith("knowledge: create"):
            raise GitError("commit", "boom")
        return real(self, paths, subject, body, trailers)

    monkeypatch.setattr(Git, "commit", commit)


def test_a_decision_that_crashes_is_recovered_at_once_and_retried(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    submit(2)
    break_creates(monkeypatch)
    llm = FakeLlm(keep_all)
    summary = run(llm)
    assert (summary.applied, summary.invalid, summary.skipped) == (0, 2, None)  # the run itself went on
    assert not intent().exists()  # recovered before the next decision, not by the next run
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert not any((memory_repo / path_of(sid(n))).exists() for n in (1, 2))
    assert sorted(r.attempt for r in Inbox().pending(10**6)) == [1, 1]
    notes = " ".join(Decisions().all()[0].notes)
    assert "crashed" in notes and "boom" in notes
    run(llm)
    last = run(llm)  # the third try: a crash counts like an invalid answer
    assert (last.invalid, last.failed) == (0, 2)
    assert [d.outcome for d in Decisions().all()] == ["deferred"] * 4 + ["failed"] * 2
    assert Inbox().count() == 0
    assert not intent().exists()
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_a_crashed_decision_does_not_stop_the_next_one(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    submit(2)
    real = Git.commit

    def commit(
        self: Git, paths: Sequence[str], subject: str, body: str = "", trailers: Mapping[str, str] | None = None
    ) -> str | None:
        if path_of(sid(1)) in paths:
            raise ValueError("embedded null byte")  # whatever a poisoned record makes of the call
        return real(self, paths, subject, body, trailers)

    monkeypatch.setattr(Git, "commit", commit)
    summary = run(FakeLlm(keep_all))
    assert (summary.applied, summary.invalid) == (1, 1)
    assert len(commits(memory_repo, sid(2))) == 1
    assert commits(memory_repo, sid(1)) == []
    assert not (memory_repo / path_of(sid(1))).exists()
    assert "ValueError" in " ".join(Decisions().all()[0].notes)


def test_a_poisoned_file_in_the_inbox_is_set_aside(memory_repo: Path):
    rec = submit(1)
    bad = to_obj(replace(rec, id=sid(2)))
    bad["origin"] = {"via": "cli", "agent": "co\x00der", "cwd": None, "event": None, "session": None}
    poisoned = Inbox().dir / f"{sid(2)}.json"
    poisoned.write_text(json.dumps(bad) + "\n", encoding="utf-8")
    summary = run(FakeLlm(keep_all))
    assert (summary.records, summary.applied) == (1, 1)
    assert Inbox().count() == 0
    assert not poisoned.exists()
    assert poisoned.with_name(f"{poisoned.name}.bad").exists()
    assert not (memory_repo / path_of(sid(2))).exists()


def failing() -> FakeLlm:
    return FakeLlm(error=LlmError("claude exited with status 1"))


def attempts() -> list[tuple[str, int]]:
    return [(r.id, r.attempt) for r in Inbox().pending(10**6)]


def test_a_failed_call_defers_every_record_of_its_batch(memory_repo: Path):
    submit(1)
    submit(2)
    summary = run(failing())
    assert (summary.skipped, summary.invalid, summary.failed) == ("llm-failure", 2, 0)
    lines = Decisions().all()
    assert [(d.id, d.outcome) for d in lines] == [(sid(1), "deferred"), (sid(2), "deferred")]
    assert lines[0].notes == ("attempt 1 of 2", "claude exited with status 1")
    assert Decisions().decided_ids() == set()
    assert attempts() == [(sid(1), 1), (sid(2), 1)]  # each file holds the record with one more attempt


def test_an_unusable_answer_defers_the_records_too(memory_repo: Path):
    submit(1)
    assert run(FakeLlm(lambda m: "I could not decide.")).skipped == "bad-response"
    [d] = Decisions().all()
    assert (d.id, d.outcome) == (sid(1), "deferred")
    assert "unusable answer" in d.notes[1]
    assert attempts() == [(sid(1), 1)]


def test_three_failed_calls_end_a_record(memory_repo: Path):
    submit(1)
    llm = failing()
    for _ in range(3):
        summary = run(llm)
    assert len(llm.calls) == 3
    assert (summary.skipped, summary.failed) == ("llm-failure", 1)
    assert [d.outcome for d in Decisions().all()] == ["deferred", "deferred", "failed"]
    assert Decisions().decided_ids() == set()
    assert Inbox().count() == 0
    assert commits(memory_repo, sid(1)) == [] and not (memory_repo / "topic").exists()
    quiet = FakeLlm(keep_all)
    assert run(quiet).skipped == "idle"
    assert quiet.calls == []  # no fourth call
    submit(2)
    assert run(quiet).applied == 1  # what comes after is curated as usual


def test_a_record_out_of_attempts_is_kept_as_failed_and_can_be_moved_back(memory_repo: Path):
    submit(1)
    llm = failing()
    for _ in range(3):
        run(llm)
    failed = Inbox().dir / f"{sid(1)}.json.failed"
    assert failed.is_file()
    assert Inbox().state(sid(1)) == "failed"
    assert status(sid(1), Decisions(), Inbox().state(sid(1)))["state"] == "failed"
    failed.rename(failed.with_name(f"{sid(1)}.json"))  # the user's `mv`
    assert Inbox().state(sid(1)) == "pending"
    summary = run(FakeLlm(keep_all))
    assert summary.applied == 1  # curated once more
    assert Inbox().state(sid(1)) is None
    assert [d.outcome for d in Decisions().all()][-1] == "applied"


def test_a_failed_dry_run_changes_nothing(memory_repo: Path):
    submit(1)
    assert run(failing(), dry_run=True).skipped == "llm-failure"
    assert Decisions().all() == []
    assert attempts() == [(sid(1), 0)]


# the commands


class Runner:
    def __init__(self, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
        self.monkeypatch = monkeypatch
        self.capsys = capsys

    def __call__(self, *argv: str, stdin: str = "") -> tuple[int, str]:
        self.monkeypatch.setattr("sys.argv", ["knowledge", *argv])
        self.monkeypatch.setattr("sys.stdin", io.StringIO(stdin))
        code = 0
        try:
            cli.main()
        except SystemExit as e:
            code = int(e.code or 0)
        return code, self.capsys.readouterr().out


@pytest.fixture
def knowledge(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> Runner:
    return Runner(monkeypatch, capsys)


def event(n: int) -> str:
    origin = {"via": "subagent-stop", "agent": "coder", "cwd": None, "event": None, "session": None}
    return json.dumps({"type": "knowledge.submit", "id": sid(n), "title": f"note {n}", "body": "Rule.", "origin": origin})


def test_the_curate_command_prints_the_summary(knowledge: Runner, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    monkeypatch.setattr(curate, "make_llm", lambda: FakeLlm(keep_all))
    code, out = knowledge("curate")
    assert code == 0
    assert out.count("\n") == 1  # one JSON line
    doc = json.loads(out)
    assert (doc["mode"], doc["records"], doc["applied"], doc["skipped"]) == ("intake", 1, 1, None)
    assert len(commits(memory_repo, sid(1))) == 1


def test_the_curate_command_exits_1_when_the_model_fails(knowledge: Runner, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    monkeypatch.setattr(curate, "make_llm", lambda: FakeLlm(error=LlmError("down")))
    code, out = knowledge("curate")
    assert code == 1
    assert json.loads(out)["skipped"] == "llm-failure"


def test_the_curate_command_exits_0_when_busy(knowledge: Runner, memory_repo: Path):
    with FileLock(locks.curator_lock(), 0.0):
        code, out = knowledge("curate", "--if-idle")
    assert code == 0
    assert json.loads(out)["skipped"] == "busy"


@pytest.mark.parametrize("flags", [["--mode", "weekly"], ["--weekly"]])
def test_the_curate_command_prints_the_prompt(knowledge: Runner, memory_repo: Path, flags: list[str]):
    code, out = knowledge("curate", *flags, "--print-prompt")
    assert code == 0
    assert "# You are the knowledge curator" in out
    assert "mode: weekly" in out


def test_the_curate_command_rejects_an_unknown_mode(knowledge: Runner):
    assert knowledge("curate", "--mode", "daily") == (2, "")


def test_the_curate_command_goes_on_too_but_not_after_a_failed_call(knowledge: Runner, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit_user(1)
    submit(2)
    llm = FakeLlm(keep_all)
    monkeypatch.setattr(curate, "make_llm", lambda: llm)
    code, out = knowledge("curate")
    assert code == 0
    assert len(llm.calls) == 2
    assert (json.loads(out)["applied"], json.loads(out)["waiting"]) == (1, 0)  # the summary of the last run
    assert Inbox().count() == 0
    submit_user(3)
    submit(4)
    failing_llm = FakeLlm(error=LlmError("down"))
    monkeypatch.setattr(curate, "make_llm", lambda: failing_llm)
    code, out = knowledge("curate")
    assert (code, json.loads(out)["skipped"]) == (1, "llm-failure")
    assert len(failing_llm.calls) == 1  # the next run waits for the timers
    assert attempts() == [(sid(3), 1), (sid(4), 0)]


def test_a_dry_run_curates_one_trust_and_does_not_go_on(knowledge: Runner, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit_user(1)
    submit(2)
    llm = FakeLlm(keep_all)
    monkeypatch.setattr(curate, "make_llm", lambda: llm)
    code, out = knowledge("curate", "--dry-run")
    assert code == 0 and len(llm.calls) == 1
    assert sid(1) in llm.calls[0].message and sid(2) not in llm.calls[0].message
    assert json.loads(out)["summary"]["waiting"] == 0  # a read-only run leaves nothing behind
    assert Inbox().count() == 2


def test_receive_only_stores_the_submission(knowledge: Runner, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    llm = FakeLlm(keep_all)
    monkeypatch.setattr(curate, "make_llm", lambda: llm)
    for n in (1, 2, 3):
        code, out = knowledge("receive", stdin=event(n))
        assert (code, json.loads(out)) == (0, {"id": sid(n), "stored": True})
    assert llm.calls == []  # only the timers start the curator
    assert Inbox().count() == 3


# skills

SKILL_PATH = "global/unions.md"


IDEA_PATH = "skill-ideas/strings.md"


def skill_add(sources: list[str]) -> dict:
    return {
        "op": "skill", "name": "strings", "description": "Use when choosing string unions.",
        "body": "Prefer unions.", "summary": "add strings", "sources": sources,
    }  # fmt: skip


def test_a_skill_idea_is_written_and_the_rest_of_the_decision_applies(memory_repo: Path):
    submit(1)
    llm = FakeLlm(lambda m: answer(decision(sid(1), "create", [entry_op(SKILL_PATH), skill_add([SKILL_PATH])])))
    summary = run(llm)  # the skills dir of the tests does not exist: no skills to read
    assert (summary.applied, summary.skipped) == (1, None)
    [d] = Decisions().all()
    assert (d.id, d.outcome, d.paths) == (sid(1), "applied", (SKILL_PATH, IDEA_PATH))
    assert (memory_repo / SKILL_PATH).is_file()
    text = (memory_repo / IDEA_PATH).read_text()
    assert text.startswith("---\nname: strings\ndescription: Use when choosing string unions.\n---\n\nPrefer unions.\n")
    assert f"2026-10-06: new skill\nwhy: add strings\nsources: {SKILL_PATH}\n" in text
    [sha] = commits(memory_repo, sid(1))  # one commit holds the entry and the idea
    assert sh(memory_repo, "show", "--name-only", "--format=%s", sha).splitlines()[0] == f"knowledge: create {SKILL_PATH} +1"
    assert IDEA_PATH in sh(memory_repo, "show", "--name-only", "--format=", sha)
    index = (memory_repo / "KNOWLEDGE.md").read_text()
    assert SKILL_PATH in index and "skill-ideas" not in index  # an idea is not an entry
    assert llm.calls[0].add_dirs == (memory_repo,)  # no skills directory to read
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_an_idea_alone_has_its_own_subject(memory_repo: Path):
    submit(1)
    run(FakeLlm(lambda m: answer(decision(sid(1), "skill", [skill_add([])]))))
    [sha] = commits(memory_repo, sid(1))
    assert sh(memory_repo, "show", "--no-patch", "--format=%s", sha) == "knowledge: skill idea strings"
    assert (memory_repo / IDEA_PATH).is_file()


def test_a_new_idea_sends_no_notification(memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    submit(1)
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        run(FakeLlm(lambda m: answer(decision(sid(1), "skill", [skill_add([])]))))
    assert (memory_repo / IDEA_PATH).is_file()
    assert router.events == []  # the footer of the session start tells the user

    submit(2)
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        run(FakeLlm(keep_all))
    assert router.events == []


def test_the_skills_dir_is_readable_by_the_model(memory_repo: Path):
    skills = config.skills_dir()
    (skills / "x").mkdir(parents=True)
    (skills / "x" / "SKILL.md").write_text("---\nname: x\ndescription: Use when x.\n---\n\nDo x.\n")
    llm = FakeLlm()
    submit(1)
    run(llm)
    assert llm.calls[0].add_dirs == (memory_repo, skills)


def test_a_written_skill_idea_is_shown_to_the_next_run(memory_repo: Path):
    submit(1)
    run(FakeLlm(lambda m: answer(decision(sid(1), "skill", [skill_add([])]))))
    llm = FakeLlm()
    submit(2)
    run(llm)
    title = "## Skill ideas in skill-ideas/ (drafts the user has not taken yet; overwrite one only to improve it with new evidence)"
    assert f"{title}\n\n- skill-ideas/strings.md\n\n" in llm.calls[0].message


def test_the_rejected_notes_are_shown_to_the_run(memory_repo: Path):
    rejected.note("topic/jj/old.md (refuted): jj has no such flag", datetime.date(2026, 10, 1))
    llm = FakeLlm()
    submit(1)
    run(llm)
    title = "## Rejected knowledge (refuted, obsolete or dropped by the user; do not re-add without new, stronger evidence)"
    assert f"{title}\n\n- 2026-10-01 topic/jj/old.md (refuted): jj has no such flag\n\n" in llm.calls[0].message
