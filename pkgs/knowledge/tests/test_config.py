from pathlib import Path

import pytest

from knowledge import config
from knowledge.config import Tunables, UsageError


def test_memory_dir_precedence(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    assert config.memory_dir() == tmp_path / "memory"
    monkeypatch.delenv("CLAUDE_MEMORY_DIR")
    assert config.memory_dir() == tmp_path / "claude" / "memory"
    monkeypatch.delenv("CLAUDE_CONFIG_DIR")
    assert config.memory_dir() == tmp_path / "home" / ".local" / "share" / "claude" / "memory"


def test_claude_config_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    assert config.claude_config_dir() == tmp_path / "claude"
    monkeypatch.delenv("CLAUDE_CONFIG_DIR")
    assert config.claude_config_dir() == tmp_path / "home" / ".local" / "share" / "claude"


def test_an_empty_variable_counts_as_unset(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("CLAUDE_MEMORY_DIR", "")
    assert config.memory_dir() == tmp_path / "claude" / "memory"


def test_state_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    assert config.state_dir() == tmp_path / "state" / "knowledge"
    monkeypatch.delenv("XDG_STATE_HOME")
    assert config.state_dir() == tmp_path / "home" / ".local" / "state" / "knowledge"


def test_runtime_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    assert config.runtime_dir() == tmp_path / "run" / "knowledge"
    monkeypatch.delenv("XDG_RUNTIME_DIR")
    assert config.runtime_dir().parent.name.startswith("user-")
    assert config.runtime_dir().name == "knowledge"
    assert config.runtime_dir().parent.parent == Path("/tmp")


def test_paths_are_not_created_until_asked(tmp_path: Path):
    assert not config.state_dir().exists()
    d = config.ensure_private(config.state_dir())
    assert d.is_dir() and d.stat().st_mode & 0o077 == 0


def test_ai_repo(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    assert config.ai_repo() == tmp_path / "ai"
    monkeypatch.delenv("KNOWLEDGE_AI_REPO")
    assert config.ai_repo() == tmp_path / "home" / "projects" / "ai"


def test_router_url_and_claude_bin(monkeypatch: pytest.MonkeyPatch):
    assert config.router_url() == "http://127.0.0.1:9"
    assert config.claude_bin() == "claude"
    monkeypatch.delenv("EVENT_ROUTER_URL")
    monkeypatch.setenv("KNOWLEDGE_CLAUDE", "/bin/fake-claude")
    assert config.router_url() == "http://127.0.0.1:7531"
    assert config.claude_bin() == "/bin/fake-claude"


def test_flags(monkeypatch: pytest.MonkeyPatch):
    assert config.origin() is None and config.agent_name() is None
    assert not config.curator_active() and not config.debug()
    monkeypatch.setenv("KNOWLEDGE_ORIGIN", "event:gitlab.note")
    monkeypatch.setenv("KNOWLEDGE_AGENT", "coder")
    monkeypatch.setenv("KNOWLEDGE_CURATOR", "1")
    monkeypatch.setenv("KNOWLEDGE_DEBUG", "1")
    assert config.origin() == "event:gitlab.note" and config.agent_name() == "coder"
    assert config.curator_active() and config.debug()
    monkeypatch.setenv("KNOWLEDGE_CURATOR", "0")
    assert not config.curator_active()


def test_in_claude_code(monkeypatch: pytest.MonkeyPatch):
    assert not config.in_claude_code()
    monkeypatch.setenv("CLAUDECODE", "")
    assert not config.in_claude_code()
    monkeypatch.setenv("CLAUDECODE", "1")
    assert config.in_claude_code()


def test_tunable_defaults():
    t = config.tunables()
    assert t == Tunables()
    assert (t.trigger_count, t.max_batch_bytes) == (25, 400000)
    assert t.timeout == 900
    assert (t.context_bytes, t.model, t.effort) == (3072, "sonnet", "medium")


def test_tunable_overrides(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("KNOWLEDGE_TRIGGER_COUNT", "3")
    monkeypatch.setenv("KNOWLEDGE_MODEL", "opus")
    monkeypatch.setenv("KNOWLEDGE_EFFORT", "high")
    monkeypatch.setenv("KNOWLEDGE_TIMEOUT", "60")
    t = config.tunables()
    assert t.trigger_count == 3 and t.model == "opus" and t.effort == "high"
    assert t.timeout == 60


@pytest.mark.parametrize(
    "name",
    [
        "KNOWLEDGE_TRIGGER_COUNT",
        "KNOWLEDGE_MAX_BATCH_BYTES",
        "KNOWLEDGE_TIMEOUT",
        "KNOWLEDGE_CONTEXT_BYTES",
    ],
)
@pytest.mark.parametrize("value", ["abc", "1.5", "0", "-3"])
def test_invalid_integer_tunables_are_usage_errors(monkeypatch: pytest.MonkeyPatch, name: str, value: str):
    monkeypatch.setenv(name, value)
    with pytest.raises(UsageError, match=name):
        config.tunables()
