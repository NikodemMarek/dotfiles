import datetime
from pathlib import Path

import pytest

from knowledge import data, ideas
from knowledge.entry import EntryError
from knowledge.ops import SkillOp

TODAY = datetime.date(2026, 10, 6)


def op(**changes: object) -> SkillOp:
    fields: dict[str, object] = {
        "name": "typescript-style",
        "description": "Use when writing TypeScript",
        "body": "- Prefer unions to enums.\n- Name types in PascalCase.\n",
        "summary": "three entries agree on TypeScript style",
        "sources": ("lang/typescript/no-enums.md", "lang/typescript/pascal-case.md"),
    }
    fields.update(changes)
    return SkillOp(**fields)  # type: ignore[arg-type]


def test_render_is_a_skill_file_with_the_note_of_the_curator():
    text = ideas.render(op(), TODAY, existing=False)
    assert text == (
        "---\n"
        "name: typescript-style\n"
        "description: Use when writing TypeScript\n"
        "---\n"
        "\n"
        "- Prefer unions to enums.\n"
        "- Name types in PascalCase.\n"
        "\n"
        "<!-- skill idea of the knowledge curator, 2026-10-06: new skill\n"
        "why: three entries agree on TypeScript style\n"
        "sources: lang/typescript/no-enums.md, lang/typescript/pascal-case.md\n"
        "Copy to ~/projects/ai/skills/typescript-style/SKILL.md without this comment, "
        "then `knowledge drop --taken skill-ideas/typescript-style.md`; "
        "or `knowledge drop skill-ideas/typescript-style.md` to reject the idea. -->\n"
    )


def test_the_frontmatter_round_trips():
    description = "Use when: a 'quoted' value, # not a comment, and ünicode"
    text = ideas.render(op(description=description), TODAY, existing=False)
    head, sep, rest = text.removeprefix("---\n").partition("---\n")
    assert sep
    assert data.as_obj(data.load_yaml(head)) == {"name": "typescript-style", "description": description}
    assert rest.startswith("\n- Prefer unions to enums.\n")


def test_an_existing_skill_makes_it_an_update():
    text = ideas.render(op(), TODAY, existing=True)
    assert "2026-10-06: update of the existing skill skills/typescript-style\n" in text
    assert "new skill" not in text


def test_no_sources_are_a_dash():
    assert "\nsources: -\n" in ideas.render(op(sources=()), TODAY, existing=False)


def test_the_body_is_stripped():
    text = ideas.render(op(body="\n\nRule.\n\n\n"), TODAY, existing=False)
    assert "---\n\nRule.\n\n<!-- skill idea" in text


def test_rel():
    assert ideas.rel("typescript-style") == "skill-ideas/typescript-style.md"
    for bad in ("", "Bad Name", "../up", "a/b", "-x", "x" * 65):
        with pytest.raises(EntryError):
            ideas.rel(bad)


def test_names(tmp_path: Path):
    memory = tmp_path / "m"
    assert ideas.names(memory) == []  # no directory
    (memory / ideas.DIR).mkdir(parents=True)
    assert ideas.names(memory) == []
    for name in ("b-skill.md", "a-skill.md", "notes.txt"):
        (memory / ideas.DIR / name).write_text("x\n")
    (memory / ideas.DIR / "dir.md").mkdir()
    assert ideas.names(memory) == ["a-skill", "b-skill"]
