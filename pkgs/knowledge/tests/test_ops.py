import pytest

from knowledge import data
from knowledge.data import Json, Obj, ParseError
from knowledge.ops import (
    Decision,
    DeleteOp,
    PrivateOp,
    SetStatusOp,
    SkillOp,
    ValidationContext,
    VerifiedOp,
    WriteOp,
    decision_keys,
    decision_obj,
    parse_response,
    validate,
)

S1 = "s-20261006T153201Z-aaaaaa"
S2 = "s-20261006T153202Z-bbbbbb"
S3 = "s-20261006T153203Z-cccccc"
S4 = "s-20261006T153204Z-dddddd"
S5 = "s-20261006T153205Z-eeeeee"


def fields(**over: Json) -> Obj:
    entry: Obj = {
        "description": "Never use enums in TypeScript",
        "kind": "convention",
        "tags": ["typescript"],
        "confidence": "medium",
        "status": "active",
        "verify": None,
        "related": [],
    }
    entry.update(over)
    return entry


def write(path: str = "lang/typescript/no-enums.md", body: str = "Rule. Why. Example.", **over: Json) -> Obj:
    return {"op": "write", "path": path, "entry": fields(**over), "body": body}


def skill(**over: Json) -> Obj:
    op: Obj = {
        "op": "skill",
        "name": "typescript-style",
        "description": "Use when writing TypeScript",
        "body": "- Prefer unions to enums.",
        "summary": "TypeScript conventions",
        "sources": ["lang/typescript/no-enums.md"],
    }
    op.update(over)
    return op


def decision(submission: str | None, verdict: str, *ops: Obj, reason: str = "because") -> Obj:
    return {"submission": submission, "verdict": verdict, "reason": reason, "ops": list(ops)}


def doc(*decisions: Obj) -> str:
    return data.dumps({"decisions": list(decisions)})


def fenced(text: str) -> str:
    return f"```json\n{text}\n```"


def ctx(*pending: str, mode: str = "intake", slugs: tuple[str, ...] = ("dotfiles",)) -> ValidationContext:
    return ValidationContext(pending_ids=frozenset(pending), project_slugs=frozenset(slugs), mode=mode)


def check(*decisions: Obj, pending: tuple[str, ...] = (S1,), mode: str = "intake") -> dict[str, list[str]]:
    return validate(parse_response(doc(*decisions)), ctx(*pending, mode=mode))


def only_errors(problems: dict[str, list[str]]) -> str:
    assert len(problems) == 1
    return "\n".join(next(iter(problems.values())))


def test_a_valid_document_covering_every_op():
    text = fenced(
        doc(
            decision(S1, "create", write(), {"op": "private", "org": "acme", "section": "sandbox db", "body": "pw"}),
            decision(
                S2,
                "merge",
                write("topic/jj/absorb.md", kind="gotcha", verify="jj absorb --help", related=["lang/typescript/no-enums.md"]),
                {"op": "delete", "path": "topic/jj/absorb-old.md", "reason": "merged"},
            ),
            decision(S3, "playbook", write("projects/dotfiles/facts/nix-layout.md", kind="reference", status="disputed")),
            decision(S4, "skill", skill()),
            decision(S5, "reject"),
            decision(None, "maintain", {"op": "verified", "path": "topic/jj/absorb.md"}, {"op": "set_status", "path": "global/x.md", "status": "disputed"}),
            decision(None, "skill", skill(name="other-style", sources=[])),
        )
    )
    resp = parse_response(text)
    assert len(resp.decisions) == 7
    assert [d.verdict for d in resp.decisions] == ["create", "merge", "playbook", "skill", "reject", "maintain", "skill"]
    assert all(d.errors == () for d in resp.decisions)

    first = resp.decisions[0]
    assert first.submission == S1
    assert first.reason == "because"
    w, p = first.ops
    assert isinstance(w, WriteOp)
    assert (w.path, w.body) == ("lang/typescript/no-enums.md", "Rule. Why. Example.")
    assert (w.entry.kind, w.entry.tags, w.entry.verify, w.entry.related) == ("convention", ("typescript",), None, ())
    assert p == PrivateOp(org="acme", section="sandbox db", body="pw")

    merge_ops = resp.decisions[1].ops
    assert isinstance(merge_ops[0], WriteOp)
    assert merge_ops[0].entry.related == ("lang/typescript/no-enums.md",)
    assert merge_ops[1] == DeleteOp(path="topic/jj/absorb-old.md", reason="merged")

    s = resp.decisions[3].ops[0]
    assert isinstance(s, SkillOp)
    assert s == SkillOp(
        name="typescript-style",
        description="Use when writing TypeScript",
        body="- Prefer unions to enums.",
        summary="TypeScript conventions",
        sources=("lang/typescript/no-enums.md",),
    )
    assert resp.decisions[5].ops == (
        VerifiedOp(path="topic/jj/absorb.md"),
        SetStatusOp(path="global/x.md", status="disputed"),
    )
    other = resp.decisions[6].ops[0]
    assert isinstance(other, SkillOp)
    assert (other.name, other.sources) == ("other-style", ())

    assert validate(resp, ctx(S1, S2, S3, S4, S5, mode="weekly")) == {}


def test_the_last_fenced_block_wins():
    first = doc(decision(S1, "reject", reason="first"))
    last = doc(decision(S1, "reject", reason="last"))
    text = f"Thinking about it.\n{fenced(first)}\nOn second thought:\n{fenced(last)}\n"
    assert [d.reason for d in parse_response(text).decisions] == ["last"]


def test_bare_json_is_accepted():
    text = doc(decision(S1, "reject"))
    assert len(parse_response(text).decisions) == 1
    assert len(parse_response(f"\n  {text}\n\n").decisions) == 1


def test_a_fenced_block_is_not_confused_by_fences_inside_strings():
    body = "```ts\nlet x = 1\n```"
    text = fenced(doc(decision(S1, "create", write(body=body))))
    op = parse_response(text).decisions[0].ops[0]
    assert isinstance(op, WriteOp)
    assert op.body == body


@pytest.mark.parametrize(
    "text",
    [
        "",
        "  \n",
        "I could not decide.",
        "```json\n{not json\n```",
        "[]",
        '"text"',
        '{"decisions": 3}',
        '{"decisions": {}}',
        "{}",
        '{"decisions": [], "extra": 1}',
        '{"decisions": ["x"]}',
        '{"decisions": [[]]}',
    ],
)
def test_garbage_is_a_parse_error(text: str):
    with pytest.raises(ParseError):
        parse_response(text)


def test_an_empty_decision_list_is_valid():
    assert parse_response('{"decisions": []}').decisions == ()
    assert validate(parse_response('{"decisions": []}'), ctx()) == {}


def test_a_broken_block_is_not_replaced_by_the_whole_text():
    text = doc(decision(S1, "reject")) + "\n" + fenced("{broken")
    with pytest.raises(ParseError):
        parse_response(text)


def test_unknown_keys_are_errors():
    bad = decision(S1, "reject")
    bad["colour"] = "red"
    assert "colour" in only_errors(check(bad))
    op = write()
    op["extra"] = 1
    assert "extra" in only_errors(check(decision(S1, "create", op)))
    entry = write(flavour="x")
    assert "flavour" in only_errors(check(decision(S1, "create", entry)))
    assert "mystery" in only_errors(check(decision(S1, "create", {"op": "mystery"})))
    assert "unknown keys" in only_errors(check(decision(S1, "create", {"op": "verified", "path": "global/x.md", "why": "?"})))


@pytest.mark.parametrize(
    ("op", "word"),
    [
        (write(kind="rumour"), "kind"),
        (write(confidence="certain"), "confidence"),
        (write(status="deleted"), "status"),
        ({"op": "delete", "path": "global/x.md", "reason": "boredom"}, "reason"),
        ({"op": "set_status", "path": "global/x.md", "status": "deleted"}, "status"),
    ],
)
def test_a_bad_enum_is_an_error(op: Obj, word: str):
    assert word in only_errors(check(decision(S1, "create", op)))


def test_a_bad_verdict_is_an_error():
    assert "verdict" in only_errors(check(decision(S1, "adopt")))
    assert "verdict" in only_errors(check({"submission": S1, "ops": []}))


def test_dispute_is_a_verdict():
    flag = {"op": "set_status", "path": "global/x.md", "status": "disputed"}
    assert check(decision(S1, "dispute", flag, reason="contradicts global/y.md")) == {}
    assert check(decision(None, "dispute", flag), pending=(), mode="weekly") != {}  # only maintain and skill have no submission


def test_a_decision_round_trips_through_decision_obj():
    docs = [
        decision(S1, "create", write(), {"op": "private", "org": "acme", "section": "sandbox db", "body": "pw"}),
        decision(S2, "merge", write("topic/jj/absorb.md", verify="jj absorb --help"), {"op": "delete", "path": "topic/jj/old.md", "reason": "merged"}),
        decision(S3, "dispute", {"op": "set_status", "path": "global/x.md", "status": "disputed"}),
        decision(S4, "skill", skill()),
        decision(None, "maintain", {"op": "verified", "path": "topic/jj/absorb.md"}),
    ]
    parsed = parse_response(doc(*docs)).decisions
    assert [decision_obj(d) for d in parsed] == docs
    assert parse_response(doc(*[decision_obj(d) for d in parsed])).decisions == parsed


def test_reject_with_ops_is_an_error():
    problems = check(decision(S1, "reject", write()))
    assert set(problems) == {S1}
    assert "no ops" in only_errors(problems)
    assert check(decision(S1, "reject")) == {}


@pytest.mark.parametrize("verdict", ["create", "merge", "supersede", "playbook", "dispute"])
def test_every_verdict_but_reject_needs_an_op(verdict: str):
    assert "at least one op" in only_errors(check(decision(S1, verdict)))
    assert check(decision(S1, verdict, write())) == {}
    for weekly in ("maintain", "skill"):
        assert "at least one op" in only_errors(check(decision(None, weekly), pending=(), mode="weekly"))


def test_the_reason_is_one_short_line():
    assert check(decision(S1, "reject", reason="r" * 300)) == {}
    assert "at most 300" in only_errors(check(decision(S1, "reject", reason="r" * 301)))
    for bad in ("two\nlines", "carriage\rreturn", "nul\x00byte", "escape\x1b[0m", "tab\there", "del\x7f"):
        assert "control characters" in only_errors(check(decision(S1, "reject", reason=bad)))
    assert "control characters" in only_errors(check(decision(S1, "create", write(), reason="a\nb")))


def test_a_duplicate_submission_is_an_error_on_the_second_decision():
    problems = check(decision(S1, "reject"), decision(S1, "reject"))
    assert list(problems) == [f"{S1}#2"]
    assert "more than once" in problems[f"{S1}#2"][0]


def test_a_submission_that_is_not_pending_is_an_error():
    problems = check(decision(S2, "reject"), decision(S1, "reject"))
    assert list(problems) == [S2]
    assert "not pending" in problems[S2][0]


def test_facts_for_an_unknown_slug_are_an_error():
    assert check(decision(S1, "create", write("projects/dotfiles/facts/a.md"))) == {}
    assert "unknown project" in only_errors(check(decision(S1, "create", write("projects/ghost/facts/a.md"))))
    assert "unknown project" in only_errors(check(decision(S1, "create", write(related=["projects/ghost/facts/a.md"]))))
    assert "unknown project" in only_errors(check(decision(S1, "create", {"op": "verified", "path": "projects/ghost/facts/a.md"})))


@pytest.mark.parametrize("path", ["README.md", "global.md", "lang/typescript/Bad Name.md", "elsewhere/x/y.md", "global/x.txt", "projects/dotfiles/overview.md"])
def test_a_path_must_be_an_entry(path: str):
    assert check(decision(S1, "create", {"op": "verified", "path": path}))


def test_maintain_is_only_valid_in_weekly_mode():
    maintain = decision(None, "maintain", {"op": "verified", "path": "global/x.md"})
    assert check(maintain, pending=(), mode="weekly") == {}
    problems = check(maintain, pending=(), mode="intake")
    assert list(problems) == ["m-1"]
    assert "weekly" in "\n".join(problems["m-1"])


def test_maintain_has_no_submission():
    problems = check(decision(S1, "maintain"), mode="weekly")
    assert "no submission" in only_errors(problems)


def test_a_decision_without_a_submission_must_be_maintain_or_skill_in_weekly_mode():
    assert check(decision(None, "create", write()), pending=(), mode="weekly")
    assert check(decision(None, "skill", skill()), pending=(), mode="weekly") == {}
    assert check(decision(None, "skill", skill()), pending=(), mode="intake")
    assert check(decision(None, "reject"), pending=(), mode="weekly")


def test_weekly_mode_still_takes_submissions():
    maintain = decision(None, "maintain", {"op": "verified", "path": "global/x.md"})
    assert check(decision(S1, "create", write()), maintain, mode="weekly") == {}


def test_an_undecided_id_is_reported():
    problems = check(decision(S1, "reject"), pending=(S1, S2, S3))
    assert problems == {S2: ["undecided"], S3: ["undecided"]}
    assert validate(parse_response('{"decisions": []}'), ctx(S1)) == {S1: ["undecided"]}


def test_an_invalid_decision_is_still_decided():
    assert check(decision(S1, "adopt")).keys() == {S1}  # not also "undecided"


def test_the_keys_of_the_decisions():
    maintain = decision(None, "maintain", {"op": "verified", "path": "global/x.md"})
    resp = parse_response(doc(decision(S1, "reject"), maintain, decision(S1, "reject"), decision(None, "skill", skill()), decision(S1, "reject")))
    assert decision_keys(resp) == [S1, "m-1", f"{S1}#2", "m-2", f"{S1}#3"]
    assert decision_keys(resp, "r-20261006T153201Z")[1] == "m-r-20261006T153201Z-1"
    keyed = validate(resp, ValidationContext(frozenset({S1}), frozenset(), "weekly", run_id="r-1"))
    assert set(keyed) == {f"{S1}#2", f"{S1}#3"}


def test_a_type_error_condemns_only_its_decision():
    broken = {"submission": S1, "verdict": "create", "reason": "x", "ops": [write(tags="typescript"), {"op": "verified"}]}
    resp = parse_response(doc(broken, decision(S2, "reject")))
    assert len(resp.decisions[0].errors) == 2
    assert resp.decisions[0].ops == ()
    assert resp.decisions[1].errors == ()
    problems = validate(resp, ctx(S1, S2))
    assert list(problems) == [S1]
    assert "tags" in problems[S1][0]
    assert parse_response(doc({"submission": 3, "verdict": "reject"})).decisions[0].errors
    assert parse_response(doc({"submission": S1, "verdict": "reject", "ops": "none"})).decisions[0].errors
    assert parse_response(doc({"submission": S1, "verdict": "create", "ops": [7]})).decisions[0].errors


def test_a_missing_reason_is_empty():
    resp = parse_response('{"decisions": [{"submission": null, "verdict": "maintain"}]}')
    assert resp.decisions == (Decision(submission=None, verdict="maintain", reason="", ops=()),)


def test_body_limits_by_kind():
    ok = "a" * 4096
    assert check(decision(S1, "create", write(body=ok, kind="fact"))) == {}
    assert "4096" in only_errors(check(decision(S1, "create", write(body=ok + "a", kind="fact"))))
    assert "byte limit" in only_errors(check(decision(S1, "create", write(body="ł" * 2049, kind="gotcha"))))  # 2 bytes each
    assert check(decision(S1, "create", write(body="a" * 32768, kind="reference"))) == {}
    assert "32768" in only_errors(check(decision(S1, "create", write(body="a" * 32769, kind="reference"))))
    assert "body" in only_errors(check(decision(S1, "create", write(body="  \n"))))


def test_write_fields_are_checked():
    def errors(**over: Json) -> str:
        return only_errors(check(decision(S1, "create", write(**over))))

    assert "description" in errors(description="")
    assert "description" in errors(description="x" * 201)
    assert "single line" in errors(description="two\nlines")
    assert check(decision(S1, "create", write(description="x" * 200))) == {}
    assert "tags" in errors(tags=["a"] * 9)
    assert "tags" in errors(tags=["Not Kebab"])
    assert check(decision(S1, "create", write(tags=["a"] * 8))) == {}
    assert "verify" in errors(verify="v" * 301)
    assert check(decision(S1, "create", write(verify="v" * 300))) == {}
    assert "related" in errors(related=["nonsense"])


def test_a_write_reports_every_problem():
    errs = only_errors(check(decision(S1, "create", write(kind="rumour", confidence="certain"))))
    assert "kind" in errs
    assert "confidence" in errs
    assert errs.startswith("ops[0]: ")


def test_private_ops_are_checked():
    def private(**over: Json) -> Obj:
        op: Obj = {"op": "private", "org": "acme", "section": "db", "body": "pw"}
        op.update(over)
        return op

    assert check(decision(S1, "create", private(section="s" * 80, body="b" * 16384))) == {}
    assert "org" in only_errors(check(decision(S1, "create", private(org="Soft Net"))))
    assert "section" in only_errors(check(decision(S1, "create", private(section=""))))
    assert "section" in only_errors(check(decision(S1, "create", private(section="s" * 81))))
    assert "single line" in only_errors(check(decision(S1, "create", private(section="a\nb"))))
    assert "body" in only_errors(check(decision(S1, "create", private(body=""))))
    assert "body" in only_errors(check(decision(S1, "create", private(body="b" * 16385))))
    assert "## " in only_errors(check(decision(S1, "create", private(body="fine\n## Other section\nmore"))))
    assert check(decision(S1, "create", private(body="fine ## not at the start\n### deeper"))) == {}


def test_skill_ops_are_checked():
    def errors(**over: Json) -> str:
        return only_errors(check(decision(S1, "skill", skill(**over))))

    assert "name" in errors(name="Bad Name")
    assert "summary" in errors(summary="")
    assert "summary" in errors(summary="s" * 201)
    assert "single line" in errors(summary="a\nb")
    assert "sources" in errors(sources=["nonsense"])
    assert "description" in errors(description="")
    assert "description" in errors(description="d" * 1025)
    assert "single line" in errors(description="two\nlines")
    assert "body" in errors(body="")
    assert "body" in errors(body="b" * 16385)
    assert "---" in errors(body="---\nname: x\n---\nbody")
    assert "---" in errors(body="\n  ---\nbody")
    assert check(decision(S1, "skill", skill(description="d" * 1024, body="b" * 16384, summary="s" * 200, sources=[]))) == {}


def test_a_skill_op_has_exactly_its_keys():
    """An unknown key is an error, and so is a missing field."""
    assert "colour" in only_errors(check(decision(S1, "skill", skill(colour="red"))))
    for key in ("description", "body", "summary"):
        op = skill()
        del op[key]
        assert key in only_errors(check(decision(S1, "skill", op)))
    assert check(decision(S1, "skill", skill(sources=[]))) == {}  # no sources is fine; the others are required
