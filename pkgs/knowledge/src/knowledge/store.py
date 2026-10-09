"""The knowledge store: entries under the memory dir, INDEX.md rows and private files (S2, S6)."""

import os
import re
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

from .data import ParseError
from .entry import NAME_RE, SCOPE_RE, Entry, EntryError, parse_entry, render_entry, split_rel

_NAME = re.compile(NAME_RE)
_SCOPE = re.compile(SCOPE_RE)
_SEPARATOR_CELL = re.compile(r":?-+:?")

# the directories that hold entries: global/, lang/*/, topic/*/, org/*/, projects/*/facts/
_SCOPE_GLOBS = ("global", "lang/*", "topic/*", "org/*", "projects/*/facts")

ENTRY_MODE = 0o644
PRIVATE_DIR = "private"
PRIVATE_FILE_MODE = 0o600
PRIVATE_DIR_MODE = 0o700
MIN_PRIVATE_LINE = 12  # chars of a private line that an entry must not repeat


@dataclass(frozen=True)
class ProjectRow:
    """One row of the architect's `INDEX.md` table."""

    slug: str
    status: str
    repo: str  # repo path


def atomic_write(path: Path, text: str, mode: int, durable: bool = False) -> None:
    """Write `text` to a tmp file next to `path`, then rename it over `path`.

    `durable`: the file and then the directory are synced, so the file survives a crash once this returns.
    """
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
            if durable:
                f.flush()
                os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise
    if durable:
        dir_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)


def has_section_heading(body: str) -> bool:
    """A line of `body` that starts with `## `: in a private file it would start another section."""
    return any(line.startswith("## ") for line in body.splitlines())


def _section_range(lines: list[str], header: str) -> tuple[int, int] | None:
    """The lines of the section `header` (the heading line included), up to the next `## ` line."""
    if header not in lines:
        return None
    start = lines.index(header)
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    return start, end


def _replace_section(text: str, section: str, body: str) -> str:
    """`## <section>` and its text up to the next `## ` replaced, or appended if there is none.

    A body with a `## ` line would split the section it is put in, so it is refused.
    """
    if has_section_heading(body):
        raise ValueError("a private body must not hold a line that starts with '## '")
    header = f"## {section}"
    block = [header, "", *body.strip("\n").splitlines(), ""]
    lines = text.splitlines()
    found = _section_range(lines, header)
    if found is not None:
        lines[found[0] : found[1]] = block
    else:
        if lines and lines[-1]:
            lines.append("")
        lines.extend(block)
    return "\n".join(lines).rstrip("\n") + "\n"


class Store:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.errors: list[tuple[str, str]] = []  # (rel, message) of the files the last `entries()` could not use

    def _path(self, rel: str) -> Path:
        """The file of an entry path; raises EntryError for anything that is not one."""
        scope, _ = split_rel(rel)
        slug = self._facts_slug(scope)
        if slug is not None and not (self.root / "projects" / slug / "overview.md").is_file():
            raise EntryError(f"{rel}: project {slug!r} has no overview.md")
        return self.root / rel

    @staticmethod
    def _facts_slug(scope: str) -> str | None:
        """`projects/<slug>/facts` is only valid if `projects/<slug>/overview.md` exists."""
        parts = scope.split("/")
        return parts[1] if len(parts) == 3 and parts[0] == "projects" else None

    # reading

    def _read_dir(self, directory: Path, found: list[Entry]) -> None:
        """Add the entries of a scope directory to `found`; the files that are not valid go to `self.errors`."""
        if not directory.is_dir():
            return
        for file in sorted(directory.glob("*.md")):
            if not file.is_file():
                continue
            rel = file.relative_to(self.root).as_posix()
            try:
                found.append(self.read(rel))
            except (EntryError, OSError) as e:
                self.errors.append((rel, str(e)))

    def entries(self) -> list[Entry]:
        """Every entry, sorted by path. Files that are not valid entries are listed in `self.errors`, not raised."""
        self.errors = []
        found: list[Entry] = []
        for pattern in _SCOPE_GLOBS:
            for directory in sorted(self.root.glob(pattern)):
                self._read_dir(directory, found)
        return sorted(found, key=_entry_rel)

    def entries_in(self, scopes: Iterable[str]) -> list[Entry]:
        """The entries of these scopes only (the other files are not opened), sorted by path; errors as `entries`."""
        self.errors = []
        found: list[Entry] = []
        for scope in sorted(set(scopes)):
            if _SCOPE.fullmatch(scope) is not None:
                self._read_dir(self.root / scope, found)
        return sorted(found, key=_entry_rel)

    def read(self, rel: str) -> Entry:
        """The entry at `rel`; EntryError if it is not valid, OSError if it cannot be read."""
        path = self._path(rel)
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError as e:
            raise EntryError(f"{rel}: not UTF-8 text") from e
        return parse_entry(rel, text)

    def bytes(self, rel: str) -> int:
        """Size of the entry file."""
        return self._path(rel).stat().st_size

    def project_slugs(self) -> list[str]:
        """Projects of the architect that may have facts: the directories with an `overview.md`."""
        projects = self.root / "projects"
        if not projects.is_dir():
            return []
        return sorted(
            d.name for d in projects.iterdir() if _NAME.fullmatch(d.name) and (d / "overview.md").is_file()
        )

    def projects_index(self) -> list[ProjectRow]:
        """Rows of the `INDEX.md` table (slug, status, repo path); none if the file is missing."""
        try:
            text = (self.root / "INDEX.md").read_text(encoding="utf-8")
        except (FileNotFoundError, UnicodeDecodeError):
            return []
        rows: list[ProjectRow] = []
        for line in text.splitlines():
            line = line.strip()
            if not line.startswith("|"):
                continue
            cells = [c.strip() for c in line.strip("|").split("|")]
            if len(cells) < 3 or cells[0].lower() == "slug":
                continue
            if all(_SEPARATOR_CELL.fullmatch(c) for c in cells):
                continue
            slug, status, repo = cells[0], cells[1], cells[2].strip("`").strip()
            if slug and repo:
                rows.append(ProjectRow(slug, status, repo))
        return rows

    # writing

    def write(self, entry: Entry) -> None:
        """Create or replace the entry file (tmp file + rename). Invalid entries raise EntryError and write nothing."""
        text = render_entry(entry)
        path = self._path(entry.rel)
        path.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(path, text, ENTRY_MODE)

    def delete(self, rel: str) -> None:
        """Remove the entry and the directories it leaves empty, up to but not including `projects/<slug>`."""
        path = self._path(rel)
        path.unlink()
        scope, _ = split_rel(rel)
        slug = self._facts_slug(scope)
        stop = self.root / "projects" / slug if slug is not None else self.root
        directory = path.parent
        while directory != stop and directory != self.root:
            try:
                directory.rmdir()
            except OSError:  # not empty
                break
            directory = directory.parent

    def private_text(self, org: str) -> str | None:
        """The content of `private/<org>.md`, or None if there is no such file."""
        if _NAME.fullmatch(org) is None:
            raise ValueError(f"invalid org name {org!r}")
        path = self.root / PRIVATE_DIR / f"{org}.md"
        try:
            return path.read_text(encoding="utf-8")
        except FileNotFoundError:
            return None
        except UnicodeDecodeError as e:
            raise ParseError(f"{path}: not UTF-8 text") from e

    def private_section(self, org: str, section: str) -> str | None:
        """The text under `## <section>` of `private/<org>.md`, stripped; None if the file or the section is missing."""
        text = self.private_text(org)
        if text is None:
            return None
        lines = text.splitlines()
        found = _section_range(lines, f"## {section.strip()}")
        if found is None:
            return None
        return "\n".join(lines[found[0] + 1 : found[1]]).strip()

    def private_lines(self) -> set[str]:
        """Every line of `private/*.md` that is worth guarding: stripped, at least MIN_PRIVATE_LINE chars."""
        found: set[str] = set()
        for path in sorted((self.root / PRIVATE_DIR).glob("*.md")):
            try:
                text = path.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            found.update(s for line in text.splitlines() if len(s := line.strip()) >= MIN_PRIVATE_LINE)
        return found

    def private_write(self, org: str, section: str, body: str) -> Path:
        """Put `body` under `## <section>` in `private/<org>.md` (never committed); the file path."""
        if _NAME.fullmatch(org) is None:
            raise ValueError(f"invalid org name {org!r}")
        if not section.strip() or "\n" in section or "\r" in section:
            raise ValueError("a private section needs a one-line heading")
        directory = self.root / PRIVATE_DIR
        directory.mkdir(parents=True, exist_ok=True, mode=PRIVATE_DIR_MODE)
        directory.chmod(PRIVATE_DIR_MODE)
        path = directory / f"{org}.md"
        text = self.private_text(org)
        if text is None:
            text = f"# {org} private notes\n"
        atomic_write(path, _replace_section(text, section.strip(), body), PRIVATE_FILE_MODE)
        path.chmod(PRIVATE_FILE_MODE)
        return path


def _entry_rel(e: Entry) -> str:
    return e.rel
