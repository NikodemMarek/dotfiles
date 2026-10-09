"""Skill ideas: the drafts of the curator, `skill-ideas/<name>.md` in the memory repo.

A draft is a SKILL.md (frontmatter `name` and `description`, then the body) followed by a comment of the curator. The user
copies it to `skills/<name>/SKILL.md` by hand and removes it with `knowledge drop --taken` (the curator may go on improving
that skill), or rejects it with `knowledge drop` (a note in rejected.md). They are not entries: the store, the index and
the scopes never read this directory.
"""

import datetime
import re
from pathlib import Path

from . import data
from .entry import NAME_RE, EntryError
from .ops import SkillOp

DIR = "skill-ideas"
FILE_MODE = 0o644

_NAME = re.compile(NAME_RE)


def rel(name: str) -> str:
    """The path of the idea `name` in the memory repo; EntryError for a name that is not a skill name."""
    if _NAME.fullmatch(name) is None:
        raise EntryError(f"invalid skill name {name!r}")
    return f"{DIR}/{name}.md"


def render(op: SkillOp, today: datetime.date, existing: bool) -> str:
    """The file of an idea. `existing`: a skill of this name is in the skills dir already, so this is an update of it."""
    head = data.dump_yaml({"name": op.name, "description": op.description}, block=True)
    what = f"update of the existing skill skills/{op.name}" if existing else "new skill"
    sources = ", ".join(op.sources) or "-"
    return (
        f"---\n{head}---\n\n{op.body.strip()}\n\n"
        f"<!-- skill idea of the knowledge curator, {today.isoformat()}: {what}\n"
        f"why: {op.summary}\n"
        f"sources: {sources}\n"
        f"Copy to the skills/ dir of your Claude config repo as {op.name}/SKILL.md without this comment, "
        f"then `knowledge drop --taken {rel(op.name)}`; "
        f"or `knowledge drop {rel(op.name)}` to reject the idea. -->\n"
    )


def names(memory: Path) -> list[str]:
    """The names of the ideas that wait in the memory repo, sorted."""
    return sorted(p.stem for p in (memory / DIR).glob("*.md") if p.is_file())
