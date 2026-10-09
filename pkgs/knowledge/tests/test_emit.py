import pytest

from fake_router import closed_port_url, serve
from knowledge import emit
from knowledge.records import Origin, from_event, origin_obj

EVENT = {
    "type": "knowledge.submit",
    "id": "s-20261006T153201Z-a1b2c3",
    "title": "lesson",
    "body": "Rule, why, example.",
    "kind": None,
    "scope": None,
    "evidence": None,
    "origin": {"via": "cli", "agent": "coder", "cwd": None, "event": None, "session": None},
}


@pytest.fixture(autouse=True)
def no_sleep(monkeypatch: pytest.MonkeyPatch) -> list[float]:
    slept: list[float] = []
    monkeypatch.setattr(emit.time, "sleep", slept.append)
    return slept


def test_accepted_at_once():
    with serve(202) as router:
        emit.post(EVENT, router.url)
    assert [path for path, _ in router.requests] == ["/events"]
    assert router.events == [EVENT]


def test_two_failures_then_accepted(no_sleep: list[float]):
    with serve(500, 503, 202) as router:
        emit.post(EVENT, router.url)
    assert len(router.requests) == 3
    assert no_sleep == [0.5, 1.5]


def test_gives_up_after_the_last_delay(no_sleep: list[float]):
    with serve(500) as router:
        with pytest.raises(emit.EmitError) as e:
            emit.post(EVENT, router.url)
    assert not e.value.permanent
    assert "500" in str(e.value)
    assert len(router.requests) == 4
    assert no_sleep == [0.5, 1.5, 3.0]


def test_other_success_statuses_are_not_acceptance():
    with serve(200) as router:
        with pytest.raises(emit.EmitError):
            emit.post(EVENT, router.url, delays=(0,))
    assert len(router.requests) == 2


def test_400_is_permanent_and_not_retried(no_sleep: list[float]):
    with serve(400, 202) as router:
        with pytest.raises(emit.EmitError) as e:
            emit.post(EVENT, router.url)
    assert e.value.permanent
    assert len(router.requests) == 1
    assert no_sleep == []


def test_closed_port_fails_after_the_retries(no_sleep: list[float]):
    with pytest.raises(emit.EmitError) as e:
        emit.post(EVENT, closed_port_url(), delays=(0, 0))
    assert not e.value.permanent
    assert len(no_sleep) == 2


def test_no_delays_means_one_attempt():
    with serve(500) as router:
        with pytest.raises(emit.EmitError):
            emit.post(EVENT, router.url, delays=())
    assert len(router.requests) == 1


@pytest.mark.parametrize("url", ["", "127.0.0.1:7531", "ftp://127.0.0.1", "http://", "http://127.0.0.1:port"])
def test_bad_url_is_permanent(url: str):
    with pytest.raises(emit.EmitError) as e:
        emit.post(EVENT, url)
    assert e.value.permanent


def test_url_with_a_path_prefix():
    with serve() as router:
        emit.post(EVENT, router.url + "/prefix/")
    assert [path for path, _ in router.requests] == ["/prefix/events"]


def test_build_event_is_the_wire_format():
    origin = Origin(via="cli", agent="coder", cwd="/work", event=None, session=None)
    rec = from_event(
        {"id": "s-20261006T153201Z-a1b2c3", "title": "  a   b ", "body": "text", "kind": "gotcha", "origin": origin_obj(origin)},
        via_router=False,
    )
    assert emit.build_event(rec) == {
        "type": "knowledge.submit",
        "id": "s-20261006T153201Z-a1b2c3",
        "title": "a b",
        "body": "text",
        "kind": "gotcha",
        "scope": None,
        "evidence": None,
        "origin": {"via": "cli", "agent": "coder", "cwd": "/work", "event": None, "session": None},
    }


def test_hard_secret_looks_at_every_text_field():
    base = {"title": "t", "body": "b", "origin": {"via": "cli"}}
    token = "glpat-" + "a" * 20
    assert emit.hard_secret(from_event(base, via_router=True)) is None
    assert emit.hard_secret(from_event({**base, "body": f"use {token}"}, via_router=True)) == "gitlab-token"
    assert emit.hard_secret(from_event({**base, "title": token}, via_router=True)) == "gitlab-token"
    assert emit.hard_secret(from_event({**base, "evidence": token}, via_router=True)) == "gitlab-token"
    # a soft finding is not a reason to refuse
    assert emit.hard_secret(from_event({**base, "body": "password: hunter2"}, via_router=True)) is None


@pytest.mark.parametrize("field", ["agent", "cwd", "event", "session", "via"])
def test_hard_secret_looks_at_the_origin_too(field: str):
    token = "glpat-" + "a" * 20
    origin = {"via": "cli", "agent": "coder", "cwd": "/work", "event": None, "session": "s", field: f"x {token}"}
    rec = from_event({"title": "t", "body": "b", "origin": origin}, via_router=True)
    assert emit.hard_secret(rec) == "gitlab-token"
