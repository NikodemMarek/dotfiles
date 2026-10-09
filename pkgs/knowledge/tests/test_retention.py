import datetime
from dataclasses import replace

import pytest

from knowledge import retention
from knowledge.entry import Entry, Source
from knowledge.retention import Drop, plan
from knowledge.scopes import ScopesConfig, parse_scopes
from knowledge.store import ProjectRow

TODAY = datetime.date(2026, 10, 6)
OLD = "2026-01-01"  # created long before any grace


def ago(days: int) -> str:
    return (TODAY - datetime.timedelta(days=days)).isoformat()


def src(n: int, trust: str = "agent") -> Source:
    return Source(ago(5), "coder", None, trust, f"s-20261001T00000{n}Z-a1b2c3", "saw it")


def mk(name: str = "x", scope: str = "topic/jj", **changes: object) -> Entry:
    base = Entry(
        name=name, description=f"About {name}", kind="convention", scope=scope, tags=(), confidence="medium",
        trust="agent", status="active", created=OLD, updated=OLD, last_verified=ago(0), verify=None, related=(),
        sources=(src(1), src(2), src(3)), body="Body.",
    )  # fmt: skip
    return replace(base, **changes)


def cfg_with(**budget: str) -> ScopesConfig:
    """`budget`: TOML pairs, e.g. topic="[10, 1000000]"."""
    return parse_scopes("[budget]\n" + "".join(f"{k} = {v}\n" for k, v in budget.items()))


def sized(entries: list[Entry], size: int = 100) -> dict[str, int]:
    return {e.rel: size for e in entries}


def names(drops: tuple[Drop, ...]) -> list[str]:
    return [d.entry.name for d in drops]


# half-life, freshness, staleness


@pytest.mark.parametrize(
    ("kind", "hl"),
    [("fact", 60), ("gotcha", 120), ("howto", 120), ("reference", 180), ("convention", 365), ("preference", 365)],
)
def test_the_half_life_depends_on_the_kind(kind: str, hl: int):
    assert retention.hl(mk(kind=kind)) == hl


@pytest.mark.parametrize(
    ("kind", "age", "fresh", "stale"),
    [
        ("fact", 0, 1.0, False),
        ("fact", 60, 0.5, False),
        ("fact", 120, 0.25, False),  # F = STALE_F exactly is not yet stale
        ("fact", 121, 0.2471, True),
        ("gotcha", 120, 0.5, False),
        ("gotcha", 240, 0.25, False),
        ("gotcha", 241, 0.2486, True),
        ("reference", 180, 0.5, False),
        ("reference", 361, 0.2490, True),
        ("convention", 365, 0.5, False),
        ("convention", 731, 0.2495, True),
        ("preference", 730, 0.25, False),
    ],
)
def test_freshness_and_staleness_per_kind(kind: str, age: int, fresh: float, stale: bool):
    e = mk(kind=kind, last_verified=ago(age))
    assert retention.freshness(e, TODAY) == pytest.approx(fresh, abs=1e-3)
    assert retention.is_stale(e, TODAY) is stale


def test_an_entry_verified_in_the_future_is_fresh():
    assert retention.freshness(mk(last_verified="2026-10-20"), TODAY) == 1.0


def test_the_half_life_of_the_user_doubles():
    assert retention.hl(mk(kind="fact", trust="user")) == 120
    assert retention.is_stale(mk(kind="fact", last_verified=ago(130)), TODAY)
    assert not retention.is_stale(mk(kind="fact", trust="user", last_verified=ago(130)), TODAY)


def test_the_facts_of_a_project_that_is_done_halve():
    e = mk(kind="fact", scope="projects/old/facts")
    assert retention.hl(e) == 60
    assert retention.hl(e, {"old"}) == 30
    assert retention.hl(e, {"other"}) == 60
    assert retention.hl(replace(e, trust="user"), {"old"}) == 60  # both factors
    assert retention.hl(mk(kind="fact", scope="topic/jj"), {"old"}) == 60  # only project facts


def test_done_slugs_come_from_the_index_status():
    rows = [
        ProjectRow("a", "done", "/r/a"),
        ProjectRow("b", "active", "/r/b"),
        ProjectRow("c", "Abandoned", "/r/c"),
        ProjectRow("d", "**done**", "/r/d"),
    ]
    assert retention.done_slugs(rows) == {"a", "c", "d"}


def test_a_done_project_goes_stale_sooner():
    e = mk(kind="fact", scope="projects/old/facts", last_verified=ago(70))
    assert not retention.is_stale(e, TODAY)
    assert retention.is_stale(e, TODAY, {"old"})  # hl 30: stale after 60 days


# the score


def test_the_score_adds_up_its_terms():
    # F 1, usage 0.5 (stub), C medium 0.6, T agent 0.5, S 3 sources
    assert retention.score(mk(), TODAY) == pytest.approx(0.30 + 0.125 + 0.09 + 0.075 + 0.15)


@pytest.mark.parametrize(
    ("changes", "expected"),
    [
        ({"confidence": "high"}, 0.30 + 0.125 + 0.15 + 0.075 + 0.15),
        ({"confidence": "low"}, 0.30 + 0.125 + 0.03 + 0.075 + 0.15),
        ({"trust": "user"}, 0.30 + 0.125 + 0.09 + 0.15 + 0.15),
        ({"trust": "untrusted"}, 0.30 + 0.125 + 0.09 + 0.015 + 0.15),
        ({"sources": ()}, 0.30 + 0.125 + 0.09 + 0.075),
        ({"sources": (src(1),)}, 0.30 + 0.125 + 0.09 + 0.075 + 0.05),
        ({"last_verified": ago(365)}, 0.15 + 0.125 + 0.09 + 0.075 + 0.15),
    ],
)
def test_the_score_per_term(changes: dict[str, object], expected: float):
    assert retention.score(mk(**changes), TODAY) == pytest.approx(expected)


def test_sources_are_counted_by_submission_or_by_and_date():
    twice = Source(ago(1), "coder", None, "agent", "", "a")
    same_day = Source(ago(1), "coder", None, "agent", "", "b")
    other_day = Source(ago(2), "coder", None, "agent", "", "c")
    assert retention.support(mk(sources=(twice, same_day))) == pytest.approx(1 / 3)
    assert retention.support(mk(sources=(twice, same_day, other_day))) == pytest.approx(2 / 3)
    assert retention.support(mk(sources=(src(1), src(1)))) == pytest.approx(1 / 3)


# grace, the plan


def test_the_grace_period_protects_new_entries():
    assert not retention.is_evictable(mk(created=ago(13), kind="fact", last_verified=ago(400)), TODAY)
    assert retention.is_evictable(mk(created=ago(14), kind="fact", last_verified=ago(400)), TODAY)


def test_the_entries_of_the_user_are_never_evictable():
    assert not retention.is_evictable(mk(trust="user"), TODAY)
    assert retention.is_evictable(mk(trust="untrusted"), TODAY)


def test_the_plan_keeps_a_long_stale_entry():
    dead = mk("dead", kind="fact", last_verified=ago(400))
    p = plan([dead, mk("live")], cfg_with(), TODAY)
    assert p.evict == ()
    assert p.user_overflow == {}


def test_a_stale_entry_of_the_user_is_not_evicted():
    old = mk("old", kind="fact", last_verified=ago(200))
    mine = mk("mine", kind="fact", trust="user", last_verified=ago(400))
    entries = [old, mine, mk("live")]
    p = plan(entries, cfg_with(topic="[2, 1000000]"), TODAY, sizes=sized(entries))
    assert names(p.evict) == ["old", "live"]  # 3 of 2, and 90% of 2 is 1.8: both agent entries go


# eviction


def spread(n: int, scope: str = "topic/jj") -> list[Entry]:
    """`n` fresh entries whose scores fall with their number: e00 is the best, the last the worst."""
    return [mk(f"e{i:02d}", scope, last_verified=ago(i)) for i in range(n)]


def test_a_scope_over_its_count_is_evicted_down_to_90_percent():
    entries = spread(12)
    p = plan(entries, cfg_with(topic="[10, 1000000]"), TODAY, sizes=sized(entries))
    assert names(p.evict) == ["e11", "e10", "e09"]  # lowest score first; 9 of 10 are left
    assert p.user_overflow == {}


def test_a_scope_within_its_budget_is_left_alone():
    entries = spread(10)
    assert plan(entries, cfg_with(topic="[10, 1000]"), TODAY, sizes=sized(entries, 100)).evict == ()


def test_a_scope_over_its_bytes_is_evicted_down_to_90_percent():
    entries = spread(11)
    p = plan(entries, cfg_with(topic="[50, 1000]"), TODAY, sizes=sized(entries))  # 1100 bytes
    assert names(p.evict) == ["e10", "e09"]  # 900 of 1000 bytes are left


def test_eviction_meets_both_limits():
    entries = spread(12)
    # 12 entries of 90 bytes (1080) against [10, 1000]: the count needs 3 out (9 left), the bytes 2 (900 left)
    p = plan(entries, cfg_with(topic="[10, 1000]"), TODAY, sizes=sized(entries, 90))
    assert len(p.evict) == 3  # the stricter of the two decides
    # against [20, 1000] only the bytes are over
    p = plan(entries, cfg_with(topic="[20, 1000]"), TODAY, sizes=sized(entries, 90))
    assert len(p.evict) == 2


def test_only_the_scope_over_its_budget_loses_entries():
    jj = spread(4)
    docker = spread(2, "topic/docker")
    p = plan([*jj, *docker], cfg_with(topic="[3, 1000000]"), TODAY, sizes=sized(jj + docker))
    assert {d.entry.scope for d in p.evict} == {"topic/jj"}
    assert names(p.evict) == ["e03", "e02"]  # 4 -> 2 (target 2.7)


def test_eviction_spares_the_new_and_the_users():
    entries = [
        mk("new", created=ago(3), last_verified=ago(300)),
        mk("user", trust="user", last_verified=ago(300)),
        mk("a", last_verified=ago(1)),
        mk("b", last_verified=ago(2)),
    ]
    p = plan(entries, cfg_with(topic="[3, 1000000]"), TODAY, sizes=sized(entries))
    assert names(p.evict) == ["b", "a"]  # the others are protected; two evictions are all there are


def test_evicted_entries_are_chosen_by_score_not_age_alone():
    sure = mk("sure", confidence="high", last_verified=ago(100))
    unsure = mk("unsure", confidence="low", trust="untrusted", sources=(), last_verified=ago(100))
    fresh = mk("fresh", last_verified=ago(0))
    entries = [sure, unsure, fresh]
    p = plan(entries, cfg_with(topic="[2, 1000000]"), TODAY, sizes=sized(entries))  # at most 1 of 2 may be left
    assert names(p.evict) == ["unsure", "fresh"]  # the sure old entry outscores the fresh one with the same support


def test_the_total_cap_evicts_across_scopes():
    entries = [*spread(3, "global"), *spread(3, "topic/jj")]
    p = plan(entries, cfg_with(total="[5, 1000000]"), TODAY, sizes=sized(entries))
    assert len(p.evict) == 2  # 6 -> 4, the target being 4.5
    assert sorted(d.rel for d in p.evict) == ["global/e02.md", "topic/jj/e02.md"]  # the two worst of the store


def test_the_total_cap_counts_bytes_too():
    entries = [*spread(3, "global"), *spread(3, "topic/jj")]
    p = plan(entries, cfg_with(total="[100, 500]"), TODAY, sizes=sized(entries))  # 600 bytes, target 450
    assert len(p.evict) == 2


def test_user_overflow_is_reported_not_deleted():
    users = [mk(f"u{i}", trust="user", last_verified=ago(i * 10)) for i in range(4)]
    agent = mk("agent", last_verified=ago(1))
    entries = [*users, agent]
    p = plan(entries, cfg_with(topic="[2, 1000000]"), TODAY, sizes=sized(entries))
    assert names(p.evict) == ["agent"]
    assert p.user_overflow == {"topic/jj": ("topic/jj/u3.md", "topic/jj/u2.md", "topic/jj/u1.md", "topic/jj/u0.md")}


def test_user_overflow_of_the_total_budget():
    users = [mk(f"u{i}", scope, trust="user") for i, scope in enumerate(["global", "topic/jj", "lang/go"])]
    p = plan(users, cfg_with(total="[2, 1000000]"), TODAY, sizes=sized(users))
    assert p.evict == ()
    assert list(p.user_overflow) == ["total"]
    assert sorted(p.user_overflow["total"]) == sorted(u.rel for u in users)


def test_nothing_is_reported_when_the_overflow_holds_no_user_entries():
    entries = [mk(f"p{i}", created=ago(3)) for i in range(3)]  # all new, so protected
    p = plan(entries, cfg_with(topic="[2, 1000000]"), TODAY, sizes=sized(entries))
    assert (p.evict, p.user_overflow) == ((), {})


def test_ties_are_broken_by_path():
    entries = [mk(name) for name in ("b", "a", "c")]
    p = plan(entries, cfg_with(topic="[2, 1000000]"), TODAY, sizes=sized(entries))
    assert names(p.evict) == ["a", "b"]


def test_sizes_default_to_the_rendered_entries():
    entries = spread(4)
    assert plan(entries, cfg_with(topic="[10, 1000000]"), TODAY).evict == ()
    assert len(plan(entries, cfg_with(topic="[10, 100]"), TODAY).evict) == 4  # a rendered entry is over 100 bytes


# what the weekly run and the index use


def test_crowded_scopes_are_those_at_80_percent():
    entries = spread(8)
    cfg = cfg_with(topic="[10, 1000]", total="[100, 100000]")
    assert retention.crowded(entries, cfg, sized(entries, 10)) == ["topic/jj"]
    assert retention.crowded(entries[:7], cfg, sized(entries, 10)) == []
    assert retention.crowded(entries[:2], cfg, sized(entries, 450)) == ["topic/jj"]  # 900 of 1000 bytes


def test_stale_flags_mark_the_stale_entries():
    entries = [mk("fresh"), mk("old", kind="fact", last_verified=ago(150))]
    assert retention.stale_flags(entries, TODAY) == {"topic/jj/old.md": ["stale"]}


def test_a_drop_has_a_commit_line():
    e = mk("old", kind="fact", last_verified=ago(200), sources=(src(1), src(1), src(2)))
    entries = [e, mk("fresh")]
    d = plan(entries, cfg_with(topic="[1, 1000000]"), TODAY, sizes=sized(entries)).evict[0]  # the lowest score first
    assert retention.drop_line(d) == f"topic/jj/old.md {retention.score(e, TODAY):.2f}"
