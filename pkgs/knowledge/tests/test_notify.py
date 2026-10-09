import datetime
import json

import pytest

from fake_router import closed_port_url, serve
from knowledge.config import state_dir
from knowledge.notify import notify

DAY = datetime.date(2026, 10, 6)


def test_notify_posts_a_review_needed_event(monkeypatch: pytest.MonkeyPatch):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        assert notify("knowledge: review", "3 waiting") is True
    assert router.requests[0][0] == "/events"
    assert router.events == [
        {"type": "knowledge.review_needed", "project": "knowledge", "title": "knowledge: review", "body": "3 waiting"}
    ]


def test_without_a_key_every_call_is_sent(monkeypatch: pytest.MonkeyPatch):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        notify("t", "b")
        notify("t", "b")
    assert len(router.events) == 2
    assert not (state_dir() / "notified.json").exists()


def test_a_key_is_notified_once_a_day(monkeypatch: pytest.MonkeyPatch):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        assert notify("t", "b", "budget", DAY) is True
        assert notify("t", "b", "budget", DAY) is False
        assert notify("t", "b", "other", DAY) is True
        assert notify("t", "b", "budget", DAY + datetime.timedelta(days=1)) is True
    assert len(router.events) == 3
    saved = json.loads((state_dir() / "notified.json").read_text())
    assert saved == {"budget": "2026-10-07"}  # the keys of older days are dropped


def test_a_router_that_is_down_is_only_a_warning(monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture):
    monkeypatch.setenv("EVENT_ROUTER_URL", closed_port_url())
    assert notify("t", "b", "budget", DAY) is False
    assert "could not notify" in caplog.text
    assert not (state_dir() / "notified.json").exists()  # not marked: the next try may get through
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        assert notify("t", "b", "budget", DAY) is True


def test_a_damaged_notified_file_is_ignored(monkeypatch: pytest.MonkeyPatch):
    state_dir().mkdir(parents=True)
    (state_dir() / "notified.json").write_text("{not json")
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        assert notify("t", "b", "budget", DAY) is True
    assert json.loads((state_dir() / "notified.json").read_text()) == {"budget": "2026-10-06"}
