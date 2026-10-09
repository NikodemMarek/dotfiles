import datetime
import stat

from knowledge import rejected
from knowledge.config import state_dir

DAY = datetime.date(2026, 10, 6)


def test_a_note_is_one_dated_line_with_the_newlines_collapsed():
    rejected.note("lang/ts/a.md (refuted):\nEnums\n  are  fine\n", DAY)
    rejected.note("b", datetime.date(2026, 10, 7))
    assert rejected.path() == state_dir() / "rejected.md"
    assert rejected.path().read_text() == "- 2026-10-06 lang/ts/a.md (refuted): Enums are fine\n- 2026-10-07 b\n"


def test_the_file_is_private():
    rejected.note("a", DAY)
    assert stat.S_IMODE(rejected.path().stat().st_mode) == 0o600
    assert stat.S_IMODE(state_dir().stat().st_mode) == 0o700


def test_a_note_appends_to_what_the_user_wrote():
    rejected.note("first", DAY)
    with rejected.path().open("a") as f:
        f.write("- by hand\n")
    rejected.note("last", DAY)
    assert rejected.recent() == ["- 2026-10-06 first", "- by hand", "- 2026-10-06 last"]


def test_recent_returns_the_tail_and_respects_the_limit():
    for i in range(5):
        rejected.note(f"n{i}", DAY)
    assert rejected.recent(2) == ["- 2026-10-06 n3", "- 2026-10-06 n4"]
    assert len(rejected.recent()) == 5
    assert rejected.recent(0) == []


def test_recent_skips_empty_lines_and_shows_at_most_the_default_limit():
    rejected.note("a", DAY)
    with rejected.path().open("a") as f:
        f.write("\n   \n")
    for i in range(rejected.SHOWN):
        rejected.note(f"n{i}", DAY)
    lines = rejected.recent()
    assert len(lines) == rejected.SHOWN
    assert lines[0] == "- 2026-10-06 n0"
    assert lines[-1] == f"- 2026-10-06 n{rejected.SHOWN - 1}"


def test_no_file_means_no_lines():
    assert not rejected.path().exists()
    assert rejected.recent() == []
