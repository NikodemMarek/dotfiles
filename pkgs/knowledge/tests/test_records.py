import datetime
import re
from dataclasses import replace

import pytest

from knowledge import data
from knowledge.data import Obj, ParseError
from knowledge.records import Origin, from_event, from_obj, new_id, stable_id, to_obj, trust_for

NOW = datetime.datetime(2026, 10, 6, 15, 32, 1, tzinfo=datetime.UTC)


def event(**over: data.Json) -> Obj:
    obj: Obj = {
        "type": "knowledge.submit",
        "title": "jj absorb needs --into",
        "body": "Rule, why, example.",
        "kind": "gotcha",
        "scope": "topic/jj",
        "evidence": "dotfiles 2026-10-06",
        "origin": {"via": "cli", "agent": "coder", "cwd": "/home/u/projects/dotfiles", "event": None, "session": None},
    }
    obj.update(over)
    return obj


def origin(via: str = "cli", cwd: str | None = None, event: str | None = None) -> Origin:
    return Origin(via=via, agent=None, cwd=cwd, event=event, session=None)


def test_a_valid_event_becomes_a_record():
    rec = from_event(event(id="s-20261006T153201Z-a1b2c3"), via_router=True, now=NOW)
    assert rec.id == "s-20261006T153201Z-a1b2c3"
    assert rec.received == "2026-10-06T15:32:01Z"
    assert (rec.trust, rec.attempt) == ("agent", 0)
    assert (rec.title, rec.kind, rec.scope) == ("jj absorb needs --into", "gotcha", "topic/jj")
    assert rec.evidence == "dotfiles 2026-10-06"
    assert rec.origin.agent == "coder"
    assert rec.origin.event is None


def test_a_missing_id_is_generated():
    rec = from_event(event(), via_router=True, now=NOW)
    assert re.fullmatch(r"s-20261006T153201Z-[0-9a-f]{6}", rec.id)
    assert re.fullmatch(r"s-20261006T153201Z-[0-9a-f]{6}", new_id(NOW))
    assert from_event(event(), via_router=True).id != from_event(event(), via_router=True).id


def test_a_stable_id_depends_only_on_its_parts_and_is_a_valid_id():
    sid = stable_id("sess", "agent", "title", "body")
    assert sid == stable_id("sess", "agent", "title", "body")
    assert re.fullmatch(r"s-\d{8}T\d{6}Z-[0-9a-f]{6}", sid)
    assert from_event(event(id=sid), via_router=True).id == sid
    assert len({sid, stable_id("sess", "agent", "title", "other"), stable_id("sess", "agen", "ttitle", "body")}) == 3
    assert stable_id("a", "bc") != stable_id("ab", "c")


@pytest.mark.parametrize("bad", ["", "s-1", "s-20261006T153201Z-A1B2C3", "s-20261006T153201Z-a1b2c", "x-20261006T153201Z-a1b2c3"])
def test_a_malformed_id_is_an_error(bad: str):
    with pytest.raises(ParseError):
        from_event(event(id=bad), via_router=True)


def test_the_title_is_collapsed_and_limited():
    assert from_event(event(title="  a \n\t b   c "), via_router=True).title == "a b c"
    assert len(from_event(event(title="x" * 200), via_router=True).title) == 200
    for bad in ("", "  \n ", "x" * 201):
        with pytest.raises(ParseError):
            from_event(event(title=bad), via_router=True)
    with pytest.raises(ParseError):
        from_event(event(title=None), via_router=True)


def test_the_body_is_limited_in_bytes():
    from_event(event(body="a" * 65536), via_router=True)
    with pytest.raises(ParseError):
        from_event(event(body="a" * 65537), via_router=True)
    with pytest.raises(ParseError):
        from_event(event(body="ł" * 32769), via_router=True)  # 2 bytes each
    for bad in ("", " \n"):
        with pytest.raises(ParseError):
            from_event(event(body=bad), via_router=True)


def test_the_body_is_kept_as_written():
    assert from_event(event(body="\nline\n\n  indented\n"), via_router=True).body == "\nline\n\n  indented\n"


def test_the_kind_is_checked_but_optional():
    assert from_event(event(kind=None), via_router=True).kind is None
    with pytest.raises(ParseError):
        from_event(event(kind="rumour"), via_router=True)


def test_an_invalid_scope_hint_is_dropped():
    assert from_event(event(scope="projects/x/facts"), via_router=True).scope == "projects/x/facts"
    for bad in ("topic/Jj", "elsewhere", "topic/jj/extra", ""):
        assert from_event(event(scope=bad), via_router=True).scope is None
    assert from_event(event(scope=None), via_router=True).scope is None


def test_the_evidence_is_limited():
    assert from_event(event(evidence="e" * 2000), via_router=True).evidence == "e" * 2000
    assert from_event(event(evidence=None), via_router=True).evidence is None
    assert from_event(event(evidence="  "), via_router=True).evidence is None
    with pytest.raises(ParseError):
        from_event(event(evidence="e" * 2001), via_router=True)


@pytest.mark.parametrize("bad", ["a\x00b", "a\x1b[31mb", "a\x07b"])
def test_control_characters_are_refused_in_title_evidence_and_origin(bad: str):
    with pytest.raises(ParseError, match="control"):
        from_event(event(title=bad), via_router=True)
    with pytest.raises(ParseError, match="control"):
        from_event(event(evidence=bad), via_router=True)
    for key in ("via", "agent", "cwd", "event", "session"):
        origin_obj: Obj = {"via": "cli", "agent": "coder", "cwd": "/w", "event": None, "session": None, key: bad}
        with pytest.raises(ParseError, match="control"):
            from_event(event(origin=origin_obj), via_router=True)


def test_a_tab_and_the_newlines_of_the_body_are_kept():
    assert from_event(event(evidence="a\tb"), via_router=True).evidence == "a\tb"
    assert from_event(event(body="a\n\tb\n"), via_router=True).body == "a\n\tb\n"
    assert from_event(event(title="a\nb"), via_router=True).title == "a b"  # collapsed before the check


def test_the_origin_is_required():
    obj = event()
    del obj["origin"]
    with pytest.raises(ParseError):
        from_event(obj, via_router=True)
    with pytest.raises(ParseError):
        from_event(event(origin={"agent": "coder"}), via_router=True)
    assert from_event(event(origin={"via": "cli"}), via_router=True).origin == origin()


@pytest.mark.parametrize(
    ("o", "via_router", "expected"),
    [
        (origin("user"), False, "user"),
        (origin("import"), False, "user"),
        (origin("user"), True, "agent"),  # claimed through the router
        (origin("import"), True, "agent"),
        (origin("cli"), False, "agent"),
        (origin("subagent-stop"), True, "agent"),
        (origin("cli", event="event:gitlab.note"), True, "untrusted"),
        (origin("user", event="event:gitlab.note"), True, "untrusted"),
        (origin("user", event="event:gitlab.note"), False, "user"),  # rule 1 comes first
        (origin("cli", cwd="/home/u/projects/ai.agents/gl-mr-7/src"), False, "untrusted"),
        (origin("cli", cwd="/home/u/projects/ai.agents/curator"), False, "agent"),
        (origin("cli", cwd="/home/u/projects/gl-thing"), False, "agent"),
        (origin("cli", cwd=None), False, "agent"),
    ],
)
def test_trust_for(o: Origin, via_router: bool, expected: str):
    assert trust_for(o, via_router) == expected


@pytest.mark.parametrize("via", ["user", "import"])
def test_a_relayed_origin_cannot_claim_to_be_the_user(via: str):
    ev = event(origin={"via": via, "agent": "user", "cwd": "/w", "event": None, "session": "x"})
    rec = from_event(ev, via_router=True)
    assert rec.origin == Origin(via="cli", agent=None, cwd="/w", event=None, session="x")
    assert rec.trust == "agent"


def test_a_relayed_origin_keeps_what_it_may_claim():
    ev = event(origin={"via": "subagent-stop", "agent": "coder", "cwd": None, "event": "event:gitlab.note", "session": "s"})
    rec = from_event(ev, via_router=True)
    assert rec.origin == Origin(via="subagent-stop", agent="coder", cwd=None, event="event:gitlab.note", session="s")
    assert rec.trust == "untrusted"
    assert from_event(event(origin={"via": "cli", "agent": "user"}), via_router=True).origin.agent is None


@pytest.mark.parametrize("via", ["user", "import"])
def test_a_direct_origin_is_kept(via: str):
    rec = from_event(event(origin={"via": via, "agent": "user"}), via_router=False)
    assert (rec.origin.via, rec.origin.agent, rec.trust) == (via, "user", "user")


def test_error_messages_do_not_echo_the_wire_values():
    secret = "glpat-" + "a" * 20
    for obj in (event(kind=secret), event(id=secret)):
        with pytest.raises(ParseError) as e:
            from_event(obj, via_router=True)
        assert secret not in str(e.value)
        assert "glpa…" in str(e.value)
    with pytest.raises(ParseError) as e:
        from_event(event(kind="x" * 5000), via_router=True)
    assert len(str(e.value)) < 200


def test_trust_is_computed_not_taken_from_the_event():
    assert from_event(event(trust="user"), via_router=True).trust == "agent"
    ev = event(origin={"via": "cli", "event": "event:gitlab.note"})
    assert from_event(ev, via_router=True).trust == "untrusted"


def test_a_record_round_trips_through_its_stored_form():
    rec = from_event(event(), via_router=True, now=NOW)
    obj = to_obj(rec)
    assert obj["v"] == 1
    assert list(obj)[:4] == ["v", "id", "received", "trust"]
    assert from_obj(data.as_obj(data.loads(data.dumps(obj)))) == rec


def test_the_last_errors_of_a_record_round_trip():
    rec = from_event(event(), via_router=True, now=NOW)
    assert rec.last_errors == ()
    assert to_obj(rec)["last_errors"] == []
    refused = replace(rec, attempt=1, last_errors=("topic/jj/x.md: an entry of the user", "second"))
    obj = to_obj(refused)
    assert obj["last_errors"] == ["topic/jj/x.md: an entry of the user", "second"]
    assert from_obj(data.as_obj(data.loads(data.dumps(obj)))) == refused


def test_a_record_stored_without_last_errors_has_none():
    obj = to_obj(from_event(event(), via_router=True, now=NOW))
    del obj["last_errors"]  # a file written before the field existed
    assert from_obj(obj).last_errors == ()
    with pytest.raises(ParseError):
        from_obj({**obj, "last_errors": [1]})


def test_a_stored_record_is_checked():
    obj = to_obj(from_event(event(), via_router=True, now=NOW))
    for key, value in (("v", 2), ("trust", "root"), ("attempt", -1), ("id", "nope"), ("origin", None)):
        with pytest.raises(ParseError):
            from_obj({**obj, key: value})
    missing = dict(obj)
    del missing["received"]
    with pytest.raises(ParseError):
        from_obj(missing)
