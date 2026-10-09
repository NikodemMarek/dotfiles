import io
import json
import os
from pathlib import Path

import pytest

from knowledge import cli
from knowledge.inbox import Inbox

TOKEN = "glpat-" + "a" * 20

REFERENCE_NOTE = """---
name: widget-notes
description: Notes on widget calibration
metadata:
  type: reference
---

Calibrate the widget twice.
Second line.
"""

PLAIN_NOTE = """---
name: fact-note
description: A plain fact
metadata:
  type: user
---

Body of the fact.
"""


class Tty(io.StringIO):
    def isatty(self) -> bool:
        return True


class Runner:
    def __init__(self, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
        self.monkeypatch = monkeypatch
        self.capsys = capsys

    def __call__(self, *argv: str, stdin: str = "", tty: bool = False) -> tuple[int, str]:
        """Run `knowledge <argv>` with `stdin` piped in, or typed at a terminal: the exit code and stdout."""
        self.monkeypatch.setattr("sys.argv", ["knowledge", *argv])
        self.monkeypatch.setattr("sys.stdin", Tty(stdin) if tty else io.StringIO(stdin))
        code = 0
        try:
            cli.main()
        except SystemExit as e:
            code = int(e.code or 0)
        return code, self.capsys.readouterr().out


@pytest.fixture
def run(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> Runner:
    return Runner(monkeypatch, capsys)


@pytest.fixture
def notes(tmp_path: Path) -> Path:
    d = tmp_path / "notes"
    d.mkdir()
    (d / "widget-notes.md").write_text(REFERENCE_NOTE)
    (d / "fact-note.md").write_text(PLAIN_NOTE)
    (d / "MEMORY.md").write_text("- [Widget notes](widget-notes.md)\n")
    return d


def stored() -> list:
    return Inbox().pending(10**9)


# import


def test_import_agent_trust_works_without_a_terminal(run: Runner, notes: Path):
    code, out = run("import", str(notes), "--trust", "agent")
    assert code == 0
    assert json.loads(out)["imported"] == 2
    by_title = {r.title: r for r in stored()}
    assert set(by_title) == {"Notes on widget calibration", "A plain fact"}
    ref = by_title["Notes on widget calibration"]
    assert ref.kind == "reference"
    assert ref.body == "Calibrate the widget twice.\nSecond line."
    assert ref.trust == "agent"
    assert ref.scope is None
    assert (ref.origin.via, ref.origin.agent, ref.origin.event) == ("import", None, None)
    assert ref.evidence == f"imported from {(notes / 'widget-notes.md').resolve()}"
    fact = by_title["A plain fact"]
    assert fact.kind is None
    assert fact.body == "Body of the fact."
    assert sorted(json.loads(out)["ids"]) == sorted(r.id for r in stored())


def test_import_skips_memory_md_even_when_named(run: Runner, notes: Path):
    code, out = run("import", str(notes / "MEMORY.md"), str(notes / "fact-note.md"), "--trust", "agent")
    assert code == 0
    assert [r.title for r in stored()] == ["A plain fact"]
    assert json.loads(out)["skipped"] == 0


def test_import_only_memory_md_is_a_usage_error(run: Runner, notes: Path):
    assert run("import", str(notes / "MEMORY.md"), "--trust", "agent") == (2, "")
    assert Inbox().count() == 0


def test_import_user_without_a_terminal_exits_2(run: Runner, notes: Path, caplog: pytest.LogCaptureFixture):
    code, out = run("import", str(notes), stdin="y\n")
    assert (code, out) == (2, "")
    assert "--trust agent" in caplog.text
    assert Inbox().count() == 0


def test_import_user_after_confirmation(run: Runner, notes: Path):
    code, out = run("import", str(notes / "fact-note.md"), stdin="y\n", tty=True)
    assert code == 0
    assert json.loads(out)["imported"] == 1
    (rec,) = stored()
    assert (rec.trust, rec.origin.via) == ("user", "import")


@pytest.mark.parametrize("answer", ["", "n\n", "no\n", "\n", "maybe\n"])
def test_import_user_declined_stores_nothing(run: Runner, notes: Path, answer: str):
    code, out = run("import", str(notes), stdin=answer, tty=True)
    assert code == 1
    assert json.loads(out)["imported"] == 0
    assert Inbox().count() == 0


def test_import_skips_a_file_with_a_hard_secret(run: Runner, notes: Path, caplog: pytest.LogCaptureFixture):
    (notes / "leaky.md").write_text(f"---\nname: leaky\ndescription: Deploy notes\n---\n\nuse {TOKEN} to log in\n")
    code, out = run("import", str(notes), "--trust", "agent")
    assert code == 0
    assert json.loads(out)["imported"] == 2
    assert json.loads(out)["skipped"] == 1
    assert "Deploy notes" not in [r.title for r in stored()]
    assert "leaky.md" in caplog.text
    assert "looks like a secret (gitlab-token)" in caplog.text
    assert TOKEN not in caplog.text


def test_import_skips_a_secret_in_the_description(run: Runner, tmp_path: Path):
    note = tmp_path / "n.md"
    note.write_text(f"---\nname: n\ndescription: key {TOKEN}\n---\n\nbody\n")
    code, out = run("import", str(note), "--trust", "agent")
    assert code == 0
    assert json.loads(out)["skipped"] == 1
    assert Inbox().count() == 0


def test_import_skips_a_body_over_64kb(run: Runner, notes: Path, caplog: pytest.LogCaptureFixture):
    (notes / "big.md").write_text("---\nname: big\n---\n\n" + "x" * 65537 + "\n")
    code, out = run("import", str(notes / "big.md"), str(notes / "fact-note.md"), "--trust", "agent")
    assert code == 0
    assert json.loads(out)["imported"] == 1
    assert json.loads(out)["skipped"] == 1
    assert "big.md" in caplog.text
    assert "byte limit" in caplog.text


def test_import_skips_unterminated_frontmatter_and_empty_bodies(run: Runner, tmp_path: Path):
    (tmp_path / "unterminated.md").write_text("---\nname: x\nbody without a fence\n")
    (tmp_path / "empty.md").write_text("---\nname: empty\ndescription: nothing here\n---\n\n")
    (tmp_path / "binary.md").write_bytes(b"\xff\xfe\x00bad")
    code, out = run(
        "import", *(str(tmp_path / n) for n in ("unterminated.md", "empty.md", "binary.md")), "--trust", "agent"
    )
    assert code == 0
    assert (json.loads(out)["imported"], json.loads(out)["skipped"]) == (0, 3)


def test_import_reads_frontmatter_that_is_not_strict_yaml(run: Runner, tmp_path: Path):
    note = tmp_path / "unlock.md"
    note.write_text(
        "---\nname: unlock\ndescription: Remove a login lock: delete the lock rows\nmetadata:\n  type: reference\n---\n\nbody\n"
    )
    (tmp_path / "broken.md").write_text("---\nname: [unclosed\n---\n\nbody\n")
    code, out = run("import", str(note), str(tmp_path / "broken.md"), "--trust", "agent")
    assert code == 0
    assert json.loads(out)["imported"] == 2
    by_title = {r.title: r for r in stored()}
    assert by_title["Remove a login lock: delete the lock rows"].kind == "reference"
    assert "[unclosed" in by_title


@pytest.mark.parametrize(
    ("text", "title"),
    [
        ("---\nname: the-name\ndescription: The   description\n---\n\n# Heading\ntext\n", "The description"),
        ("---\nname: the-name\n---\n\n# Heading\ntext\n", "the-name"),
        ("---\nmetadata:\n  type: user\n---\n\ntext\n\n# Heading here\nmore\n", "Heading here"),
        ("---\ndescription: ''\nname: 5\n---\n\ntext only\n", "title-fallback"),
        ("# Just a heading\n\ntext\n", "Just a heading"),
        ("no frontmatter at all\n", "title-fallback"),
        ("---\ndescription: " + "word " * 80 + "\n---\n\ntext\n", ("word " * 80)[:200].rstrip()),
    ],
)
def test_import_title_falls_back(run: Runner, tmp_path: Path, text: str, title: str):
    note = tmp_path / "title-fallback.md"
    note.write_text(text)
    assert run("import", str(note), "--trust", "agent")[0] == 0
    assert [r.title for r in stored()] == [title]


def test_import_without_frontmatter_keeps_the_whole_text(run: Runner, tmp_path: Path):
    note = tmp_path / "plain.md"
    note.write_text("first\n\nsecond\n")
    assert run("import", str(note), "--trust", "agent")[0] == 0
    assert [r.body for r in stored()] == ["first\n\nsecond"]


def test_import_a_directory_and_a_file_once(run: Runner, notes: Path):
    code, out = run("import", str(notes), str(notes / "fact-note.md"), "--trust", "agent")
    assert code == 0
    assert json.loads(out)["imported"] == 2


def test_import_ignores_other_files_in_a_directory(run: Runner, notes: Path):
    (notes / "README.txt").write_text("not markdown")
    (notes / "sub").mkdir()
    (notes / "sub" / "deep.md").write_text("not looked at")
    assert json.loads(run("import", str(notes), "--trust", "agent")[1])["imported"] == 2


def test_import_missing_path_is_a_usage_error(run: Runner, tmp_path: Path):
    assert run("import", str(tmp_path / "nope.md"), "--trust", "agent") == (2, "")


def test_import_rejects_an_unknown_trust(run: Runner, notes: Path):
    assert run("import", str(notes), "--trust", "untrusted") == (2, "")


def test_import_needs_a_path(run: Runner):
    assert run("import", "--trust", "agent") == (2, "")


# submit --user


def test_submit_user_without_a_terminal_exits_2(run: Runner, caplog: pytest.LogCaptureFixture):
    code, out = run("submit", "--user", "--title", "t", stdin="body")
    assert (code, out) == (2, "")
    assert "needs a terminal" in caplog.text
    assert Inbox().count() == 0


def test_submit_user_stores_in_the_inbox_with_user_trust(run: Runner, tmp_path: Path):
    body = tmp_path / "body.md"
    body.write_text("Rule, why, example.\n")
    code, out = run(
        "submit", "--user", "--title", " I  prefer   tabs ", "--kind", "preference", "--scope", "global",
        "--evidence", "said so", "--file", str(body), tty=True,
    )  # fmt: skip
    assert code == 0
    (rec,) = stored()
    assert out.strip() == rec.id
    assert (rec.title, rec.kind, rec.scope, rec.evidence) == ("I prefer tabs", "preference", "global", "said so")
    assert rec.body == "Rule, why, example.\n"
    assert rec.trust == "user"
    assert (rec.origin.via, rec.origin.agent, rec.origin.event) == ("user", None, None)


def test_submit_user_reads_the_body_typed_at_the_terminal(run: Runner):
    code, _ = run("submit", "--user", "--title", "t", stdin="typed\nbody\n", tty=True)
    assert code == 0
    assert [r.body for r in stored()] == ["typed\nbody\n"]


def test_submit_user_is_refused_in_an_event_launched_run(run: Runner, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture):
    monkeypatch.setenv("KNOWLEDGE_ORIGIN", "event:gitlab.note")
    assert run("submit", "--user", "--title", "t", stdin="body", tty=True) == (2, "")
    assert "KNOWLEDGE_ORIGIN" in caplog.text
    assert "not for agents" in caplog.text
    assert Inbox().count() == 0


def test_submit_user_is_refused_inside_claude_code(run: Runner, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture):
    monkeypatch.setenv("CLAUDECODE", "1")
    assert run("submit", "--user", "--title", "t", stdin="body", tty=True) == (2, "")
    assert "CLAUDECODE" in caplog.text
    assert Inbox().count() == 0


def test_submit_user_is_refused_in_an_event_workspace(
    run: Runner, monkeypatch: pytest.MonkeyPatch, tmp_path: Path, caplog: pytest.LogCaptureFixture
):
    workspace = tmp_path / "repo.agents" / "gl-mr-7" / "src"
    workspace.mkdir(parents=True)
    monkeypatch.chdir(workspace)
    assert run("submit", "--user", "--title", "t", stdin="body", tty=True) == (2, "")
    assert "workspace" in caplog.text
    assert Inbox().count() == 0


def test_submit_user_works_in_another_agents_workspace(run: Runner, monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
    other = tmp_path / "repo.agents" / "curator"  # only `gl-` workspaces are event-launched
    other.mkdir(parents=True)
    monkeypatch.chdir(other)
    assert run("submit", "--user", "--title", "t", stdin="body", tty=True)[0] == 0
    assert [r.trust for r in stored()] == ["user"]


def test_import_user_is_refused_in_an_event_launched_run(
    run: Runner, notes: Path, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
):
    monkeypatch.setenv("KNOWLEDGE_ORIGIN", "event:gitlab.note")
    assert run("import", str(notes), stdin="y\n", tty=True) == (2, "")
    assert "KNOWLEDGE_ORIGIN" in caplog.text
    assert Inbox().count() == 0


def test_import_user_is_refused_inside_claude_code(run: Runner, notes: Path, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture):
    monkeypatch.setenv("CLAUDECODE", "1")
    assert run("import", str(notes), stdin="y\n", tty=True) == (2, "")
    assert "CLAUDECODE" in caplog.text
    assert Inbox().count() == 0


def test_import_user_is_refused_in_an_event_workspace(
    run: Runner, notes: Path, monkeypatch: pytest.MonkeyPatch, tmp_path: Path, caplog: pytest.LogCaptureFixture
):
    workspace = tmp_path / "repo.agents" / "gl-mr-7"
    workspace.mkdir(parents=True)
    monkeypatch.chdir(workspace)
    assert run("import", str(notes), stdin="y\n", tty=True) == (2, "")
    assert "workspace" in caplog.text
    assert Inbox().count() == 0


def test_import_records_where_it_ran(run: Runner, notes: Path):
    assert run("import", str(notes / "fact-note.md"), "--trust", "agent")[0] == 0
    (rec,) = stored()
    assert (rec.trust, rec.origin.via, rec.origin.cwd, rec.origin.event) == ("agent", "import", os.getcwd(), None)


def test_import_agent_from_an_event_launched_run_is_untrusted(run: Runner, notes: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("KNOWLEDGE_ORIGIN", "event:gitlab.note")
    assert run("import", str(notes), "--trust", "agent")[0] == 0
    recs = stored()
    assert [r.trust for r in recs] == ["untrusted", "untrusted"]
    assert {r.origin.event for r in recs} == {"event:gitlab.note"}


def test_import_agent_from_an_event_workspace_is_untrusted(
    run: Runner, notes: Path, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
):
    workspace = tmp_path / "repo.agents" / "gl-mr-7"
    workspace.mkdir(parents=True)
    monkeypatch.chdir(workspace)
    assert run("import", str(notes), "--trust", "agent")[0] == 0
    assert {r.trust for r in stored()} == {"untrusted"}
    assert {r.origin.cwd for r in stored()} == {str(workspace.resolve())}


def test_import_agent_inside_claude_code_is_an_ordinary_agent_import(run: Runner, notes: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("CLAUDECODE", "1")
    assert run("import", str(notes), "--trust", "agent")[0] == 0
    assert {r.trust for r in stored()} == {"agent"}


def test_submit_user_empty_body_is_a_usage_error(run: Runner):
    assert run("submit", "--user", "--title", "t", stdin="\n", tty=True) == (2, "")
    assert Inbox().count() == 0


def test_submit_user_refuses_a_secret(run: Runner, caplog: pytest.LogCaptureFixture):
    code, out = run("submit", "--user", "--title", "t", stdin=f"see {TOKEN}", tty=True)
    assert (code, out) == (2, "")
    assert "refusing to submit: looks like a secret (gitlab-token)" in caplog.text
    assert Inbox().count() == 0
