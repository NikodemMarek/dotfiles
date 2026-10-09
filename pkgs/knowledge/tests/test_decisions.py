import datetime
import json
from dataclasses import replace

import pytest

from knowledge.decisions import Decision, Decisions, status
from knowledge.inbox import Inbox
from knowledge.records import Record, from_event

NOW = datetime.datetime(2026, 10, 6, 12, 0, tzinfo=datetime.UTC)


def decision(sid: str | None = "s-20261006T153201Z-a1b2c3", outcome: str = "applied", at: str = "2026-10-06T12:00:00Z", **changes: object) -> Decision:
    base = Decision(
        id=sid,
        key=sid or "m-r-1",
        run="r-1",
        at=at,
        verdict="create",
        reason="new gotcha",
        paths=("topic/jj/absorb.md",),
        commit="abc123",
        outcome=outcome,
        notes=(),
    )
    return replace(base, **changes)


def record(sid: str) -> Record:
    return from_event({"id": sid, "title": "t", "body": "b", "origin": {"via": "cli"}}, via_router=True)


def test_append_and_read_back():
    log = Decisions()
    d = decision(notes=("a note",))
    log.append(d)
    log.append(decision(None, "rejected", paths=(), commit=None))
    assert log.all()[0] == d
    assert len(log.all()) == 2


def test_the_log_is_private():
    log = Decisions()
    log.append(decision())
    assert log.path.stat().st_mode & 0o777 == 0o600


def test_a_missing_log_is_empty():
    log = Decisions()
    assert log.all() == []
    assert log.decided_ids() == set()
    assert log.trim() == 0
    assert not log.path.exists()


def test_decided_ids_are_applied_and_rejected_only():
    log = Decisions()
    log.append(decision("s-20261006T000000Z-000001", "applied"))
    log.append(decision("s-20261006T000000Z-000002", "deferred"))
    log.append(decision("s-20261006T000000Z-000003", "rejected"))
    log.append(decision("s-20261006T000000Z-000004", "failed"))
    log.append(decision("s-20261006T000000Z-000005", "invalid"))
    log.append(decision(None, "applied"))
    assert log.decided_ids() == {"s-20261006T000000Z-000001", "s-20261006T000000Z-000003"}


def test_a_deferred_submission_that_is_decided_later_counts_as_decided():
    sid = "s-20261006T000000Z-000002"
    log = Decisions()
    log.append(decision(sid, "deferred"))
    log.append(decision(sid, "rejected"))
    assert log.decided_ids() == {sid}


def test_trim_drops_what_is_older_than_the_window():
    log = Decisions()
    log.append(decision("s-20260101T000000Z-000001", at="2026-07-08T11:59:59Z"))  # 90 days and a second ago
    log.append(decision("s-20260101T000000Z-000002", at="2026-07-08T12:00:00Z"))
    log.append(decision("s-20260101T000000Z-000003", at="2026-10-06T11:00:00+00:00"))
    assert log.trim(now=NOW) == 1
    assert [d.id for d in log.all()] == ["s-20260101T000000Z-000002", "s-20260101T000000Z-000003"]
    assert log.trim(now=NOW) == 0
    assert log.path.stat().st_mode & 0o777 == 0o600


def test_trim_can_empty_the_log():
    log = Decisions()
    log.append(decision(at="2025-01-01T00:00:00Z"))
    assert log.trim(now=NOW) == 1
    assert log.all() == []


def test_unparsable_lines_are_skipped(caplog: pytest.LogCaptureFixture):
    log = Decisions()
    log.append(decision())
    wrong_outcome = json.dumps({"id": None, "key": "k", "run": "r", "at": "2026-10-06T12:00:00Z", "verdict": "create", "outcome": "nope"})
    with log.path.open("a") as f:
        f.write(f'not json\n{json.dumps({"id": "x"})}\n{wrong_outcome}\n')
    assert len(log.all()) == 1
    assert "skipping" in caplog.text


def test_a_torn_last_line_is_skipped(caplog: pytest.LogCaptureFixture):
    log = Decisions()
    log.append(decision("s-20261006T000000Z-000001"))
    with log.path.open("a") as f:
        f.write('{"id": "torn')
    assert [d.id for d in log.all()] == ["s-20261006T000000Z-000001"]
    assert "skipping" in caplog.text


def test_an_append_after_a_torn_tail_reads_back():
    log = Decisions()
    log.append(decision("s-20261006T000000Z-000001"))
    with log.path.open("a") as f:
        f.write('{"id": "torn')  # a crash mid-write: no newline
    log.append(decision("s-20261006T000000Z-000002"))
    assert [d.id for d in log.all()] == ["s-20261006T000000Z-000001", "s-20261006T000000Z-000002"]


def test_unicode_line_separators_do_not_split_a_line():
    log = Decisions()
    log.append(decision(reason="a b\x85c"))
    assert [d.reason for d in log.all()] == ["a b\x85c"]


# status


def test_status_of_a_decided_submission_comes_from_the_latest_decision():
    sid = "s-20261006T153201Z-a1b2c3"
    log = Decisions()
    log.append(decision(sid, "deferred", commit=None, notes=("attempt 1 of 2",)))
    log.append(decision(sid, "applied", notes=("n",)))
    got = status(sid, log, None)
    assert got == {
        "id": sid,
        "state": "applied",
        "key": sid,
        "run": "r-1",
        "at": "2026-10-06T12:00:00Z",
        "verdict": "create",
        "reason": "new gotcha",
        "paths": ["topic/jj/absorb.md"],
        "commit": "abc123",
        "notes": ["n"],
    }


@pytest.mark.parametrize("outcome", ["applied", "rejected", "invalid", "failed"])
def test_status_state_is_the_outcome(outcome: str):
    sid = "s-20261006T153201Z-a1b2c3"
    log = Decisions()
    log.append(decision(sid, outcome))
    assert status(sid, log, None)["state"] == outcome


def test_status_pending_when_the_id_is_in_the_inbox():
    inbox = Inbox()
    old, new = record("s-20261006T000000Z-000001"), record("s-20261006T000000Z-000002")
    inbox.put(old)
    inbox.put(new)
    inbox.remove(old.id)
    log = Decisions()
    assert status(new.id, log, inbox.state(new.id)) == {"id": new.id, "state": "pending"}
    assert status(old.id, log, inbox.state(old.id)) == {"id": old.id, "state": "unknown"}


def test_a_file_in_the_inbox_wins_over_the_decisions():
    sid = "s-20261006T153201Z-a1b2c3"
    log = Decisions()
    log.append(decision(sid, "failed"))
    assert status(sid, log, "pending") == {"id": sid, "state": "pending"}


def test_status_of_a_deferred_submission_with_its_file_gone_is_unknown():
    sid = "s-20261006T153201Z-a1b2c3"
    log = Decisions()
    log.append(decision(sid, "deferred"))
    assert status(sid, log, None) == {"id": sid, "state": "unknown"}


def test_a_decision_wins_over_a_file_set_aside():
    sid = "s-20261006T000000Z-000001"
    log = Decisions()
    log.append(decision(sid, "rejected"))
    assert status(sid, log, "failed")["state"] == "rejected"


def test_status_of_a_file_set_aside_without_a_decision():
    sid = "s-20261006T153201Z-a1b2c3"
    assert status(sid, Decisions(), "failed") == {"id": sid, "state": "failed"}
    assert status(sid, Decisions(), "bad") == {"id": sid, "state": "bad"}
    log = Decisions()
    log.append(decision(sid, "deferred"))
    assert status(sid, log, "bad") == {"id": sid, "state": "bad"}


def test_status_unknown():
    assert status("s-20261006T153201Z-a1b2c3", Decisions(), None) == {"id": "s-20261006T153201Z-a1b2c3", "state": "unknown"}
