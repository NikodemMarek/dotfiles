import json
import subprocess
from dataclasses import replace
from pathlib import Path

import pytest

from knowledge import cli
from knowledge.entry import Entry, Source
from knowledge.scopes import DEFAULT_SCOPES_TOML
from knowledge.store import Store

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
    sources=(
        Source(
            date="2026-10-06",
            by="coder",
            project=None,
            trust="agent",
            submission="s-20261006T153201Z-a1b2c3",
            evidence="saw it",
        ),
    ),
    body="Prefer string unions.",
)


class Runner:
    def __init__(self, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
        self.monkeypatch = monkeypatch
        self.capsys = capsys

    def __call__(self, *argv: str) -> tuple[int, str]:
        """Run `knowledge <argv>`: the exit code and stdout."""
        self.monkeypatch.setattr("sys.argv", ["knowledge", *argv])
        code = 0
        try:
            cli.main()
        except SystemExit as e:
            code = int(e.code or 0)
        return code, self.capsys.readouterr().out


@pytest.fixture
def run(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> Runner:
    return Runner(monkeypatch, capsys)


def git(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-c", "core.hooksPath=/dev/null", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )
    return proc.stdout


def subjects(repo: Path) -> list[str]:
    return git(repo, "log", "--format=%s").splitlines()


def test_init_writes_the_files_and_commits_once(memory_repo: Path, run: Runner):
    code, out = run("init")
    assert code == 0
    got = json.loads(out)
    assert got["entries"] == 0
    assert got["commit"] == git(memory_repo, "rev-parse", "HEAD").strip()
    assert subjects(memory_repo) == ["knowledge: init", "init"]
    assert (memory_repo / "SCOPES.toml").read_text() == DEFAULT_SCOPES_TOML
    assert (memory_repo / ".gitignore").read_text() == "private/\n"
    assert (memory_repo / "KNOWLEDGE.md").read_text().startswith("# Knowledge index\n")
    assert git(memory_repo, "status", "--porcelain") == ""


def test_init_twice_makes_one_commit(memory_repo: Path, run: Runner):
    assert run("init")[0] == 0
    code, out = run("init")
    assert code == 0
    assert json.loads(out)["commit"] is None
    assert subjects(memory_repo) == ["knowledge: init", "init"]


def test_init_keeps_an_existing_scopes_file_and_gitignore(memory_repo: Path, run: Runner):
    (memory_repo / "SCOPES.toml").write_text("[budget]\nglobal = [5, 4096]\n")
    (memory_repo / ".gitignore").write_text("*.tmp")
    assert run("init")[0] == 0
    assert (memory_repo / "SCOPES.toml").read_text() == "[budget]\nglobal = [5, 4096]\n"
    assert (memory_repo / ".gitignore").read_text() == "*.tmp\nprivate/\n"
    assert "private/" not in git(memory_repo, "ls-files")


def test_init_leaves_other_files_uncommitted(memory_repo: Path, run: Runner):
    (memory_repo / "notes.md").write_text("architect work in progress\n")
    assert run("init")[0] == 0
    assert git(memory_repo, "status", "--porcelain").strip() == "?? notes.md"


def test_init_rejects_a_directory_that_is_not_a_git_repo(tmp_path: Path, run: Runner):
    (tmp_path / "memory").mkdir()
    code, out = run("init")
    assert code == 2
    assert out == ""


def test_init_rejects_a_missing_memory_dir(run: Runner):
    assert run("init")[0] == 2


def test_init_rejects_an_invalid_scopes_file(memory_repo: Path, run: Runner):
    (memory_repo / "SCOPES.toml").write_text("not = [toml")
    assert run("init")[0] == 2
    assert subjects(memory_repo) == ["init"]


def test_index_commits_only_when_it_changed(memory_repo: Path, run: Runner):
    assert run("init")[0] == 0
    Store(memory_repo).write(ENTRY)
    code, out = run("index")
    assert code == 0
    assert json.loads(out)["entries"] == 1
    assert subjects(memory_repo) == ["knowledge: update index", "knowledge: init", "init"]
    index = (memory_repo / "KNOWLEDGE.md").read_text()
    assert "- [no-enums](lang/typescript/no-enums.md) - Use string unions, not enums (convention, medium)" in index
    assert git(memory_repo, "status", "--porcelain").strip() == "?? lang/"  # the entry itself is not committed

    code, out = run("index")
    assert code == 0
    assert json.loads(out)["commit"] is None
    assert len(subjects(memory_repo)) == 3


def test_index_and_init_keep_the_stale_markers_a_curator_run_writes(memory_repo: Path, run: Runner):
    old = replace(ENTRY, kind="fact", last_verified="2020-01-01")  # stale: a fact is stale after 120 days
    Store(memory_repo).write(old)
    Store(memory_repo).write(replace(ENTRY, name="fresh"))
    assert run("index")[0] == 0
    index = (memory_repo / "KNOWLEDGE.md").read_text()
    assert "(fact, medium, stale)" in index
    assert "(convention, medium)" in index
    code, out = run("index")
    assert (code, json.loads(out)["commit"]) == (0, None)  # the markers do not flap between this and a curator run
    assert run("init")[0] == 0
    assert "(fact, medium, stale)" in (memory_repo / "KNOWLEDGE.md").read_text()


def test_index_leaves_out_invalid_entries(memory_repo: Path, run: Runner):
    Store(memory_repo).write(ENTRY)
    Store(memory_repo).write(replace(ENTRY, scope="global", name="ok"))
    (memory_repo / "global" / "bad.md").write_text("no frontmatter\n")
    assert run("index")[0] == 0
    index = (memory_repo / "KNOWLEDGE.md").read_text()
    assert "[ok](global/ok.md)" in index
    assert "bad.md" not in index


def test_lint_exit_codes(memory_repo: Path, run: Runner):
    Store(memory_repo).write(ENTRY)
    code, out = run("lint")
    assert code == 0
    assert json.loads(out) == {"ok": True, "problems": []}

    (memory_repo / "lang" / "typescript" / "bad.md").write_text("no frontmatter\n")
    code, out = run("lint")
    assert code == 1
    got = json.loads(out)
    assert got["ok"] is False
    assert len(got["problems"]) == 1
    assert got["problems"][0].startswith("lang/typescript/bad.md: ")


def test_lint_flags_a_broken_related_path_and_a_broken_scopes_file(memory_repo: Path, run: Runner):
    Store(memory_repo).write(replace(ENTRY, related=("lang/typescript/gone.md",)))
    code, out = run("lint")
    assert code == 1
    assert json.loads(out)["problems"] == [
        "lang/typescript/no-enums.md: related entry lang/typescript/gone.md does not exist"
    ]

    (memory_repo / "SCOPES.toml").write_text("[nonsense]\n")
    code, out = run("lint")
    assert code == 1
    assert any(p.startswith("SCOPES.toml: ") for p in json.loads(out)["problems"])
