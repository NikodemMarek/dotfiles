from dataclasses import replace

import pytest

from knowledge import entry
from knowledge.entry import Entry, EntryError, Source

REL = "lang/typescript/no-enums.md"

SOURCE = Source(
    date="2026-10-06",
    by="coder",
    project="dotfiles",
    trust="agent",
    submission="s-20261006T153201Z-a1b2c3",
    evidence="saw it: in review",
)

ENTRY = Entry(
    name="no-enums",
    description="Use string unions, not enums; they erase cleanly",
    kind="convention",
    scope="lang/typescript",
    tags=("typescript", "style"),
    confidence="medium",
    trust="agent",
    status="active",
    created="2026-10-06",
    updated="2026-10-06",
    last_verified="2026-10-06",
    verify=None,
    related=("lang/typescript/strict-mode.md",),
    sources=(SOURCE,),
    body="Prefer `type X = 'a' | 'b'`.\n\n- enums emit runtime code\n- über",
)


def top_keys(text: str) -> list[str]:
    head = text.split("\n---\n", 1)[0]
    return [line.split(":")[0] for line in head.splitlines()[1:] if not line.startswith(("-", " "))]


def edit(text: str, old: str, new: str) -> str:
    assert old in text
    return text.replace(old, new, 1)


def test_roundtrip():
    text = entry.render_entry(ENTRY)
    assert entry.parse_entry(REL, text) == ENTRY
    assert entry.render_entry(entry.parse_entry(REL, text)) == text


def test_rendered_shape_and_key_order():
    text = entry.render_entry(ENTRY)
    assert text.startswith("---\nname: no-enums\n")
    assert "\n---\n\nPrefer `type X" in text
    assert text.endswith("- über\n") and not text.endswith("\n\n")
    assert top_keys(text) == list(entry.KEYS)
    assert "tags: [typescript, style]" in text
    assert "created: '2026-10-06'" in text
    assert "related: [lang/typescript/strict-mode.md]" in text
    assert "verify: null" in text
    assert "- {date: '2026-10-06', by: coder, project: dotfiles, trust: agent, submission: s-" in text


def test_roundtrip_with_empty_optionals_and_null_project():
    e = replace(ENTRY, tags=(), related=(), sources=(replace(SOURCE, project=None),), verify="run `tsc`", status="disputed")
    assert entry.parse_entry(REL, entry.render_entry(e)) == e
    assert entry.parse_entry(REL, entry.render_entry(replace(e, sources=()))).sources == ()


def test_parse_is_order_independent_and_tolerates_unquoted_dates():
    text = entry.render_entry(ENTRY)
    swapped = edit(text, "created: '2026-10-06'\nupdated: '2026-10-06'\n", "updated: 2026-10-06\ncreated: 2026-10-06\n")
    assert entry.parse_entry(REL, swapped) == ENTRY


def test_rel_property():
    assert ENTRY.rel == REL


@pytest.mark.parametrize(
    ("old", "new"),
    [
        ("kind: convention", "kind: rumor"),
        ("confidence: medium", "confidence: certain"),
        ("trust: agent\nstatus", "trust: root\nstatus"),
        ("status: active", "status: archived"),
        ("by: coder, project: dotfiles, trust: agent", "by: coder, project: dotfiles, trust: root"),
    ],
)
def test_invalid_enum(old: str, new: str):
    with pytest.raises(EntryError):
        entry.parse_entry(REL, edit(entry.render_entry(ENTRY), old, new))


def test_name_and_scope_must_match_the_path():
    text = entry.render_entry(ENTRY)
    with pytest.raises(EntryError, match="name"):
        entry.parse_entry("lang/typescript/other.md", text)
    with pytest.raises(EntryError, match="scope"):
        entry.parse_entry("lang/python/no-enums.md", text)
    with pytest.raises(EntryError, match="name"):
        entry.parse_entry(REL, edit(text, "name: no-enums", "name: enums"))
    with pytest.raises(EntryError, match="scope"):
        entry.parse_entry(REL, edit(text, "scope: lang/typescript", "scope: lang/python"))


def test_multi_line_description_is_rejected():
    text = entry.render_entry(ENTRY)
    with pytest.raises(EntryError, match="single line"):
        entry.parse_entry(REL, edit(text, "description: Use string unions, not enums; they erase cleanly", 'description: "a\\nb"'))
    with pytest.raises(EntryError, match="single line"):
        entry.render_entry(replace(ENTRY, description="a\nb"))


def test_description_length():
    for bad in ("", "x" * (entry.MAX_DESCRIPTION + 1)):
        with pytest.raises(EntryError, match="description"):
            entry.render_entry(replace(ENTRY, description=bad))
    entry.render_entry(replace(ENTRY, description="x" * entry.MAX_DESCRIPTION))


def test_body_limit_and_reference_kind():
    big = "x" * entry.MAX_BODY
    entry.render_entry(replace(ENTRY, body=big))
    with pytest.raises(EntryError, match="body"):
        entry.render_entry(replace(ENTRY, body=big + "x"))
    text = entry.render_entry(replace(ENTRY, kind="reference", body="y" * entry.MAX_REFERENCE_BODY))
    assert entry.parse_entry(REL, text).kind == "reference"
    with pytest.raises(EntryError, match="body"):
        entry.render_entry(replace(ENTRY, kind="reference", body="y" * (entry.MAX_REFERENCE_BODY + 1)))
    with pytest.raises(EntryError, match="body"):  # the limit is in bytes
        entry.render_entry(replace(ENTRY, body="é" * (entry.MAX_BODY // 2 + 1)))


def test_empty_body_is_rejected():
    text = entry.render_entry(ENTRY)
    head = text.split("\n---\n", 1)[0]
    with pytest.raises(EntryError, match="body"):
        entry.parse_entry(REL, head + "\n---\n\n")


def test_other_field_limits():
    bad: list[Entry] = [
        replace(ENTRY, tags=tuple(f"t{i}" for i in range(entry.MAX_TAGS + 1))),
        replace(ENTRY, tags=("Not A Tag",)),
        replace(ENTRY, verify="v" * (entry.MAX_VERIFY + 1)),
        replace(ENTRY, related=("projects/x/overview.md",)),
        replace(ENTRY, created="2026-13-01"),
        replace(ENTRY, updated="20261006"),
        replace(ENTRY, last_verified="2026-10-06T12:00:00"),
        replace(ENTRY, sources=(replace(SOURCE, evidence="e" * (entry.MAX_EVIDENCE + 1)),)),
        replace(ENTRY, sources=(replace(SOURCE, date="yesterday"),)),
    ]
    for e in bad:
        with pytest.raises(EntryError):
            entry.render_entry(e)
    entry.render_entry(replace(ENTRY, sources=(replace(SOURCE, evidence="e" * entry.MAX_EVIDENCE),)))


@pytest.mark.parametrize(
    "text",
    [
        "",
        "no frontmatter\n",
        "---\nname: no-enums\n",  # unterminated
        "---\n---\n\nbody\n",  # empty frontmatter
        "---\n- a\n- b\n---\n\nbody\n",  # not a mapping
        "---\nname: [\n---\n\nbody\n",  # bad yaml
    ],
)
def test_bad_frontmatter(text: str):
    with pytest.raises(EntryError):
        entry.parse_entry(REL, text)


def test_unknown_and_missing_keys():
    text = entry.render_entry(ENTRY)
    with pytest.raises(EntryError, match="unknown keys"):
        entry.parse_entry(REL, edit(text, "verify: null\n", "verify: null\nextra: 1\n"))
    with pytest.raises(EntryError, match="unknown keys"):
        entry.parse_entry(REL, edit(text, "by: coder,", "by: coder, nope: 1,"))
    with pytest.raises(EntryError, match="kind"):
        entry.parse_entry(REL, edit(text, "kind: convention\n", ""))
    with pytest.raises(EntryError, match="expected string"):
        entry.parse_entry(REL, edit(text, "confidence: medium", "confidence: 3"))


def test_split_frontmatter():
    meta, body = entry.split_frontmatter("---\na: 1\nb: [x]\n---\n\n\nhello\n\nworld\n\n")
    assert meta == {"a": 1, "b": ["x"]}
    assert body == "hello\n\nworld"
    assert entry.split_frontmatter("---\na: 1\n---\n---\n") == ({"a": 1}, "---")  # later --- lines are body


def test_error_names_the_file():
    with pytest.raises(EntryError, match=REL):
        entry.parse_entry(REL, "nope")


def test_max_trust():
    assert entry.max_trust(["untrusted", "agent"]) == "agent"
    assert entry.max_trust(["agent", "user", "untrusted"]) == "user"
    assert entry.max_trust(["untrusted"]) == "untrusted"
    assert entry.max_trust(t for t in ["agent", "agent"]) == "agent"
    assert entry.max_trust([]) == "untrusted"
    with pytest.raises(EntryError):
        entry.max_trust(["agent", "root"])


def test_body_limit():
    assert entry.body_limit("reference") == 32768
    assert all(entry.body_limit(k) == 4096 for k in entry.KINDS if k != "reference")


def test_constants():
    assert entry.KINDS == ("fact", "gotcha", "howto", "convention", "preference", "reference")
    assert entry.CONFIDENCES == ("high", "medium", "low")
    assert entry.TRUSTS == ("user", "agent", "untrusted")
    assert set(entry.STATUSES) == {"active", "disputed"}


@pytest.mark.parametrize(
    ("rel", "scope", "name"),
    [
        ("global/x.md", "global", "x"),
        ("lang/typescript/no-enums.md", "lang/typescript", "no-enums"),
        ("topic/git/rebase-0.md", "topic/git", "rebase-0"),
        ("org/acme/ci.md", "org/acme", "ci"),
        ("projects/dotfiles/facts/nix-flakes.md", "projects/dotfiles/facts", "nix-flakes"),
    ],
)
def test_split_rel_good(rel: str, scope: str, name: str):
    assert entry.split_rel(rel) == (scope, name)
    assert entry.entry_rel(scope, name) == rel


@pytest.mark.parametrize(
    "rel",
    [
        "",
        "x.md",  # no scope directory
        "global.md",
        "global/x.txt",
        "global/x",
        "global/.md",
        "global/X.md",
        "global/-x.md",
        "global/" + "x" * 65 + ".md",
        "lang/Typescript/x.md",
        "lang/x.md",  # lang needs a name directory
        "lang/" + "x" * 41 + "/y.md",
        "other/x/y.md",
        "projects/x/overview.md",
        "projects/x/y.md",
        "projects/x/facts/sub/y.md",
        "projects/facts/y.md",
        "/global/x.md",
        "global/../x.md",
        "../global/x.md",
        "global/x.md\n",
        "global/x y.md",
    ],
)
def test_split_rel_bad(rel: str):
    with pytest.raises(EntryError):
        entry.split_rel(rel)


def test_entry_rel_validates():
    for scope, name in [("nope", "x"), ("global", "X"), ("global", ""), ("lang/typescript/", "x"), ("global\n", "x")]:
        with pytest.raises(EntryError):
            entry.entry_rel(scope, name)
