#!/usr/bin/env python3
"""Claude Code hooks: run isolated subagents in their own jj workspace.

  create  (WorktreeCreate)  jj repo: `jj workspace add` at <repo>.agents/<name>, whose @ is a new
                            change on top of the caller's current change (the "base"). Prints the
                            directory. Not a jj repo: plain git worktree, like Claude's default.
  stop    (SubagentStop)    the stopping agent owns a workspace: squash its work into the base
                            change. The workspace stays, so the agent can be resumed.
  remove  (WorktreeRemove)  integrate leftovers, forget the workspace, delete its directory.

Agent worktrees are named `agent-<agent_id>`; SubagentStop's agent_id finds them again. Other
names (`claude --worktree foo`) get a jj workspace too, but are never squashed automatically.
The registry lives in $CLAUDE_CONFIG_DIR/jj-agents/<repo-hash>/<name>.json (default
~/.claude/jj-agents), written only by `create` (which runs with the caller's cwd), so an agent
can't redirect the hook. Claude never calls WorktreeRemove for agent worktrees, so idle ones are
deleted after GC_AGE. A failed or conflicted squash keeps the workspace and is reported.
"""

import fcntl
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

CONFIG_DIR = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
REGISTRY = os.path.join(CONFIG_DIR, "jj-agents")
TRANSCRIPTS = os.path.join(CONFIG_DIR, "projects/*/*/subagents/{name}.jsonl")
GC_AGE = 24 * 3600
LOCK_TIMEOUT = 120
AGENT_NAME = re.compile(r"^agent-[0-9a-f]+$")
VALID_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$")


class Fail(Exception):
    pass


class Conflict(Fail):
    pass


def log(msg):
    print(f"jj-workspace: {msg}", file=sys.stderr)


def jj(repo, *args, check=True):
    p = subprocess.run(["jj", "--no-pager", "--color=never", "-R", repo, *args],
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if check and p.returncode != 0:
        raise Fail(f"`jj {' '.join(args)}` in {repo}: {p.stderr.strip()}")
    return p.stdout


def git(cwd, *args):
    p = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True,
                       stdin=subprocess.DEVNULL)
    if p.returncode != 0:
        raise Fail(f"`git {' '.join(args)}`: {p.stderr.strip()}")
    sys.stderr.write(p.stdout)  # keep stdout clean: it must carry only the path
    return p.stdout


def inside(path, parent):
    path, parent = os.path.realpath(path), os.path.realpath(parent)
    return path == parent or path.startswith(parent + os.sep)


# ------------------------------------------------------------------ registry

def workspace_root(path):
    p = subprocess.run(["jj", "--no-pager", "-R", path, "workspace", "root"],
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return p.stdout.strip() if p.returncode == 0 else None


def store_of(ws_root):
    """The shared repo store; in secondary workspaces .jj/repo is a file pointing to it."""
    repo = os.path.join(ws_root, ".jj", "repo")
    if os.path.isfile(repo):
        with open(repo) as f:
            target = f.read().strip()
        repo = target if os.path.isabs(target) else os.path.join(os.path.dirname(repo), target)
    return os.path.realpath(repo)


def registry_of(store):
    d = os.path.join(REGISTRY, hashlib.sha256(store.encode()).hexdigest()[:16])
    os.makedirs(d, exist_ok=True)
    return d


def reg_path(reg, name):
    return os.path.join(reg, f"{name}.json")


def load(path):
    try:
        with open(path) as f:
            st = json.load(f)
        return st if all(k in st for k in ("name", "root", "dir", "base", "kind")) else None
    except (OSError, ValueError):
        return None


def save(reg, st):
    path = reg_path(reg, st["name"])
    with open(path + ".tmp", "w") as f:
        json.dump(st, f, indent=1)
    os.replace(path + ".tmp", path)


def drop(reg, name):
    try:
        os.remove(reg_path(reg, name))
    except FileNotFoundError:
        pass


def all_states(reg):
    for path in sorted(glob.glob(os.path.join(reg, "*.json"))):
        st = load(path)
        if st:
            yield st


class Lock:
    def __init__(self, reg):
        self.f = open(os.path.join(reg, ".lock"), "w")

    def __enter__(self):
        deadline = time.time() + LOCK_TIMEOUT
        while True:
            try:
                fcntl.flock(self.f, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return self
            except BlockingIOError:
                if time.time() > deadline:
                    raise Fail("timed out waiting for the jj-workspace lock")
                time.sleep(0.2)

    def __exit__(self, *exc):
        fcntl.flock(self.f, fcntl.LOCK_UN)
        self.f.close()


# ------------------------------------------------------------------ jj operations

def refresh(ws):
    """Update a stale workspace and snapshot it without losing unsaved edits.

    A workspace goes stale whenever a commit under its @ is rewritten (the caller snapshotting
    base, another agent squashing into it). `update-stale` then snapshots unsaved edits into a
    divergent twin of @ and checks out the rebased clean @, so fold that twin back into @.
    """
    p = subprocess.run(["jj", "--no-pager", "-R", ws, "workspace", "update-stale"],
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if p.returncode != 0 and "not stale" not in p.stderr:
        raise Fail(f"update-stale in {ws}: {p.stderr.strip()}")
    cid = jj(ws, "log", "--no-graph", "-r", "@", "-T", "change_id").strip()
    twins = jj(ws, "log", "--no-graph", "-r", f"change_id({cid}) ~ @", "-T", 'commit_id.short() ++ " "').split()
    if twins:
        jj(ws, "squash", "--from", f"change_id({cid}) ~ @", "--into", "@", "-u")
        log(f"folded unsaved edits ({', '.join(twins)}) back into @ of {ws}")
    jj(ws, "status")


def check_base(ws, base):
    out = jj(ws, "log", "--no-graph", "-r", f"change_id({base})",
             "-T", 'if(immutable, "immutable", "ok") ++ "\\n"', check=False).split()
    if len(out) != 1:
        raise Fail(f"base change {base[:8]} is {'gone' if not out else 'divergent'}")
    if out[0] != "ok":
        raise Fail(f"base change {base[:8]} is immutable now")
    stray = jj(ws, "log", "--no-graph", "-r", f"(change_id({base})..@) ~ change_id({base})::",
               "-T", 'change_id.short(8) ++ " "').split()
    if stray:
        raise Fail(f"the agent's @ is no longer on top of base {base[:8]} (also contains {', '.join(stray)})")


def changed_files(st):
    return [l for l in jj(st["dir"], "diff", "--from", f"change_id({st['base']})", "--to", "@",
                          "--name-only").splitlines() if l]


def integrate(st):
    """Squash everything the agent did (base..@) into base. Returns a summary or None."""
    root, ws, base = st["root"], st["dir"], st["base"]
    refresh(root)  # the caller's unsaved edits first
    refresh(ws)
    check_base(ws, base)
    files = changed_files(st)
    if not files:
        return None
    jj(ws, "squash", "--from", f"change_id({base})..@", "--into", f"change_id({base})", "-u")
    refresh(root)  # base may be the caller's @
    info = jj(root, "log", "--no-graph", "-r", f"change_id({base})", "-T",
              'change_id.short(8) ++ "\\x1f" ++ description.first_line() ++ "\\n"').splitlines()
    if len(info) != 1:
        raise Fail(f"base change {base[:8]} became divergent while squashing (a concurrent jj command?); "
                   f"check `jj log -r 'change_id({base})'`")
    cid, title = info[0].split("\x1f")
    msg = f"jj: squashed {len(files)} file(s) from agent workspace {st['name']} into {cid} {title or '(no description)'}"
    conflicts = jj(root, "log", "--no-graph", "-r", f"change_id({base}):: & conflicts() ~ empty()",
                   "-T", 'change_id.short(8) ++ " "').split()
    if conflicts:
        raise Conflict(f"{msg}, which left CONFLICTS in {', '.join(conflicts)} "
                       f"(jj resolve --list -r <change>)")
    return msg


def delete_workspace(reg, st):
    agents = os.path.realpath(st["root"] + ".agents")
    d = os.path.realpath(st["dir"])
    if os.path.dirname(d) != agents or not VALID_NAME.match(os.path.basename(d)):
        raise Fail(f"refusing to delete {d}: not a workspace directly under {agents}")
    jj(st["root"], "workspace", "forget", st["name"], check=False)
    shutil.rmtree(d, ignore_errors=True)
    drop(reg, st["name"])
    try:
        os.rmdir(agents)
    except OSError:
        pass


def last_activity(st):
    times = [st.get("touched", 0)]
    times += [os.path.getmtime(p) for p in glob.glob(TRANSCRIPTS.format(name=st["name"]))]
    return max(times)


def gc(reg):
    """Delete agent workspaces idle for GC_AGE with nothing left to integrate."""
    now = time.time()
    for st in list(all_states(reg)):
        try:
            if st["kind"] != "agent" or now - last_activity(st) < GC_AGE:
                continue
            if os.path.isdir(st["dir"]):
                refresh(st["dir"])
                if changed_files(st):
                    continue
            delete_workspace(reg, st)
            log(f"cleaned up idle workspace {st['name']}")
        except Exception as e:
            log(f"gc {st['name']}: {e}")


# ------------------------------------------------------------------ hooks

def create(inp):
    cwd = inp.get("cwd") or os.getcwd()
    name = inp.get("name") or os.path.basename(inp.get("worktree_path") or "")
    if not VALID_NAME.match(name or "") or set(name) <= {"."}:
        raise Fail(f"invalid worktree name {name!r}")
    root = workspace_root(cwd)
    if not root:
        return create_git(cwd, name, inp)
    reg = registry_of(store_of(root))
    with Lock(reg):
        st = load(reg_path(reg, name))
        if st and os.path.isdir(st["dir"]):
            st["touched"] = time.time()  # resumed / repeated create
            save(reg, st)
            return st["dir"]
        if st:  # registered, but its directory is gone
            jj(st["root"], "workspace", "forget", name, check=False)
            drop(reg, name)
        elif name in jj(root, "workspace", "list", "-T", 'name ++ "\\n"').split():
            raise Fail(f"a jj workspace named {name!r} already exists and isn't managed by this hook")
        d = f"{root}.agents/{name}"
        if os.path.lexists(d):
            raise Fail(f"{d} already exists")
        base = jj(root, "log", "--no-graph", "-r", "@", "-T", "change_id").strip()  # snapshots
        os.makedirs(os.path.dirname(d), exist_ok=True)
        jj(root, "workspace", "add", f"--name={name}", "-r", f"change_id({base})", d)
        try:
            save(reg, {"name": name, "root": root, "dir": d, "base": base,
                       "kind": "agent" if AGENT_NAME.match(name) else "session",
                       "touched": time.time()})
        except Exception:
            jj(root, "workspace", "forget", name, check=False)
            shutil.rmtree(d, ignore_errors=True)
            raise
        log(f"created jj workspace {name} at {d} on top of {base[:8]}")
    with Lock(reg):
        gc(reg)
    return d


def create_git(cwd, name, inp):
    top = git(cwd, "rev-parse", "--show-toplevel").strip()
    wt = inp.get("worktree_path") or os.path.join(top, ".claude", "worktrees", name)
    if os.path.isdir(wt):
        return wt
    branch = inp.get("branch_name") or f"worktree-{name}"
    os.makedirs(os.path.dirname(wt), exist_ok=True)
    if inp.get("detach"):
        git(top, "worktree", "add", "--detach", wt, "HEAD")
    elif subprocess.run(["git", "-C", top, "show-ref", "--verify", "-q", f"refs/heads/{branch}"]).returncode == 0:
        git(top, "worktree", "add", wt, branch)
    else:
        git(top, "worktree", "add", "-b", branch, wt, "HEAD")
    return wt


def find_agent(agent_id):
    """Registry entry of an isolated agent, looked up only in the user-owned registry."""
    if not re.fullmatch(r"[0-9a-f]+", agent_id or ""):
        return None, None
    for path in glob.glob(os.path.join(REGISTRY, "*", f"agent-{agent_id}.json")):
        st = load(path)
        if st:
            return os.path.dirname(path), st
    return None, None


def stop(inp):
    """Never fails and never blocks the agent; reports problems instead."""
    reg, st = find_agent(inp.get("agent_id"))
    if not st or not inside(inp.get("cwd") or "/nonexistent", st["dir"]):
        return None  # agent wasn't isolated
    try:
        with Lock(reg):
            st = load(reg_path(reg, st["name"]))
            if not st:
                return None
            if not os.path.isdir(st["dir"]):
                raise Fail(f"workspace {st['dir']} no longer exists")
            msg = integrate(st)
            st["touched"] = time.time()
            save(reg, st)
    except Fail as e:
        if isinstance(e, Conflict):
            problem = f"{e}."
        else:
            problem = f"jj integration problem: {e}. The agent's work is kept in {st['dir']}."
        out = {"systemMessage": problem}
        if not inp.get("stop_hook_active"):
            out["hookSpecificOutput"] = {
                "hookEventName": "SubagentStop",
                "additionalContext": f"{problem} Reply with this sentence verbatim, followed by "
                                     "your complete previous final report unchanged."}
        return out
    return {"systemMessage": msg} if msg else None


def remove(inp):
    path = inp.get("worktree_path")
    if not path or not os.path.isdir(path):
        return
    for reg in glob.glob(os.path.join(REGISTRY, "*")):
        for st in all_states(reg):
            if os.path.realpath(st["dir"]) != os.path.realpath(path):
                continue
            with Lock(reg):
                st = load(reg_path(reg, st["name"]))
                if not st:
                    return
                if st["kind"] == "agent":
                    msg = integrate(st)
                    if msg:
                        log(msg)
                elif changed_files(st):
                    log(f"keeping {path}: it has changes")  # Claude's default for worktrees
                    return
                delete_workspace(reg, st)
            return
    if workspace_root(path):
        return  # a jj workspace this hook doesn't manage
    if not git(path, "status", "--porcelain").strip():
        git(path, "worktree", "remove", path)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        inp = json.load(sys.stdin)
        if not isinstance(inp, dict):
            raise ValueError("not a JSON object")
    except ValueError as e:
        log(f"bad hook input: {e}")
        return 0 if mode == "stop" else 1
    if mode == "stop":
        try:
            out = stop(inp)
        except Exception as e:  # SubagentStop must never block the agent
            out = {"systemMessage": f"jj-workspace stop hook error: {e}"}
        if out:
            print(json.dumps(out))
        return 0
    try:
        if mode == "create":
            print(create(inp))
        elif mode == "remove":
            remove(inp)
        else:
            log(f"unknown mode {mode!r}")
            return 1
    except Fail as e:
        log(str(e))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
