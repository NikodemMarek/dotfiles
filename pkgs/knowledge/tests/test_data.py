import pytest

from knowledge import data
from knowledge.data import ParseError


def test_yaml_dates_become_iso_strings():
    text = "created: 2026-10-06\nat: 2026-10-06 12:30:00\nquoted: '2026-10-06'\nn: 3\nok: true\nnothing: null\n"
    doc = data.as_obj(data.load_yaml(text))
    assert doc["created"] == "2026-10-06"
    assert doc["at"] == "2026-10-06T12:30:00"
    assert doc["quoted"] == "2026-10-06"
    assert doc["n"] == 3 and doc["ok"] is True and doc["nothing"] is None


def test_yaml_dates_nested_in_flow_collections():
    doc = data.as_obj(data.load_yaml("sources:\n- {date: 2026-10-06, by: coder}\nlist: [2026-01-02, x]\n"))
    assert doc == {"sources": [{"date": "2026-10-06", "by": "coder"}], "list": ["2026-01-02", "x"]}


def test_empty_yaml_is_null():
    assert data.load_yaml("") is None


@pytest.mark.parametrize("text", ["a: [", "a: b: c", "!!python/object:os.system {}", "1: x"])
def test_bad_yaml_is_a_parse_error(text: str):
    with pytest.raises(ParseError):
        data.load_yaml(text)


def test_dump_yaml_keeps_key_order_and_roundtrips():
    obj: data.Obj = {
        "name": "no-enums",
        "description": "Use unions: not enums",
        "kind": "convention",
        "tags": ["typescript", "style"],
        "created": "2026-10-06",
        "verify": None,
        "related": [],
        "sources": [{"date": "2026-10-06", "by": "coder", "evidence": "über"}],
    }
    text = data.dump_yaml(obj)
    assert list(data.as_obj(data.load_yaml(text))) == list(obj)
    assert [line.split(":")[0] for line in text.splitlines() if not line.startswith(("-", " "))] == list(obj)
    assert "tags: [typescript, style]" in text
    assert "über" in text
    assert "created: '2026-10-06'" in text  # quoted: it would load back as a date
    assert data.load_yaml(text) == obj


def test_dump_yaml_does_not_wrap_long_lines():
    long = "word " * 200
    text = data.dump_yaml({"description": long.strip()})
    assert len(text.splitlines()) == 1


def test_toml():
    text = '# c\n[[path]]\nprefix = "~/p"\nscopes = ["org/x"]\n[budget]\n"lang/python" = [10, 4000]\nd = 2026-10-06\n'
    doc = data.load_toml(text)
    assert doc == {
        "path": [{"prefix": "~/p", "scopes": ["org/x"]}],
        "budget": {"lang/python": [10, 4000], "d": "2026-10-06"},
    }


def test_bad_toml_is_a_parse_error():
    with pytest.raises(ParseError):
        data.load_toml("a = ")


def test_json_loads_cleans_surrogates():
    assert data.loads('"a\\ud800b"') == "a?b"
    with pytest.raises(ParseError):
        data.loads("{")


def test_dumps_is_compact_by_default():
    assert data.dumps({"a": [1, "é"]}) == '{"a":[1,"é"]}'
    assert data.dumps({"a": 1}, indent=2) == '{\n  "a": 1\n}'


def test_strs_is_a_json_list_of_the_strings():
    assert data.strs(("a", "b")) == ["a", "b"]
    assert data.strs(s for s in ["x"]) == ["x"]
    assert data.strs(()) == []


def test_checked_access():
    o = data.as_obj(data.loads('{"s": "x", "n": 4, "l": ["a", "b"], "b": true, "o": {"k": 1}}'))
    assert data.get_str(o, "s") == "x" and data.get_int(o, "n") == 4
    assert data.str_list(o, "l") == ["a", "b"] and data.get_bool(o, "b")
    assert data.get_obj(o, "o") == {"k": 1}
    assert data.opt_str(o, "missing") is None and data.str_or(o, "missing", "d") == "d"
    assert data.opt_list(o, "missing") == []
    for bad in (lambda: data.get_str(o, "n"), lambda: data.get_int(o, "s"), lambda: data.get_str(o, "missing"),
                lambda: data.str_list(o, "o"), lambda: data.get_bool(o, "n"), lambda: data.get_list(o, "s")):
        with pytest.raises(ParseError):
            bad()
    with pytest.raises(ParseError):  # a bool is not an int
        data.opt_int({"n": True}, "n")
