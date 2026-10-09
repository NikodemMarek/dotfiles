"""Retention: what an entry is worth, when it is stale, and what to drop to keep the store in budget (S11).

Age only flags an entry as stale: an entry nobody re-verified stays, flagged, until the weekly run re-checks it.
Knowledge is dropped only when a scope is over its budget, which loses its lowest-scoring entries; the entries of
the user are never dropped automatically, the user is told about them instead.
Nothing is archived; a drop is a `git rm`. Staleness is computed, never stored.
The usage term of the score is a fixed `USAGE_STUB`: v1 has no read log.
"""

import datetime
import math
from collections.abc import Collection, Iterable, Mapping, Sequence
from dataclasses import dataclass

from .entry import Entry, Source
from .index import entry_size, scope_order, total_usage, usage
from .scopes import ScopesConfig
from .store import ProjectRow

HALF_LIFE = {"fact": 60, "gotcha": 120, "howto": 120, "reference": 180, "convention": 365, "preference": 365}  # days
USER_HALF_LIFE_FACTOR = 2.0
DONE_HALF_LIFE_FACTOR = 0.5  # the facts of a project that is done or abandoned
DONE_STATUSES = ("done", "abandoned")  # the status column of the architect's INDEX.md
GRACE = 14  # days an entry is safe from eviction
STALE_F = 0.25  # stale: F < STALE_F, i.e. age > 2 half-lives
USAGE_STUB = 0.5
EVICT_TO = 0.9  # an eviction goes down to this share of the count and of the bytes
FULL_AT = 0.8  # a scope this full is worth a weekly run
STALE_FLAG = "stale"
TOTAL = "total"  # the key of the whole store in `RetentionPlan.user_overflow`

CONFIDENCE_WEIGHT = {"high": 1.0, "medium": 0.6, "low": 0.2}
TRUST_WEIGHT = {"user": 1.0, "agent": 0.5, "untrusted": 0.1}
SOURCES_FOR_FULL_SUPPORT = 3


@dataclass(frozen=True)
class Drop:
    entry: Entry
    score: float

    @property
    def rel(self) -> str:
        return self.entry.rel


@dataclass(frozen=True)
class RetentionPlan:
    evict: tuple[Drop, ...]
    user_overflow: dict[str, tuple[str, ...]]  # scope (or `total`) -> entries of the user, lowest score first


def done_slugs(rows: Iterable[ProjectRow]) -> frozenset[str]:
    """The projects whose INDEX status says they are over."""
    return frozenset(r.slug for r in rows if r.status.strip("*_` ").lower() in DONE_STATUSES)


def _facts_slug(scope: str) -> str | None:
    parts = scope.split("/")
    return parts[1] if len(parts) == 3 and parts[0] == "projects" else None


def _days_since(date: str, today: datetime.date) -> int:
    return (today - datetime.date.fromisoformat(date)).days


# half-life, freshness, score


def hl(e: Entry, done: Collection[str] = ()) -> float:
    """The half-life of an entry in days: its kind's, doubled for the user, halved for a project that is over."""
    days = float(HALF_LIFE[e.kind])
    if e.trust == "user":
        days *= USER_HALF_LIFE_FACTOR
    slug = _facts_slug(e.scope)
    if slug is not None and slug in done:
        days *= DONE_HALF_LIFE_FACTOR
    return days


def age(e: Entry, today: datetime.date) -> int:
    """Days since the entry was last verified."""
    return max(0, _days_since(e.last_verified, today))


def freshness(e: Entry, today: datetime.date, done: Collection[str] = ()) -> float:
    """F: 1 when verified today, 0.5 after one half-life."""
    return math.pow(0.5, age(e, today) / hl(e, done))  # `0.5 ** x` is typed Any


def _identity(s: Source) -> str:
    return s.submission or f"{s.by}@{s.date}"


def support(e: Entry) -> float:
    """S: the share of three distinct sources the entry has."""
    return min(1.0, len({_identity(s) for s in e.sources}) / SOURCES_FOR_FULL_SUPPORT)


def score(e: Entry, today: datetime.date, done: Collection[str] = ()) -> float:
    return (
        0.30 * freshness(e, today, done)
        + 0.25 * USAGE_STUB
        + 0.15 * CONFIDENCE_WEIGHT[e.confidence]
        + 0.15 * TRUST_WEIGHT[e.trust]
        + 0.15 * support(e)
    )


# stale, evictable


def is_stale(e: Entry, today: datetime.date, done: Collection[str] = ()) -> bool:
    """F < STALE_F, which is age > 2 half-lives (compared in days, so a boundary is not a rounding question)."""
    return age(e, today) > 2 * hl(e, done)


def _protected(e: Entry, today: datetime.date) -> bool:
    return _days_since(e.created, today) < GRACE


def is_evictable(e: Entry, today: datetime.date) -> bool:
    return not _protected(e, today) and e.trust != "user"


def _staleness(e: Entry) -> tuple[str, str]:
    return e.last_verified, e.rel


def stale_entries(entries: Iterable[Entry], today: datetime.date, done: Collection[str] = ()) -> list[Entry]:
    """The stale entries, the longest unverified first."""
    return sorted((e for e in entries if is_stale(e, today, done)), key=_staleness)


def stale_flags(entries: Iterable[Entry], today: datetime.date, done: Collection[str] = ()) -> dict[str, list[str]]:
    """The markers the index shows, by entry path."""
    return {e.rel: [STALE_FLAG] for e in stale_entries(entries, today, done)}


def crowded(entries: Sequence[Entry], cfg: ScopesConfig, sizes: Mapping[str, int] | None = None) -> list[str]:
    """The scopes (and `total`) that are at FULL_AT of their count or bytes budget, or over it."""
    rows = [*usage(entries, cfg, sizes), total_usage(entries, cfg, sizes)]
    return [u.scope for u in rows if u.count >= FULL_AT * u.max_count or u.size >= FULL_AT * u.max_size]


# the plan


def _within(count: int, size: int, limit: tuple[int, int], factor: float) -> bool:
    return count <= limit[0] * factor and size <= limit[1] * factor


def _shrink(
    members: Sequence[Entry],
    limit: tuple[int, int],
    sizes: Mapping[str, int] | None,
    scores: Mapping[str, float],
    today: datetime.date,
) -> tuple[list[Drop], list[Entry], bool]:
    """Evict the lowest-scoring evictable members of a group that is over its budget, down to EVICT_TO of it.

    Returns the drops, the members left, and whether the group is still over its budget (only entries that are
    protected or the user's are left to drop).
    """
    count = len(members)
    size = sum(entry_size(e, sizes) for e in members)
    if _within(count, size, limit, 1.0):
        return [], list(members), False

    def by_score(e: Entry) -> tuple[float, str]:
        return scores[e.rel], e.rel

    drops: list[Drop] = []
    gone: set[str] = set()
    for e in sorted((m for m in members if is_evictable(m, today)), key=by_score):
        if _within(count, size, limit, EVICT_TO):
            break
        drops.append(Drop(e, scores[e.rel]))
        gone.add(e.rel)
        count -= 1
        size -= entry_size(e, sizes)
    left = [m for m in members if m.rel not in gone]
    return drops, left, not _within(count, size, limit, 1.0)


def _users(members: Iterable[Entry], scores: Mapping[str, float]) -> tuple[str, ...]:
    def by_score(e: Entry) -> tuple[float, str]:
        return scores[e.rel], e.rel

    return tuple(e.rel for e in sorted((m for m in members if m.trust == "user"), key=by_score))


def plan(
    entries: Sequence[Entry],
    cfg: ScopesConfig,
    today: datetime.date,
    done: Collection[str] = (),
    sizes: Mapping[str, int] | None = None,
) -> RetentionPlan:
    """What to drop: the lowest scores of each scope over its budget, then of the whole store.

    `done`: the slugs of the finished projects. `sizes`: the file sizes by path (default: as rendered). Entries of
    the user are never evicted: when a budget cannot be met without them they are listed in `user_overflow`.
    """
    scores = {e.rel: score(e, today, done) for e in entries}

    evict: list[Drop] = []
    overflow: dict[str, tuple[str, ...]] = {}
    by_scope: dict[str, list[Entry]] = {}
    for e in entries:
        by_scope.setdefault(e.scope, []).append(e)
    left: list[Entry] = []
    for scope in sorted(by_scope, key=scope_order):
        drops, rest, over = _shrink(by_scope[scope], cfg.budget_for(scope), sizes, scores, today)
        evict.extend(drops)
        left.extend(rest)
        if over:
            overflow[scope] = _users(rest, scores)

    drops, rest, over = _shrink(left, cfg.total_budget, sizes, scores, today)
    evict.extend(drops)
    if over:
        overflow[TOTAL] = _users(rest, scores)

    return RetentionPlan(tuple(evict), {k: v for k, v in overflow.items() if v})


# the effects of a plan


def drop_line(d: Drop) -> str:
    """A line of the commit body."""
    return f"{d.rel} {d.score:.2f}"
