"""Knowledge curator: collects what agents learn and keeps a curated store in the memory repo."""

import argparse
import datetime
import logging
import sys
from pathlib import Path

from . import config, index, locks, retention
from .config import UsageError
from .data import Json, Obj, ParseError, dumps
from .gitops import Git, GitError
from .scopes import DEFAULT_SCOPES_TOML, SCOPES_FILE
from .store import Store, atomic_write

log = logging.getLogger("knowledge")

GITIGNORE = ".gitignore"
PRIVATE_IGNORE = "private/"
FILE_MODE = 0o644


class Args(argparse.Namespace):
    command: str
    verbose: bool


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="knowledge", description=__doc__)
    p.add_argument("-v", "--verbose", action="store_true")
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("paths", help="print every path, the router URL and the claude binary as JSON")
    sub.add_parser("init", help="prepare the memory repo: SCOPES.toml, .gitignore and KNOWLEDGE.md, committed")
    sub.add_parser("index", help="regenerate KNOWLEDGE.md and commit it if it changed")
    sub.add_parser("lint", help="check the store, SCOPES.toml and the budgets; exit 1 if anything is wrong")
    return p


def _paths() -> Obj:
    return {
        "memory_dir": str(config.memory_dir()),
        "claude_config_dir": str(config.claude_config_dir()),
        "state_dir": str(config.state_dir()),
        "inbox": str(config.inbox_dir()),
        "runtime_dir": str(config.runtime_dir()),
        "ai_repo": str(config.ai_repo()),
        "router_url": config.router_url(),
        "claude": config.claude_bin(),
        "memory_lock": str(locks.memory_lock()),
        "curator_lock": str(locks.curator_lock()),
    }


def _memory() -> Path:
    memory = config.memory_dir()
    if not memory.is_dir():
        raise UsageError(f"{memory} is not a directory")
    return memory


def _git(memory: Path) -> Git:
    """The memory repo, which must be a git repository of its own."""
    git = Git(memory, locks.memory_lock())
    try:
        git.ensure_repo()
    except GitError as e:
        raise UsageError(f"{memory} is not a git repository: {e}") from e
    return git


def _ensure_private_ignored(memory: Path) -> None:
    """`private/` (credentials the curator keeps for the user) must never be committed."""
    path = memory / GITIGNORE
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        text = ""
    if any(line.strip() in (PRIVATE_IGNORE, "/" + PRIVATE_IGNORE) for line in text.splitlines()):
        return
    if text and not text.endswith("\n"):
        text += "\n"
    atomic_write(path, f"{text}{PRIVATE_IGNORE}\n", FILE_MODE)


def _stale_flags(memory: Path) -> dict[str, list[str]]:
    """The markers a curator run writes into the index, so that this does not undo them."""
    store = Store(memory)
    today = datetime.datetime.now(datetime.UTC).date()
    return retention.stale_flags(store.entries(), today, retention.done_slugs(store.projects_index()))


def _init() -> Obj:
    memory = _memory()
    git = _git(memory)
    if not (memory / SCOPES_FILE).exists():
        atomic_write(memory / SCOPES_FILE, DEFAULT_SCOPES_TOML, FILE_MODE)
    _ensure_private_ignored(memory)
    entries = index.regenerate(memory, _stale_flags(memory))
    commit = git.commit([SCOPES_FILE, GITIGNORE, index.INDEX_FILE], "knowledge: init")
    return {"commit": commit, "entries": entries}


def _index() -> Obj:
    memory = _memory()
    git = _git(memory)
    entries = index.regenerate(memory, _stale_flags(memory))
    commit = git.commit([index.INDEX_FILE], "knowledge: update index")
    return {"commit": commit, "entries": entries}


def _lint() -> tuple[Obj, int]:
    store = Store(_memory())
    problems = index.lint(store)
    for problem in problems:
        log.error("%s", problem)
    listed: list[Json] = [p for p in problems]
    return {"ok": not problems, "problems": listed}, 1 if problems else 0


def main() -> None:
    args = _parser().parse_args(namespace=Args())
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(message)s",
        stream=sys.stderr,
    )
    code = 0
    try:
        result: Obj
        if args.command == "paths":
            result = _paths()
        elif args.command == "init":
            result = _init()
        elif args.command == "index":
            result = _index()
        elif args.command == "lint":
            result, code = _lint()
        else:  # argparse accepts only the commands above
            raise UsageError(f"unknown command {args.command}")
        print(dumps(result), flush=True)
    except (ParseError, UsageError) as e:
        log.error("%s", e)
        sys.exit(2)
    except (OSError, ValueError, GitError, locks.LockTimeout) as e:  # ValueError: text that cannot be written out
        log.error("%s", e)
        sys.exit(1)
    if code:
        sys.exit(code)
