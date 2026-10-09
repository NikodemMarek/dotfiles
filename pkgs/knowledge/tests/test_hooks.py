import datetime
import io
import json
import re
from dataclasses import replace
from pathlib import Path

import pytest

from fake_router import closed_port_url, serve
from knowledge import cli, config, emit, hooks, scopes
from knowledge.entry import Entry
from knowledge.store import Store

TOKEN = "glpat-" + "a" * 20
ID = re.compile(r"s-\d{8}T\d{6}Z-[0-9a-f]{6}")
TODAY = datetime.datetime.now(datetime.UTC).date()


class Hook:
    def __init__(self, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
        self.monkeypatch = monkeypatch
        self.capsys = capsys

    def __call__(self, name: str, payload: object) -> tuple[int, str]:
        """Run `knowledge hook <name>` with the payload (JSON, or text as it is) on stdin: the exit code and stdout."""
        stdin = payload if isinstance(payload, str) else json.dumps(payload)
        self.monkeypatch.setattr("sys.argv", ["knowledge", "hook", name])
        self.monkeypatch.setattr("sys.stdin", io.StringIO(stdin))
        code = 0
        try:
            cli.main()
        except SystemExit as e:
            code = int(e.code or 0)
        return code, self.capsys.readouterr().out

    def context(self, cwd: Path | str) -> str:
        """The additionalContext a new session in `cwd` gets, "" if there is none."""
        code, out = self("session-start", {"session_id": "s1", "cwd": str(cwd), "hook_event_name": "SessionStart", "source": "startup"})
        assert code == 0
        if not out:
            return ""
        assert out.count("\n") == 1
        got = json.loads(out)["hookSpecificOutput"]
        assert got["hookEventName"] == "SessionStart"
        return got["additionalContext"]

    def stop(self, **fields: object) -> tuple[int, dict | None]:
        """Run subagent-stop: the exit code and the JSON it printed (None if nothing)."""
        payload = {"session_id": "sess1", "cwd": "/home/u/projects/dotfiles", "hook_event_name": "SubagentStop", "agent_id": "a1b2c3"}
        code, out = self("subagent-stop", {**payload, **fields})
        assert out == "" or out.count("\n") == 1
        return code, json.loads(out) if out else None


@pytest.fixture
def hook(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> Hook:
    monkeypatch.setattr(emit.time, "sleep", lambda s: None)
    return Hook(monkeypatch, capsys)


# the store


def ago(days: int) -> str:
    return (TODAY - datetime.timedelta(days=days)).isoformat()


def entry(scope: str, name: str, **changes: object) -> Entry:
    base = Entry(
        name=name,
        description=f"about {name}",
        kind="gotcha",
        scope=scope,
        tags=(),
        confidence="medium",
        trust="agent",
        status="active",
        created=ago(1),
        updated=ago(1),
        last_verified=ago(1),
        verify=None,
        related=(),
        sources=(),
        body="Rule.",
    )
    return replace(base, **changes)


@pytest.fixture
def memory(tmp_path: Path) -> Store:
    (tmp_path / "memory").mkdir()
    return Store(tmp_path / "memory")


@pytest.fixture
def work(tmp_path: Path, memory: Store) -> Path:
    """The repo of the project app, under the work path of SCOPES.toml, with a tsconfig.json."""
    extra = '\n[[path]]\nprefix = "~/projects/work"\nscopes = ["org/work"]\n'
    (memory.root / "SCOPES.toml").write_text(scopes.DEFAULT_SCOPES_TOML + extra)
    repo = tmp_path / "home" / "projects" / "work" / "app"
    (repo / ".git").mkdir(parents=True)
    (repo / "tsconfig.json").write_text("{}")
    project = memory.root / "projects" / "app"
    project.mkdir(parents=True)
    (project / "overview.md").write_text("# app\n")
    (memory.root / "INDEX.md").write_text(f"| slug | status | repo |\n|---|---|---|\n| app | active | {repo} |\n")
    return repo


# session-start


def test_session_start_scopes_the_knowledge_to_the_directory(hook: Hook, memory: Store, work: Path):
    for scope, name in [
        ("global", "commit-style"),
        ("lang/typescript", "no-enums"),
        ("org/work", "vpn"),
        ("projects/app/facts", "api-quirk"),
        ("lang/python", "not-here"),  # no pyproject.toml
        ("topic/jj", "not-here-either"),  # no .jj
    ]:
        memory.write(entry(scope, name))
    text = hook.context(work)
    lines = text.splitlines()
    assert lines[0].startswith(f"Curated knowledge for this directory (store {memory.root}, index KNOWLEDGE.md; read an entry before relying on it).")
    assert "`knowledge submit` or a ```knowledge block (see the `knowledge` skill)." in lines[0]
    assert lines[1] == "Scopes: projects/app/facts, org/work, lang/typescript, global"
    assert lines[2:] == [
        "- [api-quirk](projects/app/facts/api-quirk.md) - about api-quirk (gotcha, medium)",
        "- [vpn](org/work/vpn.md) - about vpn (gotcha, medium)",
        "- [no-enums](lang/typescript/no-enums.md) - about no-enums (gotcha, medium)",
        "- [commit-style](global/commit-style.md) - about commit-style (gotcha, medium)",
    ]


def test_session_start_treats_an_agent_workspace_as_its_repo(hook: Hook, memory: Store, work: Path):
    memory.write(entry("lang/typescript", "no-enums"))
    memory.write(entry("projects/app/facts", "api-quirk"))
    workspace = work.parent / "app.agents" / "gl-mr-7" / "src"  # does not exist
    assert hook.context(workspace) == hook.context(work)
    assert "lang/typescript" in hook.context(workspace)


def test_session_start_outside_any_known_place_gives_global_only(hook: Hook, memory: Store, tmp_path: Path):
    memory.write(entry("global", "g"))
    memory.write(entry("lang/typescript", "no-enums"))
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    assert hook.context(elsewhere).splitlines()[1:] == ["Scopes: global", "- [g](global/g.md) - about g (gotcha, medium)"]


def test_session_start_reads_only_the_entries_of_the_scopes_that_apply(
    hook: Hook, memory: Store, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    memory.write(entry("global", "g"))
    memory.write(entry("lang/typescript", "no-enums"))
    for scope in ("lang/python", "org/work", "topic/jj"):
        (memory.root / scope).mkdir(parents=True)
        (memory.root / scope / "broken.md").write_text("not an entry\n")
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    (elsewhere / "tsconfig.json").write_text("{}")
    read: list[str] = []
    real = Store.read

    def spy(self: Store, rel: str) -> Entry:
        read.append(rel)
        return real(self, rel)

    monkeypatch.setattr(Store, "read", spy)
    lines = hook.context(elsewhere).splitlines()
    assert lines[1] == "Scopes: lang/typescript, global"
    assert sorted(read) == ["global/g.md", "lang/typescript/no-enums.md"]  # the broken files are never opened


def test_session_start_leaves_out_stale_entries(hook: Hook, memory: Store, tmp_path: Path):
    old = {"created": ago(400), "updated": ago(200), "last_verified": ago(200)}
    memory.write(entry("global", "stale-fact", kind="fact", **old))  # a fact has a half-life of 60 days
    memory.write(entry("global", "old-convention", kind="convention", **old))  # 365 days: not stale yet
    text = hook.context(tmp_path)
    assert "stale-fact" not in text
    assert "old-convention" in text


def test_session_start_ranks_by_score_and_marks_disputed(hook: Hook, memory: Store, tmp_path: Path):
    memory.write(entry("global", "a-low", confidence="low"))
    memory.write(entry("global", "b-high", confidence="high"))
    memory.write(entry("global", "c-disputed", confidence="high", status="disputed"))
    lines = hook.context(tmp_path).splitlines()
    assert [line.split("]")[0] for line in lines[2:]] == ["- [b-high", "- [c-disputed", "- [a-low"]
    assert lines[3].endswith("(gotcha, high, disputed)")


def test_session_start_keeps_to_the_byte_cap_and_says_what_it_left_out(
    hook: Hook, memory: Store, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    for i in range(10):
        memory.write(entry("global", f"entry-{i}", description="x" * 100))
    monkeypatch.setenv("KNOWLEDGE_CONTEXT_BYTES", "1200")
    text = hook.context(tmp_path)
    assert len(text.encode()) <= 1200
    shown = sum(1 for line in text.splitlines() if line.startswith("- ["))
    more = re.search(r"^\(\+(\d+) more in global: Grep (\S+)\)$", text, re.MULTILINE)
    assert more is not None
    assert 1 <= shown < 10
    assert shown + int(more.group(1)) == 10
    assert more.group(2) == str(memory.root / "global")
    assert text.splitlines()[-1] == more.group(0)
    monkeypatch.setenv("KNOWLEDGE_CONTEXT_BYTES", "100000")
    assert "more in" not in hook.context(tmp_path)


def test_session_start_shows_the_store_under_the_home_directory_with_a_tilde(hook: Hook, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("CLAUDE_MEMORY_DIR", str(tmp_path / ".local" / "share" / "claude" / "memory"))
    store = Store(tmp_path / ".local" / "share" / "claude" / "memory")
    store.write(entry("global", "g"))
    assert hook.context(tmp_path).startswith("Curated knowledge for this directory (store ~/.local/share/claude/memory, index")


def test_session_start_counts_the_skill_ideas(hook: Hook, memory: Store, tmp_path: Path):
    memory.write(entry("global", "g"))
    drafts = memory.root / "skill-ideas"
    drafts.mkdir()
    (drafts / "a-skill.md").write_text("---\nname: a-skill\ndescription: Use when a.\n---\n\nDo a.\n")
    lines = hook.context(tmp_path).splitlines()
    assert lines[-1].startswith(f"1 skill idea waits in {memory.root}/skill-ideas/. ")
    assert lines[-2].startswith("- [g]")
    assert not any("a-skill" in line for line in lines)  # an idea is not an entry
    (drafts / "b-skill.md").write_text("draft\n")
    assert hook.context(tmp_path).splitlines()[-1].startswith(f"2 skill ideas wait in {memory.root}/skill-ideas/. ")


def test_the_footer_says_how_to_take_or_reject_an_idea(hook: Hook, memory: Store, tmp_path: Path):
    (memory.root / "skill-ideas").mkdir()
    (memory.root / "skill-ideas" / "a-skill.md").write_text("draft\n")
    footer = hook.context(tmp_path).splitlines()[-1]
    assert "`knowledge drop --taken skill-ideas/<name>.md`" in footer
    assert "to reject it: `knowledge drop skill-ideas/<name>.md`" in footer


def test_session_start_with_only_skill_ideas(hook: Hook, memory: Store, tmp_path: Path):
    (memory.root / "skill-ideas").mkdir()
    (memory.root / "skill-ideas" / "a-skill.md").write_text("draft\n")
    lines = hook.context(tmp_path).splitlines()
    assert len(lines) == 2
    assert lines[0].startswith("Curated knowledge")
    assert lines[1].startswith(f"1 skill idea waits in {memory.root}/skill-ideas/. ")


def test_session_start_says_nothing_for_an_empty_store(hook: Hook, tmp_path: Path):
    assert hook.context(tmp_path) == ""  # not even a memory dir
    (tmp_path / "memory").mkdir()
    assert hook.context(tmp_path) == ""


def test_session_start_says_nothing_inside_a_curator_run(hook: Hook, memory: Store, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    memory.write(entry("global", "g"))
    assert hook.context(tmp_path) != ""
    monkeypatch.setenv("KNOWLEDGE_CURATOR", "1")
    assert hook("session-start", {"cwd": str(tmp_path)}) == (0, "")


@pytest.mark.parametrize("stdin", ["", "not json", "[]", '{"cwd": 5}'])
def test_session_start_never_fails(hook: Hook, memory: Store, stdin: str):
    memory.write(entry("global", "g"))
    code, out = hook("session-start", stdin)
    assert code == 0
    if out:  # a cwd that is not text is not a reason to say nothing
        assert json.loads(out)["hookSpecificOutput"]["hookEventName"] == "SessionStart"


def test_session_start_with_a_broken_scopes_file_says_nothing(hook: Hook, memory: Store, tmp_path: Path):
    memory.write(entry("global", "g"))
    (memory.root / "SCOPES.toml").write_text("[[path]\nnot toml")
    assert hook("session-start", {"cwd": str(tmp_path)}) == (0, "")


# subagent-stop


def block(title: str = "jj absorb needs --into", kind: str = "gotcha", scope: str = "topic/jj", body: str = "Rule, why, example.") -> str:
    return f"```knowledge\ntitle: {title}\nkind: {kind}\nscope: {scope}\nevidence: dotfiles 2026-10-06\n---\n{body}\n```"


def test_subagent_stop_posts_the_block_of_the_last_message(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = hook.stop(last_assistant_message=f"All done.\n\n{block()}\n", agent_type="coder")
    assert code == 0
    assert out is not None
    msg = out["systemMessage"]
    (sid,) = ID.findall(msg)
    assert msg == f"knowledge: queued 1 ({sid})"
    assert router.events == [
        {
            "type": "knowledge.submit",
            "id": sid,
            "title": "jj absorb needs --into",
            "body": "Rule, why, example.",
            "kind": "gotcha",
            "scope": "topic/jj",
            "evidence": "dotfiles 2026-10-06",
            "origin": {"via": "subagent-stop", "agent": "coder", "cwd": "/home/u/projects/dotfiles", "event": None, "session": "sess1"},
        }
    ]


def test_subagent_stop_names_the_agent_and_the_event(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("KNOWLEDGE_ORIGIN", "event:gitlab.note")
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        assert hook.stop(last_assistant_message=block())[0] == 0
    assert router.events[0]["origin"]["agent"] == "subagent"
    assert router.events[0]["origin"]["event"] == "event:gitlab.note"


def test_subagent_stop_posts_every_block_and_leaves_an_unknown_kind_to_the_curator(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    text = block("first") + "\ntext between\n" + block("second", kind="nonsense", scope="Not A Scope")
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = hook.stop(last_assistant_message=text)
    assert code == 0
    assert out is not None
    assert re.fullmatch(r"knowledge: queued 2 \(s-[0-9a-f\-TZ]+, s-[0-9a-f\-TZ]+\)", out["systemMessage"])
    assert [(e["title"], e["kind"], e["scope"]) for e in router.events] == [("first", "gotcha", "topic/jj"), ("second", None, None)]


def assistant(*content: object) -> dict:
    return {"type": "assistant", "message": {"role": "assistant", "content": list(content)}}


def jsonl(path: Path, *lines: object) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join((line if isinstance(line, str) else json.dumps(line)) + "\n" for line in lines))
    return path


def subagent_file(tmp_path: Path) -> Path:
    return tmp_path / "claude" / "projects" / "x" / "sess1" / "subagents" / "agent-a1b2c3.jsonl"


def test_subagent_stop_reads_the_transcript_of_the_subagent(hook: Hook, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    jsonl(
        subagent_file(tmp_path),
        {"type": "user", "message": {"role": "user", "content": block("not this one")}},
        assistant({"type": "text", "text": block("nor this one")}),
        "{ this line is not json",
        assistant({"type": "thinking", "thinking": "hm"}, {"type": "text", "text": "Done.\n\n" + block("found it")}),
        assistant({"type": "tool_use", "id": "t1", "name": "Read", "input": {}}),  # no text: not the message
        "",
        "[1, 2]",
        "{not json either",
    )
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = hook.stop()
    assert code == 0
    assert out is not None and out["systemMessage"].startswith("knowledge: queued 1 (")
    assert [e["title"] for e in router.events] == ["found it"]


def test_subagent_stop_reads_a_message_that_is_a_string_and_joins_text_items(hook: Hook, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    path = jsonl(
        tmp_path / "elsewhere.jsonl",
        {"type": "assistant", "message": {"role": "assistant", "content": block("from a string")}},
    )
    other = jsonl(
        tmp_path / "other.jsonl",
        assistant({"type": "text", "text": "```knowledge\ntitle: split"}, {"type": "text", "text": "---\nbody\n```"}),
    )
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        hook.stop(agent_transcript_path=str(path))
        hook.stop(agent_transcript_path=str(other))
    assert [e["title"] for e in router.events] == ["from a string", "split"]


def test_subagent_stop_prefers_the_message_then_the_agent_path_then_the_directory_never_the_session(
    hook: Hook, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    given = jsonl(tmp_path / "given.jsonl", assistant({"type": "text", "text": block("path")}))
    jsonl(subagent_file(tmp_path), assistant({"type": "text", "text": block("directory")}))
    main = jsonl(tmp_path / "main.jsonl", assistant({"type": "text", "text": block("session")}))
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        hook.stop(last_assistant_message=block("message"), agent_transcript_path=str(given), transcript_path=str(main))
        hook.stop(agent_transcript_path=str(given), transcript_path=str(main))
        hook.stop(agent_transcript_path=str(tmp_path / "missing.jsonl"), transcript_path=str(main))
        subagent_file(tmp_path).unlink()
        hook.stop(agent_transcript_path=str(tmp_path / "missing.jsonl"), transcript_path=str(main))
        hook.stop(last_assistant_message=None, agent_id=None, transcript_path=str(main))
    assert [e["title"] for e in router.events] == ["message", "path", "directory"]


def test_subagent_stop_without_any_text_says_nothing(hook: Hook, tmp_path: Path):
    assert hook.stop() == (0, None)
    assert hook.stop(transcript_path=str(tmp_path / "missing.jsonl")) == (0, None)
    assert hook.stop(last_assistant_message=["not", "a", "string"], agent_transcript_path=str(tmp_path)) == (0, None)


def test_subagent_stop_a_message_without_blocks_says_nothing(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        assert hook.stop(last_assistant_message="Nothing new.\n```python\nprint(1)\n```\n") == (0, None)
        assert hook.stop(last_assistant_message="```knowledge\nkind: gotcha\n---\nno title\n```") == (0, None)
    assert router.requests == []


def test_subagent_stop_router_down_names_what_was_dropped(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("EVENT_ROUTER_URL", closed_port_url())
    code, out = hook.stop(last_assistant_message=block("first") + "\n" + block("second"))
    assert code == 0
    assert out == {"systemMessage": "knowledge: queued 0; router down, dropped: first; second"}


def test_subagent_stop_gives_up_on_a_router_that_is_down_after_the_first_block(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    with serve(503) as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = hook.stop(last_assistant_message=block("first") + "\n" + block("second"))
    assert code == 0
    assert out == {"systemMessage": "knowledge: queued 0; router down, dropped: first; second"}
    assert len(router.requests) == len(hooks.POST_DELAYS) + 1 == 2  # the short retry policy, the first block only


def test_subagent_stop_drops_what_is_left_when_the_deadline_has_passed(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(hooks, "DEADLINE", 0.0)
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = hook.stop(last_assistant_message=block("first") + "\n" + block("second"))
    assert code == 0
    assert out == {"systemMessage": "knowledge: queued 0; router down, dropped: first; second"}
    assert router.requests == []


def test_subagent_stop_posts_with_the_short_retry_policy(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    seen: list[tuple[object, object]] = []

    def post(event: object, url: str, delays: object = (), timeout: object = 0.0) -> None:
        seen.append((delays, timeout))

    monkeypatch.setattr(emit, "post", post)
    hook.stop(last_assistant_message=block())
    assert seen == [((0.5,), 3.0)]


def test_subagent_stop_gives_a_block_the_same_id_every_time_it_is_posted(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        first = hook.stop(last_assistant_message=block())
        again = hook.stop(last_assistant_message=f"I went on.\n\n{block()}")  # the continued subagent says it again
        other_agent = hook.stop(last_assistant_message=block(), agent_id="zzz")
        other_session = hook.stop(last_assistant_message=block(), session_id="sess2")
        other_text = hook.stop(last_assistant_message=block(body="Another rule."))
        twice = hook.stop(last_assistant_message=block() + "\n" + block())
    ids = [e["id"] for e in router.events]
    assert ids[0] == ids[1] == ids[5]
    assert len({ids[0], ids[2], ids[3], ids[4]}) == 4
    assert all(ID.fullmatch(i) for i in ids)
    assert first == again
    assert twice[1] is not None and len(ID.findall(twice[1]["systemMessage"])) == 1  # posted once, not twice
    assert len(router.events) == 6
    assert other_agent[0] == other_session[0] == other_text[0] == 0


def test_subagent_stop_says_nothing_while_a_stop_hook_keeps_the_subagent_going(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        assert hook.stop(last_assistant_message=block(), stop_hook_active=True) == (0, None)
        assert hook.stop(last_assistant_message=block(), stop_hook_active=False)[1] is not None
    assert len(router.requests) == 1


def test_subagent_stop_goes_on_after_a_block_the_router_rejects(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    with serve(400, 202) as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = hook.stop(last_assistant_message=block("first") + "\n" + block("second"))
    assert code == 0
    assert out is not None
    (sid,) = ID.findall(out["systemMessage"])
    assert out["systemMessage"] == f"knowledge: queued 1 ({sid}); router rejected, dropped: first"
    assert [e["title"] for e in router.events] == ["first", "second"]


def test_subagent_stop_refuses_a_secret(hook: Hook, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = hook.stop(last_assistant_message=block("leaky", body=f"the token is {TOKEN}"))
        assert code == 0
        assert out == {"systemMessage": "knowledge: queued 0; refused 1 block(s) that look like secrets"}
        assert router.requests == []
        code, out = hook.stop(last_assistant_message=block("leaky", body=f"the token is {TOKEN}") + "\n" + block("fine"))
    assert out is not None
    assert out["systemMessage"].endswith("; refused 1 block(s) that look like secrets")
    assert out["systemMessage"].startswith("knowledge: queued 1 (")
    assert [e["title"] for e in router.events] == ["fine"]
    assert TOKEN not in caplog.text
    assert TOKEN not in out["systemMessage"]


def test_subagent_stop_refuses_a_secret_in_the_origin(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = hook.stop(last_assistant_message=block(), cwd=f"/work/{TOKEN}")
    assert code == 0
    assert out == {"systemMessage": "knowledge: queued 0; refused 1 block(s) that look like secrets"}
    assert router.requests == []


def test_subagent_stop_skips_a_block_that_is_not_a_valid_submission(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        code, out = hook.stop(last_assistant_message=block("t" * 201) + "\n" + block("fine"))
    assert code == 0
    assert out is not None
    assert out["systemMessage"].endswith("; skipped 1 invalid block(s)")
    assert [e["title"] for e in router.events] == ["fine"]


def test_subagent_stop_says_nothing_inside_a_curator_run(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("KNOWLEDGE_CURATOR", "1")
    with serve() as router:
        monkeypatch.setenv("EVENT_ROUTER_URL", router.url)
        assert hook.stop(last_assistant_message=block()) == (0, None)
    assert router.requests == []


@pytest.mark.parametrize("stdin", ["", "not json", "[]"])
def test_subagent_stop_reports_input_it_cannot_read_and_exits_0(hook: Hook, stdin: str):
    code, out = hook("subagent-stop", stdin)
    assert code == 0
    assert out.startswith('{"systemMessage":"knowledge hook error: ')


def test_subagent_stop_reports_an_unexpected_error_and_exits_0(hook: Hook, monkeypatch: pytest.MonkeyPatch):
    def boom(event: object, url: str, **kwargs: object) -> None:
        raise RuntimeError("boom")

    monkeypatch.setattr(emit, "post", boom)
    code, out = hook.stop(last_assistant_message=block())
    assert (code, out) == (0, {"systemMessage": "knowledge hook error: boom"})


# KNOWLEDGE_DEBUG


def test_debug_logs_the_keys_of_the_input_and_not_the_values(hook: Hook, memory: Store, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    memory.write(entry("global", "g"))
    log = config.state_dir() / "hook-inputs.log"
    hook("session-start", {"cwd": str(tmp_path), "session_id": "secret-session-value"})
    assert not log.exists()  # off by default
    monkeypatch.setenv("KNOWLEDGE_DEBUG", "1")
    hook("session-start", {"cwd": str(tmp_path), "session_id": "secret-session-value"})
    hook.stop(last_assistant_message="a secret value", agent_type="coder")
    lines = log.read_text().splitlines()
    assert len(lines) == 2
    assert re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ session-start \["cwd","session_id"\]', lines[0])
    assert lines[1].endswith(
        ' subagent-stop ["agent_id","agent_type","cwd","hook_event_name","last_assistant_message","session_id"]'
    )
    assert "secret" not in log.read_text().replace("session_id", "")
    assert log.stat().st_mode & 0o777 == 0o600


def test_debug_is_a_no_op_inside_a_curator_run(hook: Hook, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("KNOWLEDGE_DEBUG", "1")
    monkeypatch.setenv("KNOWLEDGE_CURATOR", "1")
    hook("session-start", {"cwd": str(tmp_path)})
    assert not (config.state_dir() / "hook-inputs.log").exists()


# the command


def test_an_unknown_hook_is_a_usage_error(hook: Hook):
    assert hook("nonsense", {})[0] == 2


def test_closed_stdout_does_not_change_the_exit_code(memory: Store, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    memory.write(entry("global", "g"))

    def broken(*args: object, **kwargs: object) -> None:
        raise BrokenPipeError("closed")

    monkeypatch.setattr("builtins.print", broken)
    monkeypatch.setattr("sys.argv", ["knowledge", "hook", "session-start"])
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps({"cwd": str(tmp_path)})))
    cli.main()  # returns, no SystemExit
