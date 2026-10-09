"""Git operations on the memory repo: no hooks, and a commit takes only the paths it is given."""

import os
import re
import subprocess
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import NamedTuple

from .locks import FileLock

TIMEOUT = 120
LOCK_WAIT = 30.0  # seconds to wait for memory.lock

_TRAILER_KEY = re.compile(r"[A-Za-z][A-Za-z0-9-]*\Z")
_REV = re.compile(r"[0-9a-fA-F]{4,64}\Z")
# variables that point git at another repo, index or object store than the one `-C` names
_FOREIGN_ENV = (
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY",
    "GIT_COMMON_DIR",
    "GIT_NAMESPACE",
    "GIT_PREFIX",
)


class GitError(Exception):
    def __init__(self, cmd: str, detail: str) -> None:
        super().__init__(f"git {cmd}: {detail}")
        self.detail = detail


class _Result(NamedTuple):
    code: int
    out: str
    err: str


def _check_key(key: str) -> str:
    if not _TRAILER_KEY.match(key):
        raise ValueError(f"not a trailer key: {key!r}")
    return key


def _check_rev(rev: str) -> str:
    if not rev or rev.startswith("-"):
        raise ValueError(f"not a revision: {rev!r}")
    return rev


def _message(subject: str, body: str, trailers: Mapping[str, str]) -> str:
    subject = " ".join(subject.split())
    if not subject:
        raise ValueError("empty commit subject")
    parts = [subject]
    if body.strip():
        parts.append(body.strip())
    if trailers:
        parts.append("\n".join(f"{_check_key(k)}: {' '.join(v.split())}" for k, v in trailers.items()))
    return "\n\n".join(parts) + "\n"


class Git:
    def __init__(self, repo: Path, lock_path: Path, lock_timeout: float = LOCK_WAIT) -> None:
        self.repo = repo
        self.lock_path = lock_path
        self.lock_timeout = lock_timeout

    # plumbing

    def _proc(self, *args: str, timeout: float = TIMEOUT) -> _Result:
        """Run git; a non-zero exit is returned, not raised."""
        cmd = ["git", "-c", "core.hooksPath=/dev/null", "-C", str(self.repo), *args]
        shown = args[0] if args else ""
        inherited = {k: v for k, v in os.environ.items() if k not in _FOREIGN_ENV}
        env = {**inherited, "GIT_TERMINAL_PROMPT": "0", "GIT_LITERAL_PATHSPECS": "1"}
        try:
            proc = subprocess.run(
                cmd, capture_output=True, timeout=timeout, check=False, stdin=subprocess.DEVNULL, env=env
            )
        except subprocess.TimeoutExpired as e:
            raise GitError(shown, f"timed out after {timeout:g}s") from e
        except OSError as e:
            raise GitError(shown, f"cannot run git: {e}") from e
        except ValueError as e:  # an argument subprocess refuses, e.g. "embedded null byte"
            raise GitError(shown, f"invalid argument: {e}") from e
        return _Result(
            proc.returncode,
            proc.stdout.decode(errors="replace"),
            proc.stderr.decode(errors="replace"),
        )

    def run(self, *args: str) -> str:
        """stdout of `git -C repo args`; raises GitError on a non-zero exit."""
        res = self._proc(*args)
        if res.code != 0:
            msg = " ".join((res.err or res.out).split())
            raise GitError(args[0] if args else "", msg or f"exit status {res.code}")
        return res.out

    def _paths(self, paths: Sequence[str]) -> list[str]:
        """The repo-relative paths, deduplicated and checked: nothing outside the repo, nothing in `.git`."""
        for p in paths:
            parts = Path(p).parts
            if not p or Path(p).is_absolute() or ".." in parts or any(part.lower() == ".git" for part in parts):
                raise ValueError(f"not a path inside the repo: {p!r}")
        seen: dict[str, None] = {p: None for p in paths}
        return list(seen)

    def _listed(self, *args: str) -> set[str]:
        """The names a `-z` listing command prints; empty if it fails (e.g. no HEAD yet)."""
        res = self._proc(*args)
        return {n for n in res.out.split("\0") if n} if res.code == 0 else set()

    # queries

    def ensure_repo(self) -> None:
        """The repo must be a git repository of its own, not a directory inside another one."""
        top = self.run("rev-parse", "--show-toplevel").strip()
        if Path(top).resolve() != self.repo.resolve():
            raise GitError("rev-parse", f"{self.repo} is not the top of a git repository (found {top})")

    def head(self) -> str:
        return self.run("rev-parse", "HEAD").strip()

    def _has_head(self) -> bool:
        return self._proc("rev-parse", "--verify", "-q", "HEAD").code == 0

    def trailer_values(self, key: str, since_days: int = 30) -> set[str]:
        """The values of the trailer in the commits of the last `since_days` days; empty if there is no HEAD yet."""
        if not self._has_head():
            return set()
        out = self.run(
            "log", f"--since={since_days}.days.ago", f"--format=%(trailers:key={_check_key(key)},valueonly,unfold)"
        )
        return {line.strip() for line in out.splitlines() if line.strip()}

    def commits_with_trailer(self, key: str, value: str) -> list[str]:
        """Commits that carry the trailer `key: value`, newest first; none if there is no HEAD yet."""
        if not self._has_head():
            return []
        out = self.run(
            "log",
            f"--format=%H%x1f%(trailers:key={_check_key(key)},valueonly,unfold,separator=%x1f)%x1e",
        )
        found: list[str] = []
        for record in out.split("\x1e"):
            sha, _, values = record.strip("\n").partition("\x1f")
            if sha and value in (v.strip() for v in values.split("\x1f")):
                found.append(sha)
        return found

    def last_deleting_commit(self, path: str) -> str | None:
        [path] = self._paths([path])
        out = self.run("log", "--diff-filter=D", "-n1", "--format=%H", "--", path).strip()
        return out or None

    def show(self, rev: str, path: str) -> str:
        """The content of `path` at `rev`."""
        [path] = self._paths([path])
        return self.run("show", f"{_check_rev(rev)}:{path}")

    # changes

    def _commit(self, paths: list[str], subject: str, body: str, trailers: Mapping[str, str]) -> str | None:
        """Commit `paths` (the caller holds the lock). Paths that are neither on disk nor known to git are dropped."""
        message = _message(subject, body, trailers)
        if not paths:
            return None
        in_index = self._listed("ls-files", "-z", "--", *paths)
        in_head = self._listed("ls-tree", "-r", "--name-only", "-z", "HEAD", "--", *paths)
        known = [p for p in paths if (self.repo / p).exists(follow_symlinks=False) or p in in_index or p in in_head]
        if not known:
            return None
        # `add` refuses a path that is gone from the index and the disk; that deletion is staged already
        addable = [p for p in known if (self.repo / p).exists(follow_symlinks=False) or p in in_index]
        if addable:
            self.run("add", "-A", "--", *addable)
        diff = self._proc("diff", "--cached", "--quiet", "--", *known)
        if diff.code == 0:
            return None
        if diff.code != 1:
            raise GitError("diff", " ".join(diff.err.split()) or f"exit status {diff.code}")
        self.run("commit", "-q", "--no-verify", "-m", message, "--", *known)
        return self.head()

    def commit(
        self, paths: Sequence[str], subject: str, body: str = "", trailers: Mapping[str, str] | None = None
    ) -> str | None:
        """Commit only `paths`; the sha, or None if they have no changes. Waits for memory.lock."""
        checked = self._paths(paths)
        with FileLock(self.lock_path, self.lock_timeout):
            return self._commit(checked, subject, body, trailers or {})

    def _restore(self, paths: list[str], created: set[str]) -> None:
        """Back to HEAD (the caller holds the lock); only a path of `created` is ever deleted from the disk."""
        if not paths:
            return
        in_head = self._listed("ls-tree", "-r", "--name-only", "-z", "HEAD", "--", *paths)
        tracked = [p for p in paths if p in in_head]
        others = [p for p in paths if p not in in_head]
        if tracked:
            self.run("checkout", "HEAD", "--", *tracked)
        if others:
            self.run("rm", "--cached", "-q", "--ignore-unmatch", "--", *others)
            for p in others:
                f = self.repo / p
                if p in created and (f.is_symlink() or f.is_file()):
                    f.unlink()

    def restore(self, paths: Sequence[str], created: Sequence[str] = ()) -> None:
        """Back to HEAD: tracked paths are checked out again, the others are dropped from the index.

        A path that is not in HEAD is deleted from the disk only if it is also in `created` (the caller made it);
        any other such path stays where it is, unstaged. Waits for memory.lock.
        """
        checked = self._paths(paths)
        made = set(self._paths(created))
        with FileLock(self.lock_path, self.lock_timeout):
            self._restore(checked, made)

    def revert(self, shas: Sequence[str], subject: str, trailers: Mapping[str, str] | None = None) -> str:
        """One commit that undoes `shas` (newest first).

        The paths the commits touched must be clean. On any failure nothing is left behind (those paths are put back
        to HEAD, which is safe because they were clean) and the error is raised.
        """
        if not shas:
            raise ValueError("nothing to revert")
        revs = [_check_rev(s) for s in shas]
        for rev in revs:
            if not _REV.match(rev):
                raise ValueError(f"not a commit id: {rev!r}")
        with FileLock(self.lock_path, self.lock_timeout):
            touched: dict[str, None] = {}
            for rev in revs:
                names = self.run("diff-tree", "--no-commit-id", "--name-only", "-r", "-z", "--root", rev)
                touched.update((n, None) for n in names.split("\0") if n)
            paths = list(touched)
            if paths and self.run("status", "--porcelain", "--", *paths).strip():
                raise GitError("revert", "the paths to revert have uncommitted changes")
            try:
                res = self._proc("revert", "--no-commit", *revs)
                if res.code != 0:
                    raise GitError("revert", " ".join((res.err or res.out).split()) or f"exit status {res.code}")
                sha = self._commit(paths, subject, "", trailers or {})
                if sha is None:
                    raise GitError("revert", "the revert changed nothing (already undone?)")
                return sha
            except BaseException:
                try:
                    self._proc("revert", "--abort")  # fails if there is no sequencer state; the restore cleans up
                except GitError:
                    pass
                self._restore(paths, set(paths))  # whatever is not in HEAD was made by the revert: the paths were clean
                raise
