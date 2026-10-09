import io
import json
import os
import re
from dataclasses import replace
from pathlib import Path

import pytest

from fake_router import closed_port_url, serve
from knowledge import cli, emit
from knowledge.inbox import Inbox

TOKEN = "glpat-" + "a" * 20
ID = re.compile(r"s-\d{8}T\d{6}Z-[0-9a-f]{6}")


class Runner:
    def __init__(self, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
        self.monkeypatch = monkeypatch
        self.capsys = capsys

    def __call__(self, *argv: str, stdin: str = "") -> tuple[int, str]:
        """Run `knowledge <argv>` with `stdin` piped in: the exit code and stdout."""
        self.monkeypatch.setattr("sys.argv", ["knowledge", *argv])
        self.monkeypatch.setattr("sys.stdin", io.StringIO(stdin))
        code = 0
        try:
            cli.main()
        except SystemExit as e:
            code = int(e.code or 0)
        return code, self.capsys.readouterr().out


@pytest.fixture
def run(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> Runner:
    monkeypatch.setattr(emit.time, "sleep", lambda s: None)
    return Runner(monkeypatch, capsys)


def event(**fields: object) -> str:
    base = {
        "type": "knowledge.submit",
        "title": "jj absorb needs --into",
        "body": "Rule, why, example.",
        "origin": {"via": "subagent-stop", "agent": "coder", "cwd": "/home/u/projects/dotfiles", "event": None, "session": "x"},
    }
    return json.dumps({**base, **fields})


# submit


def test_submit_prints_the_id_and_the_router_gets_the_event(run: Runner, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("KNOWLEDGE_AGENT", "coder")
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = run(
            "submit", "--title", "  jj absorb   needs --into ", "--kind", "gotcha", "--scope", "topic/jj",
            "--evidence", "dotfiles 2026-10-06", stdin="Rule, why, example.\n",
        )  # fmt: skip
    assert code == 0
    sid = out.strip()
    assert ID.fullmatch(sid)
    assert router.requests[0][0] == "/events"
    assert router.events == [
        {
            "type": "knowledge.submit",
            "id": sid,
            "title": "jj absorb needs --into",
            "body": "Rule, why, example.\n",
            "kind": "gotcha",
            "scope": "topic/jj",
            "evidence": "dotfiles 2026-10-06",
            "origin": {"via": "cli", "agent": "coder", "cwd": os.getcwd(), "event": None, "session": None},
        }
    ]


def test_submit_carries_the_event_origin_and_reads_a_file(run: Runner, monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
    monkeypatch.setenv("KNOWLEDGE_ORIGIN", "event:gitlab.note")
    body = tmp_path / "body.md"
    body.write_text("from a file\n")
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, _ = run("submit", "--title", "t", "--file", str(body), stdin="ignored")
    assert code == 0
    assert router.events[0]["body"] == "from a file\n"
    assert router.events[0]["origin"]["event"] == "event:gitlab.note"
    assert router.events[0]["origin"]["agent"] is None


def test_submit_refuses_a_file_inside_claude_code(run: Runner, monkeypatch: pytest.MonkeyPatch, tmp_path: Path, caplog: pytest.LogCaptureFixture):
    body = tmp_path / "body.md"
    body.write_text("from a file\n")
    monkeypatch.setenv("CLAUDECODE", "1")
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        assert run("submit", "--title", "t", "--file", str(body)) == (2, "")
        assert "pipe the body on stdin" in caplog.text
        code, out = run("submit", "--title", "t", stdin="piped\n")  # stdin is fine
    assert code == 0 and out.strip()
    assert [e["body"] for e in router.events] == ["piped\n"]


def test_submit_drops_an_invalid_scope_hint(run: Runner, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, _ = run("submit", "--title", "t", "--scope", "Not A Scope", stdin="body")
    assert code == 0
    assert router.events[0]["scope"] is None
    assert "ignoring scope" in caplog.text


def test_submit_without_a_body_is_a_usage_error(run: Runner, monkeypatch: pytest.MonkeyPatch):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = run("submit", "--title", "t", stdin=" \n")
    assert (code, out) == (2, "")
    assert router.requests == []


def test_submit_with_a_missing_file_is_a_usage_error(run: Runner, tmp_path: Path):
    assert run("submit", "--title", "t", "--file", str(tmp_path / "nope.md"))[0] == 2


@pytest.mark.parametrize("argv", [["--kind", "gotcha"], ["--title", "t", "--kind", "nonsense"], ["--title", " "]])
def test_submit_rejects_bad_arguments(run: Runner, argv: list[str]):
    code, out = run("submit", *argv, stdin="body")
    assert (code, out) == (2, "")


def test_submit_router_down_exits_1(run: Runner, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture):
    monkeypatch.setenv("EVENT_ROUTER_URL", closed_port_url())
    code, out = run("submit", "--title", "t", stdin="body")
    assert (code, out) == (1, "")
    assert "knowledge: router unreachable (" in caplog.text
    assert "knowledge NOT stored" in caplog.text


def test_submit_router_rejecting_it_exits_2(run: Runner, monkeypatch: pytest.MonkeyPatch):
    with serve(400, 202) as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = run("submit", "--title", "t", stdin="body")
    assert (code, out) == (2, "")
    assert len(router.requests) == 1


@pytest.mark.parametrize("where", ["body", "title", "evidence"])
def test_submit_refuses_a_secret(run: Runner, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture, where: str):
    fields = {"body": "text", "title": "t", "evidence": "e", where: f"see {TOKEN}"}
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = run("submit", "--title", fields["title"], "--evidence", fields["evidence"], stdin=fields["body"])
    assert (code, out) == (2, "")
    assert router.requests == []
    assert "refusing to submit: looks like a secret (gitlab-token)" in caplog.text
    assert TOKEN not in caplog.text


# receive


def test_receive_stores_with_the_trust_computed(run: Runner):
    code, out = run("receive", stdin=event())
    assert code == 0
    got = json.loads(out)
    assert got["stored"] is True
    pending = Inbox().pending(10**6)
    assert [(r.id, r.trust, r.title, r.origin.via) for r in pending] == [
        (got["id"], "agent", "jj absorb needs --into", "subagent-stop")
    ]
    assert pending[0].attempt == 0


def test_receive_untrusts_what_an_event_launched(run: Runner):
    origin = {"via": "cli", "agent": "reviewer", "cwd": "/home/u/projects/ai", "event": "event:gitlab.note", "session": None}
    assert run("receive", stdin=event(origin=origin))[0] == 0
    assert [r.trust for r in Inbox().pending(10**6)] == ["untrusted"]


def test_receive_untrusts_a_review_workspace(run: Runner):
    origin = {"via": "cli", "agent": None, "cwd": "/home/u/projects/ai.agents/gl-mr-7/src", "event": None, "session": None}
    assert run("receive", stdin=event(origin=origin))[0] == 0
    assert [r.trust for r in Inbox().pending(10**6)] == ["untrusted"]


@pytest.mark.parametrize("via", ["user", "import"])
def test_receive_never_grants_user_trust(run: Runner, via: str):
    origin = {"via": via, "agent": None, "cwd": None, "event": None, "session": None}
    assert run("receive", stdin=event(origin=origin))[0] == 0
    assert [r.trust for r in Inbox().pending(10**6)] == ["agent"]


def test_receive_keeps_the_id_it_was_sent(run: Runner):
    sid = "s-20261006T153201Z-a1b2c3"
    assert json.loads(run("receive", stdin=event(id=sid))[1])["id"] == sid
    assert [r.id for r in Inbox().pending(10**6)] == [sid]


def test_a_second_receive_of_an_id_keeps_the_first_file(run: Runner, caplog: pytest.LogCaptureFixture):
    caplog.set_level("INFO", logger="knowledge")
    sid = "s-20261006T153201Z-a1b2c3"
    assert run("receive", stdin=event(id=sid))[0] == 0
    [first] = Inbox().pending(10**6)
    Inbox().put(replace(first, attempt=1))  # the curator retried it
    code, out = run("receive", stdin=event(id=sid, title="a replay with another title"))
    assert code == 0
    assert json.loads(out) == {"id": sid, "stored": True}
    assert [(r.id, r.title, r.attempt) for r in Inbox().pending(10**6)] == [(sid, first.title, 1)]
    assert f"submission {sid} is queued already" in caplog.text


@pytest.mark.parametrize("state", ["failed", "bad"])
def test_a_replayed_id_that_was_set_aside_is_not_queued_again(run: Runner, caplog: pytest.LogCaptureFixture, state: str):
    caplog.set_level("INFO", logger="knowledge")
    sid = "s-20261006T153201Z-a1b2c3"
    assert run("receive", stdin=event(id=sid))[0] == 0
    inbox = Inbox()
    if state == "failed":
        inbox.fail(sid)
    else:
        (inbox.dir / f"{sid}.json").rename(inbox.dir / f"{sid}.json.bad")
    assert inbox.state(sid) == state
    code, out = run("receive", stdin=event(id=sid))
    assert (code, json.loads(out)) == (0, {"id": sid, "stored": True})
    assert inbox.count() == 0  # not resurrected
    assert inbox.state(sid) == state
    assert f"submission {sid} is queued already ({state})" in caplog.text


def test_receive_drops_a_secret_and_still_exits_0(run: Runner, caplog: pytest.LogCaptureFixture):
    code, out = run("receive", stdin=event(body=f"token is {TOKEN}"))
    assert code == 0
    assert json.loads(out)["stored"] is False
    assert Inbox().count() == 0
    assert "looks like a secret (gitlab-token)" in caplog.text
    assert TOKEN not in caplog.text


@pytest.mark.parametrize("field", ["agent", "cwd", "event", "session"])
def test_receive_drops_a_secret_in_the_origin(run: Runner, caplog: pytest.LogCaptureFixture, field: str):
    origin = {"via": "cli", "agent": "coder", "cwd": "/work", "event": None, "session": None, field: f"x {TOKEN}"}
    code, out = run("receive", stdin=event(origin=origin))
    assert code == 0
    assert json.loads(out)["stored"] is False
    assert Inbox().count() == 0
    assert "looks like a secret (gitlab-token)" in caplog.text
    assert TOKEN not in caplog.text


def test_receive_does_not_log_a_secret_sent_as_the_kind(run: Runner, caplog: pytest.LogCaptureFixture):
    assert run("receive", stdin=event(kind=TOKEN)) == (2, "")
    assert TOKEN not in caplog.text


def test_receive_does_not_believe_a_user_origin(run: Runner):
    origin = {"via": "user", "agent": "user", "cwd": None, "event": None, "session": None}
    assert run("receive", stdin=event(origin=origin))[0] == 0
    (rec,) = Inbox().pending(10**6)
    assert (rec.trust, rec.origin.via, rec.origin.agent) == ("agent", "cli", None)


@pytest.mark.parametrize(
    "stdin",
    [
        "",
        "not json",
        "[]",
        event(type="knowledge.other"),
        event(title=""),
        event(body="  "),
        event(kind="nonsense"),
        event(id="not-an-id"),
        json.dumps({"type": "knowledge.submit", "title": "t", "body": "b"}),  # no origin
    ],
)
def test_receive_rejects_what_is_not_a_submission(run: Runner, stdin: str):
    code, out = run("receive", stdin=stdin)
    assert (code, out) == (2, "")
    assert Inbox().count() == 0


def test_submit_then_receive_round_trip(run: Runner, monkeypatch: pytest.MonkeyPatch):
    """What `submit` posts is what `receive` accepts."""
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        _, out = run("submit", "--title", "t", "--kind", "howto", "--scope", "lang/nix", stdin="body")
    sid = out.strip()
    assert run("receive", stdin=json.dumps(router.events[0]))[0] == 0
    (rec,) = Inbox().pending(10**6)
    assert (rec.id, rec.kind, rec.scope, rec.trust, rec.origin.via) == (sid, "howto", "lang/nix", "agent", "cli")
