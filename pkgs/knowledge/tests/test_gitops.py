import subprocess
from pathlib import Path

import pytest

from knowledge import locks
from knowledge.gitops import Git, GitError
from knowledge.locks import FileLock, LockTimeout


def sh(repo: Path, *args: str) -> str:
    """Plain git, for the test's own setup and checks."""
    proc = subprocess.run(
        ["git", "-c", "core.hooksPath=/dev/null", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )
    return proc.stdout.strip()


def put(repo: Path, rel: str, text: str) -> None:
    path = repo / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def commit_count(repo: Path) -> int:
    return int(sh(repo, "rev-list", "--count", "HEAD"))


@pytest.fixture
def git(memory_repo: Path) -> Git:
    return Git(memory_repo, locks.memory_lock(), lock_timeout=0.05)


def test_ensure_repo_accepts_the_top_of_a_repo(git: Git):
    git.ensure_repo()


def test_ensure_repo_rejects_a_directory_inside_a_repo(memory_repo: Path):
    inner = memory_repo / "sub"
    inner.mkdir()
    with pytest.raises(GitError):
        Git(inner, locks.memory_lock()).ensure_repo()


def test_ensure_repo_rejects_a_missing_dir(tmp_path: Path):
    with pytest.raises(GitError):
        Git(tmp_path / "nope", locks.memory_lock()).ensure_repo()


def test_head_is_the_current_commit(git: Git, memory_repo: Path):
    assert git.head() == sh(memory_repo, "rev-parse", "HEAD")


def test_run_raises_with_gits_message(git: Git):
    with pytest.raises(GitError, match="rev-parse"):
        git.run("rev-parse", "--verify", "no-such-ref")


def test_commit_takes_only_the_given_paths(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    put(memory_repo, "global/b.md", "b\n")
    sha = git.commit(["global/a.md"], "knowledge: create global/a.md")
    assert sha == git.head()
    assert sh(memory_repo, "show", "--name-only", "--format=", "HEAD") == "global/a.md"
    assert sh(memory_repo, "status", "--porcelain", "-uall") == "?? global/b.md"


def test_commit_leaves_staged_changes_of_others_alone(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    put(memory_repo, "global/b.md", "b\n")
    sh(memory_repo, "add", "global/b.md")
    git.commit(["global/a.md"], "a")
    assert sh(memory_repo, "show", "--name-only", "--format=", "HEAD") == "global/a.md"
    assert sh(memory_repo, "status", "--porcelain") == "A  global/b.md"


def test_commit_records_a_deletion(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    git.commit(["global/a.md"], "add")
    (memory_repo / "global" / "a.md").unlink()
    assert git.commit(["global/a.md"], "delete") is not None
    assert sh(memory_repo, "ls-files", "global") == ""


def test_commit_without_changes_is_none(git: Git, memory_repo: Path):
    before = commit_count(memory_repo)
    assert git.commit(["README.md"], "nothing") is None
    assert git.commit([], "nothing") is None
    assert git.commit(["never/existed.md"], "nothing") is None
    assert commit_count(memory_repo) == before


def test_commit_writes_body_and_trailers(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    git.commit(
        ["global/a.md"],
        "knowledge: create global/a.md",
        body="why it was kept",
        trailers={"Submission": "s-1", "Run": "r-1"},
    )
    message = sh(memory_repo, "log", "-n1", "--format=%B")
    assert message == "knowledge: create global/a.md\n\nwhy it was kept\n\nSubmission: s-1\nRun: r-1"
    assert sh(memory_repo, "log", "-n1", "--format=%(trailers:key=Run,valueonly)") == "r-1"


def test_commit_ignores_a_failing_hook(git: Git, memory_repo: Path):
    hook = memory_repo / ".git" / "hooks" / "pre-commit"
    hook.parent.mkdir(exist_ok=True)
    hook.write_text("#!/bin/sh\nexit 1\n")
    hook.chmod(0o755)
    put(memory_repo, "global/a.md", "a\n")
    assert git.commit(["global/a.md"], "a") is not None


def test_commit_rejects_paths_outside_the_repo(git: Git):
    with pytest.raises(ValueError):
        git.commit(["../x.md"], "x")
    with pytest.raises(ValueError):
        git.commit(["/etc/passwd"], "x")


def test_commit_rejects_a_bad_trailer_key(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    with pytest.raises(ValueError):
        git.commit(["global/a.md"], "a", trailers={"Bad Key": "v"})


def test_commit_times_out_when_the_lock_is_held(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    before = commit_count(memory_repo)
    with FileLock(locks.memory_lock()):
        with pytest.raises(LockTimeout):
            git.commit(["global/a.md"], "a")
    assert commit_count(memory_repo) == before
    assert git.commit(["global/a.md"], "a") is not None


def test_trailer_values_and_commits_with_trailer(git: Git, memory_repo: Path):
    shas: list[str] = []
    for n in (1, 2, 3):
        put(memory_repo, f"global/{n}.md", f"{n}\n")
        sha = git.commit([f"global/{n}.md"], f"add {n}", trailers={"Run": f"r-{n % 2}", "Submission": "s-9"})
        assert sha is not None
        shas.append(sha)
    assert git.trailer_values("Run") == {"r-0", "r-1"}
    assert git.trailer_values("Submission") == {"s-9"}
    assert git.trailer_values("Nothing") == set()
    assert git.commits_with_trailer("Run", "r-1") == [shas[2], shas[0]]  # newest first
    assert git.commits_with_trailer("Run", "r-0") == [shas[1]]
    assert git.commits_with_trailer("Run", "r-7") == []
    assert git.commits_with_trailer("Nothing", "x") == []


def test_trailer_queries_of_a_repo_without_a_commit_are_empty(tmp_path: Path):
    repo = tmp_path / "fresh"
    repo.mkdir()
    sh(repo, "init", "-q", "-b", "main")
    git = Git(repo, locks.memory_lock())
    assert git.trailer_values("Submission") == set()
    assert git.commits_with_trailer("Submission", "s-1") == []


def test_an_argument_git_cannot_take_is_a_git_error(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    before = commit_count(memory_repo)
    with pytest.raises(GitError, match="null byte"):
        git.commit(["global/a.md"], "a", body="bad\0reason")
    with pytest.raises(GitError, match="null byte"):
        git.run("log", "--format=%H\0")
    assert commit_count(memory_repo) == before


def test_last_deleting_commit(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    git.commit(["global/a.md"], "add")
    assert git.last_deleting_commit("global/a.md") is None
    (memory_repo / "global" / "a.md").unlink()
    deleted = git.commit(["global/a.md"], "delete")
    assert deleted is not None
    assert git.last_deleting_commit("global/a.md") == deleted
    assert git.last_deleting_commit("global/other.md") is None


def test_show_reads_a_file_at_a_revision(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "old\n")
    first = git.commit(["global/a.md"], "add")
    assert first is not None
    put(memory_repo, "global/a.md", "new\n")
    git.commit(["global/a.md"], "change")
    assert git.show(first, "global/a.md") == "old\n"
    assert git.show("HEAD", "global/a.md") == "new\n"
    with pytest.raises(GitError):
        git.show(first, "global/missing.md")
    with pytest.raises(ValueError):
        git.show("--help", "global/a.md")


def test_restore_resets_modified_and_removes_untracked(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    git.commit(["global/a.md"], "add")
    put(memory_repo, "global/a.md", "changed\n")  # tracked, modified
    put(memory_repo, "global/new.md", "new\n")  # untracked
    put(memory_repo, "global/staged.md", "staged\n")  # added, not committed
    sh(memory_repo, "add", "global/staged.md")
    put(memory_repo, "global/other.md", "keep\n")  # not mentioned
    git.restore(
        ["global/a.md", "global/new.md", "global/staged.md", "global/gone.md"],
        created=["global/new.md", "global/staged.md"],
    )
    assert (memory_repo / "global" / "a.md").read_text() == "a\n"
    assert not (memory_repo / "global" / "new.md").exists()
    assert not (memory_repo / "global" / "staged.md").exists()
    assert (memory_repo / "global" / "other.md").read_text() == "keep\n"
    assert sh(memory_repo, "status", "--porcelain") == "?? global/other.md"


def test_restore_keeps_a_file_that_is_not_in_head_unless_it_was_created(git: Git, memory_repo: Path):
    put(memory_repo, "global/mine.md", "made by the caller\n")
    put(memory_repo, "global/yours.md", "was here before\n")
    put(memory_repo, "global/staged.md", "staged by someone\n")
    sh(memory_repo, "add", "global/staged.md")
    git.restore(["global/mine.md", "global/yours.md", "global/staged.md"], created=["global/mine.md"])
    assert not (memory_repo / "global" / "mine.md").exists()
    assert (memory_repo / "global" / "yours.md").read_text() == "was here before\n"
    assert (memory_repo / "global" / "staged.md").read_text() == "staged by someone\n"
    assert sh(memory_repo, "status", "--porcelain", "-uall") == "?? global/staged.md\n?? global/yours.md"


def test_restore_ignores_created_paths_that_are_not_asked_for(git: Git, memory_repo: Path):
    put(memory_repo, "global/new.md", "new\n")
    git.restore([], created=["global/new.md"])
    git.restore(["README.md"], created=["global/new.md"])
    assert (memory_repo / "global" / "new.md").exists()


def test_restore_takes_the_memory_lock(git: Git, memory_repo: Path):
    put(memory_repo, "global/new.md", "new\n")
    with FileLock(locks.memory_lock()):
        with pytest.raises(LockTimeout):
            git.restore(["global/new.md"], created=["global/new.md"])
    assert (memory_repo / "global" / "new.md").exists()
    git.restore(["global/new.md"], created=["global/new.md"])
    assert not (memory_repo / "global" / "new.md").exists()


@pytest.mark.parametrize("path", [".git/config", ".git", "global/.git/x", "./.git/hooks/pre-commit", ".GIT/config"])
def test_paths_inside_dot_git_are_refused(git: Git, path: str):
    with pytest.raises(ValueError):
        git.commit([path], "x")
    with pytest.raises(ValueError):
        git.restore([path])
    with pytest.raises(ValueError):
        git.restore(["README.md"], created=[path])


def test_a_dot_git_look_alike_is_an_ordinary_path(git: Git, memory_repo: Path):
    put(memory_repo, "global/.gitkeep", "")
    assert git.commit(["global/.gitkeep"], "keep") is not None


def test_git_ignores_variables_that_point_elsewhere(git: Git, memory_repo: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("GIT_DIR", str(tmp_path / "elsewhere"))
    monkeypatch.setenv("GIT_WORK_TREE", str(tmp_path / "elsewhere"))
    monkeypatch.setenv("GIT_INDEX_FILE", str(tmp_path / "elsewhere.index"))
    monkeypatch.setenv("GIT_OBJECT_DIRECTORY", str(tmp_path / "elsewhere-objects"))
    monkeypatch.setenv("GIT_COMMON_DIR", str(tmp_path / "elsewhere"))
    monkeypatch.setenv("GIT_NAMESPACE", "other")
    monkeypatch.setenv("GIT_PREFIX", "sub/")
    git.ensure_repo()
    put(memory_repo, "global/a.md", "a\n")
    sha = git.commit(["global/a.md"], "a")  # (the plain `sh` helper would see the variables too)
    assert sha is not None and sha == git.head()
    assert git.run("log", "-n1", "--format=%s", "--name-only").split() == ["a", "global/a.md"]
    assert not (tmp_path / "elsewhere").exists()


def test_restore_brings_back_a_deleted_file(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    git.commit(["global/a.md"], "add")
    (memory_repo / "global" / "a.md").unlink()
    git.restore(["global/a.md"])
    assert (memory_repo / "global" / "a.md").read_text() == "a\n"


def test_revert_undoes_commits_in_one_commit(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "one\n")
    git.commit(["global/a.md"], "add a")
    put(memory_repo, "global/a.md", "two\n")
    second = git.commit(["global/a.md"], "change a")
    put(memory_repo, "global/b.md", "b\n")
    third = git.commit(["global/b.md"], "add b")
    assert second is not None and third is not None
    before = commit_count(memory_repo)
    sha = git.revert([third, second], "knowledge: revert", {"Reverted": "run r-1"})
    assert sha == git.head()
    assert commit_count(memory_repo) == before + 1
    assert (memory_repo / "global" / "a.md").read_text() == "one\n"
    assert not (memory_repo / "global" / "b.md").exists()
    assert sh(memory_repo, "log", "-n1", "--format=%s") == "knowledge: revert"
    assert git.trailer_values("Reverted") == {"run r-1"}
    assert sh(memory_repo, "status", "--porcelain") == ""


def test_revert_of_a_deletion_brings_the_file_back(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "a\n")
    git.commit(["global/a.md"], "add")
    (memory_repo / "global" / "a.md").unlink()
    deleted = git.commit(["global/a.md"], "delete")
    assert deleted is not None
    git.revert([deleted], "undo")
    assert (memory_repo / "global" / "a.md").read_text() == "a\n"


def test_revert_conflict_leaves_nothing_behind(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "one\n")
    git.commit(["global/a.md"], "add")
    put(memory_repo, "global/a.md", "two\n")
    second = git.commit(["global/a.md"], "two")
    put(memory_repo, "global/a.md", "three\n")
    git.commit(["global/a.md"], "three")
    assert second is not None
    head = git.head()
    with pytest.raises(GitError):
        git.revert([second], "undo")
    assert git.head() == head
    assert sh(memory_repo, "status", "--porcelain") == ""
    assert (memory_repo / "global" / "a.md").read_text() == "three\n"


def test_revert_refuses_paths_with_uncommitted_changes(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "one\n")
    git.commit(["global/a.md"], "add a")
    put(memory_repo, "global/a.md", "two\n")
    second = git.commit(["global/a.md"], "change a")
    assert second is not None
    head = git.head()
    for dirty in ("edited\n", None):
        if dirty is None:
            (memory_repo / "global" / "a.md").unlink()
        else:
            put(memory_repo, "global/a.md", dirty)
        with pytest.raises(GitError, match="uncommitted"):
            git.revert([second], "undo")
        assert git.head() == head
    (memory_repo / "global" / "a.md").write_text("two\n")  # clean again
    git.revert([second], "undo")
    assert (memory_repo / "global" / "a.md").read_text() == "one\n"


def test_revert_ignores_changes_to_other_paths(git: Git, memory_repo: Path):
    put(memory_repo, "global/a.md", "one\n")
    git.commit(["global/a.md"], "add a")
    put(memory_repo, "global/other.md", "mine\n")
    put(memory_repo, "README.md", "edited\n")
    assert git.revert([git.head()], "undo") is not None
    assert (memory_repo / "global" / "other.md").read_text() == "mine\n"
    assert (memory_repo / "README.md").read_text() == "edited\n"


def test_revert_failing_after_it_started_puts_the_paths_back(git: Git, memory_repo: Path, monkeypatch: pytest.MonkeyPatch):
    put(memory_repo, "global/a.md", "a\n")
    put(memory_repo, "global/b.md", "b\n")
    git.commit(["global/a.md", "global/b.md"], "add both")
    (memory_repo / "global" / "a.md").unlink()
    deleted = git.commit(["global/a.md"], "delete a")  # reverting it brings a.md back
    put(memory_repo, "global/b.md", "b2\n")
    changed = git.commit(["global/b.md"], "change b")
    assert deleted is not None and changed is not None
    head = git.head()

    def fail(*args: object, **kwargs: object) -> str:
        raise GitError("commit", "boom")

    monkeypatch.setattr(git, "_commit", fail)
    with pytest.raises(GitError, match="boom"):
        git.revert([changed, deleted], "undo")
    assert git.head() == head
    assert sh(memory_repo, "status", "--porcelain", "-uall") == ""
    assert not (memory_repo / "global" / "a.md").exists()  # not in HEAD: what the revert made is removed
    assert (memory_repo / "global" / "b.md").read_text() == "b2\n"


def test_revert_needs_commits_and_valid_ids(git: Git):
    with pytest.raises(ValueError):
        git.revert([], "undo")
    with pytest.raises(ValueError):
        git.revert(["--abort"], "undo")
    with pytest.raises(ValueError):
        git.revert(["HEAD"], "undo")
