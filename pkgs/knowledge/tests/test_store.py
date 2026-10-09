import os
import stat
from dataclasses import replace
from pathlib import Path

import pytest

from knowledge import entry
from knowledge.entry import Entry, EntryError, Source
from knowledge.store import ProjectRow, Store, atomic_write

SOURCE = Source(
    date="2026-10-06",
    by="coder",
    project="dotfiles",
    trust="agent",
    submission="s-20261006T153201Z-a1b2c3",
    evidence="saw it",
)

ENTRY = Entry(
    name="no-enums",
    description="Use string unions, not enums",
    kind="convention",
    scope="lang/typescript",
    tags=("typescript",),
    confidence="medium",
    trust="agent",
    status="active",
    created="2026-10-06",
    updated="2026-10-06",
    last_verified="2026-10-06",
    verify=None,
    related=(),
    sources=(SOURCE,),
    body="Prefer string unions.",
)

# the table shape of the architect's INDEX.md
INDEX = """\
# Projects

| slug | status | repo path | summary |
|------|--------|-----------|---------|
| ai | active | /home/u/projects/ai | Claude config flake (wrapped `claude`, agents) |
| dotfiles | done | `/home/u/projects/dotfiles` | Nix flake + home-manager; a | in the summary |
| shop | active | /home/u/projects/acme/shop-new | Acme shop BFF |

Notes after the table.
"""


def make(scope: str, name: str, **changes: str) -> Entry:
    return replace(ENTRY, scope=scope, name=name, **changes)


@pytest.fixture
def store(tmp_path: Path) -> Store:
    root = tmp_path / "store"
    root.mkdir()
    return Store(root)


def put(store: Store, rel: str, text: str) -> Path:
    path = store.root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


def test_walk_collects_entries_and_ignores_architect_files(store):
    put(store, "projects/dotfiles/overview.md", "# dotfiles\n")
    for rel in ("global/prefs.md", "lang/typescript/no-enums.md", "topic/jj/absorb.md", "org/acme/playbook-x.md"):
        scope, name = entry.split_rel(rel)
        put(store, rel, entry.render_entry(make(scope, name)))
    put(store, "projects/dotfiles/facts/f.md", entry.render_entry(make("projects/dotfiles/facts", "f")))
    for rel in (
        "KNOWLEDGE.md",
        "INDEX.md",
        "README.md",
        "SCOPES.toml",
        "templates/t.md",
        "projects/dotfiles/decisions.md",
        "projects/dotfiles/log.md",
        "projects/dotfiles/notes/n.md",
        "lang/loose.md",
        "private/acme.md",
    ):
        put(store, rel, "not an entry\n")
    put(store, "lang/typescript/notes.txt", "x")

    assert [e.rel for e in store.entries()] == [
        "global/prefs.md",
        "lang/typescript/no-enums.md",
        "org/acme/playbook-x.md",
        "projects/dotfiles/facts/f.md",
        "topic/jj/absorb.md",
    ]
    assert store.errors == []


def test_walk_collects_errors(store):
    put(store, "global/good.md", entry.render_entry(make("global", "good")))
    put(store, "global/plain.md", "no frontmatter\n")
    put(store, "global/Upper.md", entry.render_entry(make("global", "upper")))
    put(store, "topic/jj/mismatch.md", entry.render_entry(make("topic/jj", "other")))
    put(store, "projects/ghost/facts/g.md", entry.render_entry(make("projects/ghost/facts", "g")))  # no overview.md
    (store.root / "lang/typescript").mkdir(parents=True)
    (store.root / "lang/typescript/dir.md").mkdir()
    put(store, "lang/typescript/binary.md", "x")
    (store.root / "lang/typescript/binary.md").write_bytes(b"---\n\xff\xfe\n---\n")

    assert [e.rel for e in store.entries()] == ["global/good.md"]
    assert sorted(rel for rel, _ in store.errors) == [
        "global/Upper.md",
        "global/plain.md",
        "lang/typescript/binary.md",
        "projects/ghost/facts/g.md",
        "topic/jj/mismatch.md",
    ]
    assert all(msg for _, msg in store.errors)
    store.entries()
    assert len(store.errors) == 5  # reset on every walk


def test_entries_in_reads_only_the_scopes_asked_for(store):
    put(store, "projects/dotfiles/overview.md", "# dotfiles\n")
    for rel in ("global/prefs.md", "lang/typescript/no-enums.md", "topic/jj/absorb.md", "projects/dotfiles/facts/f.md"):
        scope, name = entry.split_rel(rel)
        put(store, rel, entry.render_entry(make(scope, name)))
    put(store, "lang/python/broken.md", "no frontmatter\n")
    put(store, "global/plain.md", "no frontmatter\n")

    got = store.entries_in(["projects/dotfiles/facts", "lang/typescript", "global", "global", "topic/missing"])
    assert [e.rel for e in got] == ["global/prefs.md", "lang/typescript/no-enums.md", "projects/dotfiles/facts/f.md"]
    assert [rel for rel, _ in store.errors] == ["global/plain.md"]  # the broken file of lang/python is not looked at
    assert store.entries_in([]) == []
    assert store.errors == []
    assert store.entries_in(["../etc", "private", "projects/dotfiles"]) == []  # not scopes: nothing is read


def test_walk_of_an_empty_store(store):
    assert store.entries() == []
    assert store.errors == []
    assert store.project_slugs() == []
    assert store.projects_index() == []


def test_read(store):
    store.write(ENTRY)
    assert store.read(ENTRY.rel) == ENTRY
    assert store.bytes(ENTRY.rel) == len(entry.render_entry(ENTRY).encode())
    with pytest.raises(FileNotFoundError):
        store.read("global/missing.md")
    with pytest.raises(EntryError):
        store.read("../outside.md")
    with pytest.raises(EntryError):
        store.read("projects/dotfiles/overview.md")


def test_write_creates_directories_and_leaves_no_tmp_file(store):
    store.write(ENTRY)
    path = store.root / ENTRY.rel
    assert path.read_text() == entry.render_entry(ENTRY)
    assert [p.name for p in path.parent.iterdir()] == ["no-enums.md"]

    changed = replace(ENTRY, description="changed")
    store.write(changed)
    assert store.read(ENTRY.rel) == changed
    assert [p.name for p in path.parent.iterdir()] == ["no-enums.md"]


def count_fsyncs(monkeypatch: pytest.MonkeyPatch) -> list[int]:
    calls: list[int] = []
    real = os.fsync

    def fsync(fd: int) -> None:
        calls.append(fd)
        real(fd)

    monkeypatch.setattr(os, "fsync", fsync)
    return calls


def test_a_plain_atomic_write_does_not_sync(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    calls = count_fsyncs(monkeypatch)
    atomic_write(tmp_path / "f", "text\n", 0o600)
    assert calls == []
    assert (tmp_path / "f").read_text() == "text\n"


def test_a_durable_atomic_write_syncs_the_file_and_the_directory(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    calls = count_fsyncs(monkeypatch)
    atomic_write(tmp_path / "f", "text\n", 0o600, durable=True)
    assert len(calls) == 2
    assert (tmp_path / "f").read_text() == "text\n"
    assert [p.name for p in tmp_path.iterdir()] == ["f"]


def test_write_of_an_invalid_entry_changes_nothing(store):
    store.write(ENTRY)
    before = (store.root / ENTRY.rel).read_text()
    with pytest.raises(EntryError):
        store.write(replace(ENTRY, kind="bogus"))
    assert (store.root / ENTRY.rel).read_text() == before
    assert sorted(p.name for p in (store.root / "lang/typescript").iterdir()) == ["no-enums.md"]
    with pytest.raises(EntryError):
        store.write(make("topic/jj", "x", kind="bogus"))
    assert not (store.root / "topic").exists()


def test_facts_need_an_overview(store):
    facts = make("projects/dotfiles/facts", "f")
    with pytest.raises(EntryError, match="overview.md"):
        store.write(facts)
    assert not (store.root / "projects").exists()
    put(store, "projects/dotfiles/overview.md", "# dotfiles\n")
    store.write(facts)
    assert store.read(facts.rel) == facts
    assert store.project_slugs() == ["dotfiles"]


def test_delete_removes_empty_directories(store):
    store.write(ENTRY)
    store.write(make("lang/typescript", "other"))
    store.delete(ENTRY.rel)
    assert (store.root / "lang/typescript").is_dir()  # still holds `other`
    store.delete("lang/typescript/other.md")
    assert not (store.root / "lang").exists()
    assert store.root.is_dir()
    with pytest.raises(FileNotFoundError):
        store.delete("lang/typescript/other.md")


def test_delete_keeps_the_project_directory(store):
    put(store, "projects/dotfiles/overview.md", "# dotfiles\n")
    store.write(make("projects/dotfiles/facts", "f"))
    store.delete("projects/dotfiles/facts/f.md")
    assert not (store.root / "projects/dotfiles/facts").exists()
    assert (store.root / "projects/dotfiles/overview.md").is_file()


def test_project_slugs(store):
    put(store, "projects/dotfiles/overview.md", "x")
    put(store, "projects/kubernetes/overview.md", "x")
    put(store, "projects/no-overview/log.md", "x")
    put(store, "projects/Bad_Name/overview.md", "x")
    put(store, "projects/stray.md", "x")
    assert store.project_slugs() == ["dotfiles", "kubernetes"]


def test_projects_index(store):
    put(store, "INDEX.md", INDEX)
    assert store.projects_index() == [
        ProjectRow("ai", "active", "/home/u/projects/ai"),
        ProjectRow("dotfiles", "done", "/home/u/projects/dotfiles"),
        ProjectRow("shop", "active", "/home/u/projects/acme/shop-new"),
    ]


def test_projects_index_of_the_real_header_only(store):
    put(store, "INDEX.md", "# Projects\n\n| slug | status | repo path | summary |\n|------|--------|-----------|---------|\n")
    assert store.projects_index() == []


def test_private_write_creates_replaces_and_appends(store):
    path = store.private_write("acme", "sandbox db", "user: a\npassword: b\n")
    assert path == store.root / "private" / "acme.md"
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    assert stat.S_IMODE(path.parent.stat().st_mode) == 0o700
    assert path.read_text() == "# acme private notes\n\n## sandbox db\n\nuser: a\npassword: b\n"

    store.private_write("acme", "vpn", "vpn pass")
    store.private_write("acme", "sandbox db", "user: c")
    assert path.read_text() == "# acme private notes\n\n## sandbox db\n\nuser: c\n\n## vpn\n\nvpn pass\n"

    store.private_write("acme", "vpn", "new pass\n\nsecond paragraph")
    assert path.read_text().endswith("## vpn\n\nnew pass\n\nsecond paragraph\n")
    assert path.read_text().count("## sandbox db") == 1
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    assert sorted(p.name for p in path.parent.iterdir()) == ["acme.md"]


def test_private_write_refuses_a_body_with_a_section_heading(store):
    store.private_write("acme", "vpn", "vpn pass")
    store.private_write("acme", "db", "user: a")
    before = (store.root / "private" / "acme.md").read_text()
    with pytest.raises(ValueError, match="## "):
        store.private_write("acme", "vpn", "new pass\n## db\nuser: overwritten")
    assert (store.root / "private" / "acme.md").read_text() == before
    store.private_write("acme", "vpn", "new pass with ## inside and\n### a deeper heading")
    assert store.private_section("acme", "db") == "user: a"  # the other section is intact


def test_private_section_text_and_lines(store):
    assert store.private_text("acme") is None
    assert store.private_section("acme", "db") is None
    assert store.private_lines() == set()
    store.private_write("acme", "db", "user: a\nhost: sandbox.example.com\n\nshort")
    store.private_write("globex", "vpn", "  the vpn secret phrase  ")
    assert store.private_section("acme", "db") == "user: a\nhost: sandbox.example.com\n\nshort"
    assert store.private_section("acme", "nope") is None
    assert store.private_section("nobody", "db") is None
    lines = store.private_lines()
    assert {"host: sandbox.example.com", "the vpn secret phrase"} <= lines  # stripped
    assert not {"user: a", "short", ""} & lines  # under 12 chars


def test_private_write_tightens_an_existing_directory(store):
    (store.root / "private").mkdir(mode=0o755)
    path = store.private_write("acme", "s", "b")
    assert stat.S_IMODE(path.parent.stat().st_mode) == 0o700


def test_private_write_rejects_bad_names(store):
    with pytest.raises(ValueError):
        store.private_write("../x", "s", "b")
    with pytest.raises(ValueError):
        store.private_write("acme", "two\nlines", "b")
    with pytest.raises(ValueError):
        store.private_write("acme", " ", "b")
    assert not (store.root / "private" / "acme.md").exists()
