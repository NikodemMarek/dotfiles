"""What the user does by hand to the store: undo a submission, restore or drop an entry (S6).

Every command takes the curator lock, so it does not race a run.
"""

import datetime
import logging
from dataclasses import replace
from pathlib import Path

from . import data, ideas, locks, rejected
from .config import UsageError
from .data import Obj
from .entry import EntryError, parse_entry, split_rel
from .gitops import Git
from .locks import FileLock
from .records import ID_RE
from .store import Store

log = logging.getLogger("knowledge")

LOCK_WAIT = 600.0  # seconds to wait for a curator run to finish


class Manual:
    def __init__(self, git: Git, now: datetime.datetime | None = None) -> None:
        self.git = git
        self._at = now

    def _now(self) -> datetime.datetime:
        return self._at or datetime.datetime.now(datetime.UTC)

    @staticmethod
    def _exclusive() -> FileLock:
        return FileLock(locks.curator_lock(), LOCK_WAIT)

    def undo(self, sid: str) -> Obj:
        """One commit that reverts every commit of the submission; GitError (with git's message) on a conflict."""
        if ID_RE.fullmatch(sid) is None:
            raise UsageError(f"{sid!r} is not a submission id")
        with self._exclusive():
            shas = self.git.commits_with_trailer("Submission", sid)
            if not shas:
                raise UsageError(f"no commit of submission {sid}")
            commit = self.git.revert(shas, f"knowledge: undo {sid}", trailers={"Undo": sid})
        return {"id": sid, "commit": commit, "reverted": data.strs(shas)}

    def restore(self, rel: str) -> Obj:
        """Bring back an entry from the commit that deleted it, with `updated` and `last_verified` set to today.

        The user has just looked at it: left as it was, a stale entry would score low and be evicted again by the next run.
        """
        split_rel(rel)
        store = Store(self.git.repo)
        with self._exclusive():
            if (self.git.repo / rel).exists(follow_symlinks=False):
                raise UsageError(f"{rel} exists")
            deleted = self.git.last_deleting_commit(rel)
            if deleted is None:
                raise UsageError(f"{rel}: no commit deleted it")
            entry = parse_entry(rel, self.git.show(f"{deleted}^", rel))
            today = self._now().date().isoformat()
            store.write(replace(entry, updated=today, last_verified=today))
            try:
                commit = self.git.commit([rel], f"knowledge: restore {rel}")
            except BaseException:
                self.git.restore([rel], created=[rel])
                raise
        return {"path": rel, "commit": commit, "from": deleted}

    def drop(self, rel: str, reason: str | None = None, taken: bool = False) -> Obj:
        """Delete an entry of any trust, or a skill idea (`skill-ideas/<name>.md`); a note in rejected.md tells the
        curator not to take it back.

        `taken` (a skill idea only): the user adopted the idea as a skill, so it is deleted without that note: the curator
        may go on improving the skill.
        """
        idea = rel.startswith(f"{ideas.DIR}/")
        name = Path(rel).stem
        if taken and not idea:
            raise UsageError(f"{rel}: --taken is for a skill idea ({ideas.DIR}/<name>.md), not an entry")
        if idea:
            try:
                valid = ideas.rel(name) == rel
            except EntryError:
                valid = False
            if not valid:
                raise UsageError(f"{rel}: not a skill idea path ({ideas.DIR}/<name>.md)")
        else:
            split_rel(rel)
        store = Store(self.git.repo)
        with self._exclusive():
            if not (self.git.repo / rel).is_file():
                raise UsageError(f"{rel}: no such {'skill idea' if idea else 'entry'}")
            label = f"skill idea {name}" if idea else rel
            description = label  # what the note says; an entry has its own description
            if idea:
                (self.git.repo / rel).unlink()
            else:
                try:
                    description = store.read(rel).description
                except (EntryError, OSError) as e:  # a damaged entry can be dropped too
                    log.warning("%s", e)
                    description = ""
                store.delete(rel)
            subject = f"knowledge: {label} taken (by user)" if taken else f"knowledge: drop {label} (by user)"
            try:
                commit = self.git.commit([rel], subject, body=reason or "")
            except BaseException:
                self.git.restore([rel])
                raise
            if not taken:
                why = f": {reason}" if reason else ""
                rejected.note(f"{rel} (dropped by the user{why}): {description}", self._now().date())
        return {"path": rel, "commit": commit}
