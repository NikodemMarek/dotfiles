"""The Claude Code hooks: curated knowledge for a new session, and the knowledge blocks of a finished subagent (S12).

A hook must never block or break the session: `run` catches everything, and the command exits 0 whatever happens.
"""

import datetime
import glob
import logging
import os
import time
from collections.abc import Collection, Iterator
from pathlib import Path

from . import config, data, emit, ideas, records, retention
from .blocks import Block, parse_blocks
from .data import Json, Obj, ParseError
from .emit import EmitError
from .entry import KINDS, Entry
from .records import Origin, Record
from .scopes import load_scopes, scopes_for_cwd
from .store import Store

log = logging.getLogger("knowledge")

SESSION_START = "session-start"
SUBAGENT_STOP = "subagent-stop"
HOOKS = (SESSION_START, SUBAGENT_STOP)
DEBUG_LOG = "hook-inputs.log"
DEBUG_MODE = 0o600
DEFAULT_AGENT = "subagent"  # the origin of a block when the hook input does not name the agent type
POST_DELAYS = (0.5,)  # seconds before the one retry of a post: the hook has a timeout of 30 s
POST_TIMEOUT = 3.0  # seconds, per attempt
DEADLINE = 20.0  # seconds after which the blocks that are left are dropped as if the router were down


def _opt(inp: Obj, key: str) -> str | None:
    """A field of the hook input that is a non-empty string; anything else (a missing field, another type) is None."""
    value = inp.get(key)
    return value if isinstance(value, str) and value else None


def _tilde(path: Path) -> str:
    """The path as the user writes it: under the home directory it starts with `~/`."""
    try:
        return f"~/{path.relative_to(Path.home()).as_posix()}"
    except ValueError:
        return str(path)


def _size(line: str) -> int:
    """Bytes a line takes in the context, newline included."""
    return len(line.encode("utf-8")) + 1


# session start


def _counts_line(memory: Path) -> str | None:
    """What waits for the user: the skill ideas."""
    drafts = len(ideas.names(memory))
    if not drafts:
        return None
    return (
        f"{drafts} skill {'idea waits' if drafts == 1 else 'ideas wait'} in {_tilde(memory / ideas.DIR)}/. "
        f"Once the user adopted one as a skill: `knowledge drop --taken {ideas.DIR}/<name>.md`; "
        f"to reject it: `knowledge drop {ideas.DIR}/<name>.md`."
    )


def _entry_line(e: Entry) -> str:
    marks = f"{e.kind}, {e.confidence}" + (", disputed" if e.status == "disputed" else "")
    return f"- [{e.name}]({e.rel}) - {e.description} ({marks})"


def _fit(lines: list[str], scope: str, memory: Path, room: int) -> list[str]:
    """As many of the lines of a scope as fit in `room` bytes, then a line that says how many were left out and where to
    find them; none if even that line does not fit."""
    for shown in range(len(lines), -1, -1):
        out = lines[:shown]
        if shown < len(lines):
            out.append(f"(+{len(lines) - shown} more in {scope}: Grep {_tilde(memory / scope)})")
        if sum(_size(line) for line in out) <= room:
            return out
    return []


def _ranked(entries: list[Entry], today: datetime.date, done: Collection[str]) -> list[Entry]:
    """The most valuable first (S11 score), ties by path."""

    def by_score(e: Entry) -> tuple[float, str]:
        return -retention.score(e, today, done), e.rel

    return sorted(entries, key=by_score)


def session_context(inp: Obj, today: datetime.date | None = None) -> str | None:
    """The text to put in a new session: the knowledge of the scopes that apply to its directory, at most
    `context_bytes`. None if there is neither knowledge nor anything waiting."""
    memory = config.memory_dir()
    cwd = Path(_opt(inp, "cwd") or os.getcwd())
    today = today or datetime.datetime.now(datetime.UTC).date()
    store = Store(memory)
    projects = store.projects_index()
    scopes = scopes_for_cwd(cwd, load_scopes(memory), projects, store.project_slugs())
    entries = store.entries_in(scopes)  # only what applies here is read: this runs at every session start
    done = retention.done_slugs(projects)
    stale = {e.rel for e in retention.stale_entries(entries, today, done)}
    live = [e for e in entries if e.rel not in stale]
    ranked = {s: _ranked([e for e in live if e.scope == s], today, done) for s in scopes}
    footer = _counts_line(memory)
    if footer is None and not any(ranked.values()):
        return None

    head = [
        f"Curated knowledge for this directory (store {_tilde(memory)}, index KNOWLEDGE.md; read an entry before relying on it). "
        "Submit reusable learnings with `knowledge submit` or a ```knowledge block (see the `knowledge` skill)."
    ]
    if any(ranked.values()):
        head.append(f"Scopes: {', '.join(scopes)}")
    cap = config.tunables().context_bytes
    room = cap - sum(_size(line) for line in head) - (_size(footer) if footer is not None else 0)
    body: list[str] = []
    for scope in scopes:
        if not ranked[scope]:
            continue
        lines = _fit([_entry_line(e) for e in ranked[scope]], scope, memory, room)
        room -= sum(_size(line) for line in lines)
        body.extend(lines)
    text = "\n".join([*head, *body, *([footer] if footer is not None else [])])
    raw = text.encode("utf-8")
    return text if len(raw) <= cap else raw[:cap].decode("utf-8", "ignore")


def session_start(inp: Obj) -> Obj | None:
    text = session_context(inp)
    if text is None:
        return None
    return {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": text}}


# subagent stop


def _content_text(content: Json) -> str:
    """The text of a message: the string itself, or the `text` items of a list of content blocks, one per line."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    parts: list[str] = []
    for item in content:
        if isinstance(item, dict) and item.get("type") == "text":
            text = item.get("text")
            if isinstance(text, str):
                parts.append(text)
    return "\n".join(parts)


def _assistant_text(line: str) -> str:
    """The text of a transcript line that is a message of the assistant; "" for any other line, or one that is not JSON."""
    try:
        obj = data.loads(line)
    except (ParseError, RecursionError):
        return ""
    if not isinstance(obj, dict) or obj.get("type") != "assistant":
        return ""
    message = obj.get("message")
    return _content_text(message.get("content")) if isinstance(message, dict) else ""


def last_assistant_text(path: Path) -> str:
    """The text of the last assistant message in a JSONL transcript that has any; "" if there is none or it cannot be read."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    for line in reversed(text.split("\n")):  # not splitlines(): it also splits on U+2028 and the like
        found = _assistant_text(line)
        if found.strip():
            return found
    return ""


def _transcripts(inp: Obj) -> Iterator[Path]:
    """Where the transcript of the subagent may be: the path in the input, then the subagents directory of the session.
    Never the session's own transcript: blocks there are not the subagent's."""
    if (given := _opt(inp, "agent_transcript_path")) is not None:
        yield Path(given)
    session, agent = _opt(inp, "session_id"), _opt(inp, "agent_id")
    if session is not None and agent is not None:
        pattern = f"*/{glob.escape(session)}/subagents/agent-{glob.escape(agent)}.jsonl"
        yield from sorted((config.claude_config_dir() / "projects").glob(pattern))


def agent_text(inp: Obj) -> str:
    """What the subagent said last: `last_assistant_message` if the input has it, else read from a transcript."""
    message = inp.get("last_assistant_message")
    if isinstance(message, str):
        return message
    for path in _transcripts(inp):
        text = last_assistant_text(path)
        if text:
            return text
    return ""


def _record(block: Block, origin: Origin, agent_id: str | None) -> Record:
    """The submission of a block; raises ParseError if it is not valid. A kind that does not exist is left to the curator.

    Its id comes from the session, the agent and the text, so that a subagent that is continued and says the same block
    again does not submit it twice: the inbox and the curator know the id.
    """
    kind = block.kind if block.kind in KINDS else None
    return records.from_event(
        {
            "id": records.stable_id(origin.session or "", agent_id or "", block.title, block.body),
            "title": block.title,
            "body": block.body,
            "kind": kind,
            "scope": block.scope,
            "evidence": block.evidence,
            "origin": records.origin_obj(origin),
        },
        via_router=False,
    )


def _summary(ids: list[str], down: list[str], rejected: list[str], refused: int, invalid: int) -> str:
    text = f"knowledge: queued {len(ids)}" + (f" ({', '.join(ids)})" if ids else "")
    if down:
        text += f"; router down, dropped: {'; '.join(down)}"
    if rejected:
        text += f"; router rejected, dropped: {'; '.join(rejected)}"
    if refused:
        text += f"; refused {refused} block(s) that look like secrets"
    if invalid:
        text += f"; skipped {invalid} invalid block(s)"
    return text


def subagent_stop(inp: Obj) -> Obj | None:
    """Post the knowledge blocks of the subagent's last message to the router; the message for the user, None without blocks.

    The router gets a short retry policy and the whole hook DEADLINE seconds: the hook has a timeout of 30 s.
    """
    if inp.get("stop_hook_active") is True:  # the subagent goes on because a stop hook said so: its message was seen
        return None
    blocks = parse_blocks(agent_text(inp))
    if not blocks:
        return None
    deadline = time.monotonic() + DEADLINE
    origin = Origin(
        via="subagent-stop",
        agent=_opt(inp, "agent_type") or DEFAULT_AGENT,
        cwd=_opt(inp, "cwd"),
        event=config.origin(),
        session=_opt(inp, "session_id"),
    )
    url = config.router_url()
    ids: list[str] = []
    down: list[str] = []  # titles the router did not take because it is not there
    rejected: list[str] = []  # ... because it turned them down
    refused = invalid = 0
    for block in blocks:
        try:
            rec = _record(block, origin, _opt(inp, "agent_id"))
        except ParseError as e:
            log.warning("skipping an invalid knowledge block: %s", e)
            invalid += 1
            continue
        if (secret := emit.hard_secret(rec)) is not None:
            log.warning("refusing a knowledge block: looks like a secret (%s)", secret)
            refused += 1
            continue
        if rec.id in ids:  # the same block twice in a message
            continue
        if down or time.monotonic() >= deadline:  # the router is not there: every retry costs seconds of the hook's timeout
            down.append(rec.title)
            continue
        try:
            emit.post(emit.build_event(rec), url, delays=POST_DELAYS, timeout=POST_TIMEOUT)
        except EmitError as e:
            log.warning("router: %s", e)
            (rejected if e.permanent else down).append(rec.title)
            continue
        ids.append(rec.id)
    return {"systemMessage": _summary(ids, down, rejected, refused, invalid)}


# running


def _read_input() -> Obj:
    return data.as_obj(data.loads(data.read_stdin()), "hook input")


def _debug(name: str, inp: Obj) -> None:
    """KNOWLEDGE_DEBUG=1: append the keys (never the values) of the input, to see what Claude Code sends."""
    if not config.debug():
        return
    keys: list[Json] = [k for k in sorted(inp)]
    line = f"{datetime.datetime.now(datetime.UTC):%Y-%m-%dT%H:%M:%SZ} {name} {data.dumps(keys)}\n"
    try:
        path = config.ensure_private(config.state_dir()) / DEBUG_LOG
        fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, DEBUG_MODE)
        try:
            os.write(fd, line.encode("utf-8", "replace"))
        finally:
            os.close(fd)
    except OSError as e:
        log.warning("cannot write %s: %s", DEBUG_LOG, e)


def run(name: str) -> Obj | None:
    """The JSON the hook prints, or None for nothing. Never raises, and does nothing inside a curator run."""
    if config.curator_active():
        return None
    try:
        inp = _read_input()
        _debug(name, inp)
        return session_start(inp) if name == SESSION_START else subagent_stop(inp)
    except Exception as e:  # anything: a hook must not break the session
        reason = str(e) or type(e).__name__
        log.warning("hook %s failed: %s", name, reason)
        if name == SUBAGENT_STOP:
            return {"systemMessage": f"knowledge hook error: {reason}"}
        return None
