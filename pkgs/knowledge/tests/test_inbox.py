import datetime
import os
from dataclasses import replace
from pathlib import Path

import pytest

from knowledge.inbox import Inbox
from knowledge.records import Record, from_event


def make(sid: str, received: str = "2026-10-08T10:00:00Z", body: str = "Rule, why, example.") -> Record:
    rec = from_event(
        {"id": sid, "title": f"lesson {sid}", "body": body, "origin": {"via": "cli", "agent": "coder"}},
        via_router=True,
        now=datetime.datetime(2026, 10, 8, 10, tzinfo=datetime.UTC),
    )
    return replace(rec, received=received)


A = "s-20261008T100000Z-aaaaaa"
B = "s-20261008T100000Z-bbbbbb"
C = "s-20261008T100000Z-cccccc"


def ids(records: list[Record]) -> list[str]:
    return [r.id for r in records]


def test_an_empty_inbox_has_nothing_pending():
    inbox = Inbox()
    assert inbox.count() == 0
    assert inbox.pending(1000) == []
    assert not inbox.has(A)


def test_put_and_pending_round_trip():
    inbox = Inbox()
    rec = make(A, body="two\nlines")
    inbox.put(rec)
    assert inbox.pending(10**6) == [rec]
    assert inbox.has(A)
    assert inbox.count() == 1


def test_the_file_is_private_and_so_is_the_dir():
    inbox = Inbox()
    inbox.put(make(A))
    assert (inbox.dir / f"{A}.json").stat().st_mode & 0o777 == 0o600
    assert inbox.dir.stat().st_mode & 0o777 == 0o700


def test_the_same_id_replaces_the_file():
    inbox = Inbox()
    inbox.put(make(A))
    inbox.put(replace(make(A), attempt=1))
    assert inbox.count() == 1
    assert [r.attempt for r in inbox.pending(10**6)] == [1]


def test_pending_is_ordered_by_received_then_id():
    inbox = Inbox()
    inbox.put(make(C, received="2026-10-08T10:00:00Z"))
    inbox.put(make(B, received="2026-10-08T09:00:00Z"))
    inbox.put(make(A, received="2026-10-08T10:00:00Z"))
    assert ids(inbox.pending(10**6)) == [B, A, C]


def test_the_byte_cap_keeps_at_least_one_record():
    inbox = Inbox()
    inbox.put(make(A, received="2026-10-08T09:00:00Z"))
    inbox.put(make(B, received="2026-10-08T10:00:00Z"))
    size = (inbox.dir / f"{A}.json").stat().st_size
    assert ids(inbox.pending(1)) == [A]
    assert ids(inbox.pending(size)) == [A]
    assert ids(inbox.pending(2 * size - 1)) == [A]
    assert ids(inbox.pending(2 * size)) == [A, B]


def test_a_bad_file_is_set_aside_and_skipped(caplog: pytest.LogCaptureFixture):
    inbox = Inbox()
    inbox.put(make(A))
    bad = inbox.dir / f"{B}.json"
    bad.write_text("{not json")
    assert ids(inbox.pending(10**6)) == [A]
    assert not bad.exists()
    assert (inbox.dir / f"{B}.json.bad").read_text() == "{not json"
    assert "setting aside" in caplog.text
    assert inbox.count() == 1
    assert ids(inbox.pending(10**6)) == [A]


def test_a_read_only_pending_leaves_a_bad_file_in_place(caplog: pytest.LogCaptureFixture):
    inbox = Inbox()
    inbox.put(make(A))
    bad = inbox.dir / f"{B}.json"
    bad.write_text("{not json")
    assert ids(inbox.pending(10**6, set_aside=False)) == [A]
    assert bad.read_text() == "{not json"
    assert not list(inbox.dir.glob("*.bad*"))
    assert "skipping an unparsable file" in caplog.text
    assert ids(inbox.pending(10**6)) == [A]  # the next run that may write sets it aside
    assert (inbox.dir / f"{B}.json.bad").exists()


def test_a_second_bad_file_does_not_overwrite_the_first():
    inbox = Inbox()
    bad = inbox.dir / f"{B}.json"
    inbox.dir.mkdir(parents=True)
    bad.write_text("first")
    inbox.pending(10**6)
    bad.write_text("second")
    inbox.pending(10**6)
    bad.write_text("third")
    inbox.pending(10**6)
    assert (inbox.dir / f"{B}.json.bad").read_text() == "first"
    assert (inbox.dir / f"{B}.json.bad.1").read_text() == "second"
    assert (inbox.dir / f"{B}.json.bad.2").read_text() == "third"
    assert not bad.exists()


@pytest.mark.skipif(os.geteuid() == 0, reason="root reads any file")
def test_an_unreadable_file_is_skipped_without_a_crash(caplog: pytest.LogCaptureFixture):
    inbox = Inbox()
    inbox.put(make(A))
    inbox.put(make(B))
    locked = inbox.dir / f"{B}.json"
    locked.chmod(0o000)
    try:
        assert ids(inbox.pending(10**6)) == [A]
    finally:
        locked.chmod(0o600)
    assert "cannot be read" in caplog.text
    assert locked.exists()
    assert ids(inbox.pending(10**6)) == [A, B]


def test_a_rename_that_fails_skips_the_file(monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture):
    inbox = Inbox()
    inbox.put(make(A))
    (inbox.dir / f"{B}.json").write_text("{not json")

    def refuse(self: Path, target: Path) -> Path:
        raise PermissionError("read-only directory")

    monkeypatch.setattr(Path, "rename", refuse)
    assert ids(inbox.pending(10**6)) == [A]
    assert "cannot be set aside" in caplog.text


def test_put_syncs_the_file_and_the_directory(monkeypatch: pytest.MonkeyPatch):
    calls: list[int] = []
    real = os.fsync

    def fsync(fd: int) -> None:
        calls.append(fd)
        real(fd)

    monkeypatch.setattr(os, "fsync", fsync)
    Inbox().put(make(A))
    assert len(calls) == 2


def test_fail_sets_the_file_aside_as_failed():
    inbox = Inbox()
    inbox.put(make(A))
    inbox.fail(A)
    assert not inbox.has(A)
    assert inbox.count() == 0
    assert (inbox.dir / f"{A}.json.failed").exists()
    assert inbox.pending(10**6) == []
    inbox.put(make(A))  # the same id again, and failing again keeps both
    inbox.fail(A)
    assert (inbox.dir / f"{A}.json.failed.1").exists()
    inbox.fail(B)  # nothing to fail: fine


def test_state():
    inbox = Inbox()
    assert inbox.state(A) is None
    inbox.put(make(A))
    assert inbox.state(A) == "pending"
    inbox.fail(A)
    assert inbox.state(A) == "failed"
    (inbox.dir / f"{B}.json").write_text("{not json")
    inbox.pending(10**6)
    assert inbox.state(B) == "bad"
    inbox.put(make(A))
    assert inbox.state(A) == "pending"  # a file in the inbox wins
    (inbox.dir / f"{C}.json.bad").write_text("x")
    (inbox.dir / f"{C}.json.failed.1").write_text("x")
    assert inbox.state(C) == "failed"
    assert inbox.state("../x") is None
    assert inbox.state("") is None


def test_a_file_that_holds_another_record_is_set_aside():
    inbox = Inbox()
    inbox.put(make(A))
    (inbox.dir / f"{A}.json").rename(inbox.dir / f"{B}.json")
    assert inbox.pending(10**6) == []
    assert (inbox.dir / f"{B}.json.bad").exists()


def test_a_tmp_file_is_ignored():
    inbox = Inbox()
    inbox.put(make(A))
    (inbox.dir / f".{B}.json.123.tmp").write_text("half a rec")
    assert ids(inbox.pending(10**6)) == [A]
    assert inbox.count() == 1
    assert not inbox.has(B)
    assert not list(inbox.dir.glob("*.bad"))


def test_remove_deletes_the_file_and_a_missing_one_is_fine():
    inbox = Inbox()
    inbox.put(make(A))
    inbox.remove(A)
    inbox.remove(A)
    inbox.remove(B)
    assert not inbox.has(A)
    assert inbox.count() == 0


def test_only_a_submission_id_is_a_name():
    inbox = Inbox()
    inbox.put(make(A))
    assert not inbox.has("../x")
    assert not inbox.has("")
    assert not inbox.has(f"{A}.json")
    with pytest.raises(ValueError):
        inbox.remove("../x")
