#!/usr/bin/env python3
"""jw: quick jj workspaces for the repos under ~/projects, at <repo>.agents/<name> (the layout the claude wrapper uses too).

new, cd, rm and clone print the directory to go to on stdout; the `jw` fish function cds there.
Everything else goes to stderr.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.expanduser("~/projects")
FZF = "fzf"  # the nix package pins the store path
NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


class Fail(Exception):
    pass


def jj(*args, cwd=None):
    """Run jj; its own messages and errors go straight to the terminal."""
    p = subprocess.run(["jj", "--no-pager", *args], cwd=cwd, stdout=subprocess.PIPE, text=True)
    if p.returncode != 0:
        raise Fail()  # jj already said why
    return p.stdout


def locate():
    """(root of the current workspace, home = root of the main workspace)."""
    p = subprocess.run(["jj", "--ignore-working-copy", "workspace", "root"],
                       capture_output=True, text=True)
    if p.returncode != 0:
        raise Fail("not in a jj repo")
    root = p.stdout.strip()
    parent = os.path.dirname(root)
    home = parent.removesuffix(".agents") if re.search(r".\.agents$", parent) else root
    return root, home


def repos():
    """Sorted names of the jj repos directly in ROOT."""
    try:
        entries = list(os.scandir(ROOT))
    except FileNotFoundError:
        return []
    return sorted(e.name for e in entries
                  if not e.name.startswith(".") and not e.name.endswith(".agents")
                  and os.path.isdir(f"{e.path}/.jj"))


def workspaces():
    """Every repo and every workspace of it, relative to ROOT."""
    found = []
    for r in repos():
        found.append(r)
        try:
            subs = os.scandir(f"{ROOT}/{r}.agents")
        except OSError:
            continue
        found += [f"{r}.agents/{s.name}" for s in subs if os.path.isdir(f"{s.path}/.jj")]
    return sorted(found)


def pick(items, query=""):
    """Let the user choose with fzf (it draws on /dev/tty, so the fish function can capture stdout)."""
    if not items:
        raise Fail("no jj repos under ~/projects")
    p = subprocess.run([FZF, "--select-1", "--exit-0", "--query", query],
                       input="\n".join(items), stdout=subprocess.PIPE, text=True)
    if p.returncode == 1:
        raise Fail("no match")
    if p.returncode != 0:
        raise Fail()  # cancelled
    return p.stdout.strip()


def repo_home(arg):
    """The repo to act on: the named/picked one, else the current one, else a picked one."""
    if arg:
        if os.path.isdir(f"{ROOT}/{arg}/.jj"):
            return f"{ROOT}/{arg}"
        return f"{ROOT}/{pick(repos(), arg)}"
    try:
        return locate()[1]
    except Fail:
        return f"{ROOT}/{pick(repos())}"


def in_use(d):
    """Whether some process has its working directory in d."""
    d = os.path.realpath(d)
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            cwd = os.readlink(f"/proc/{pid}/cwd")
        except OSError:
            continue
        if cwd == d or cwd.startswith(d + "/"):
            return True
    return False


def cmd_new(a):
    home = repo_home(a.repo)
    try:
        jj("--ignore-working-copy", "git", "fetch", cwd=home)
    except Fail:
        sys.stderr.write("jw: fetch failed, continuing\n")
    name = time.strftime("w-%m%d-%H%M%S")
    # resolve first: `workspace add` leaves its directory behind on a bad revision
    commits = jj("--ignore-working-copy", "log", "--no-graph", "-r", a.revision,
                 "-T", 'if(root, "root", commit_id) ++ "\\n"', cwd=home).split()
    if len(commits) != 1:
        raise Fail(f"{a.revision!r} must be exactly one commit, not {len(commits)}")
    if commits[0] == "root":
        raise Fail(f"{a.revision} resolves to the root commit; pass -r")
    d = f"{home}.agents/{name}"
    os.makedirs(os.path.dirname(d), exist_ok=True)
    jj("workspace", "add", "--name", name, "-r", commits[0], d, cwd=home)
    print(d)


def cmd_cd(a):
    if not a.name:
        print(os.path.join(ROOT, pick(workspaces())))
        return
    try:
        _, home = locate()
        d = home if a.name == "default" else f"{home}.agents/{a.name}"
        if os.path.isdir(d):
            print(d)
            return
    except Fail:
        pass  # not in a repo
    print(os.path.join(ROOT, pick(workspaces(), a.name)))


def cmd_clone(a):
    name = a.name or re.split(r"[/:]", a.url.rstrip("/"))[-1].removesuffix(".git")
    if not NAME.match(name) or name.endswith(".agents"):
        raise Fail(f"invalid name {name!r}")
    d = f"{ROOT}/{name}"
    if os.path.lexists(d):
        raise Fail(f"{d} already exists")
    os.makedirs(ROOT, exist_ok=True)
    jj("git", "clone", "--colocate", a.url, d)
    print(d)


def untracked(d):
    """Files in d that jj does not track (ignored or too large): they die with the directory."""
    on_disk = set()
    for path, dirs, files in os.walk(d):
        if ".jj" in dirs:
            dirs.remove(".jj")
        if path == d:  # jj may put a .git file in the workspaces of colocated repos
            dirs[:] = [x for x in dirs if x != ".git"]
            files = [x for x in files if x != ".git"]
        links = [x for x in dirs if os.path.islink(f"{path}/{x}")]  # jj tracks a symlink as one file
        dirs[:] = [x for x in dirs if x not in links]
        on_disk.update(os.path.relpath(f"{path}/{x}", d) for x in files + links)
    return sorted(on_disk - set(jj("--ignore-working-copy", "file", "list", cwd=d).splitlines()))


def remove(home, name):
    d = f"{home}.agents/{name}"
    jj("status", cwd=d)  # snapshot: its work stays in its change after the workspace is gone
    lost = untracked(d)
    if lost:
        more = f", ... (+{len(lost) - 5} more)" if len(lost) > 5 else ""
        sys.stderr.write(f"jw: {len(lost)} file(s) in {d} are not tracked by jj (ignored or too large) "
                         f"and will be lost: {', '.join(lost[:5])}{more}. Delete? [y/N] ")
        try:
            with open("/dev/tty") as tty:  # stdout is captured by the fish function
                answer = tty.readline()
        except OSError:
            raise Fail("nothing removed (no terminal to confirm)")
        if answer.strip().lower() != "y":
            raise Fail("nothing removed")
    jj("--ignore-working-copy", "workspace", "forget", name, cwd=home)
    shutil.rmtree(d)
    try:
        os.rmdir(f"{home}.agents")
    except OSError:
        pass


def cmd_rm(a):
    root, home = locate()
    name = a.name or (os.path.basename(root) if root != home else None)
    if not name:
        raise Fail("give a workspace name (this is the main one)")
    d = f"{home}.agents/{name}"
    if name == "default" or not NAME.match(name) or not os.path.isdir(f"{d}/.jj"):
        raise Fail(f"no workspace at {d}")
    inside = (os.path.realpath(os.getcwd()) + "/").startswith(os.path.realpath(d) + "/")
    remove(home, name)
    if inside:
        print(home)


def cmd_prune(a):
    """Remove the workspaces that hold nothing: empty, undescribed, a visible head, not in use."""
    for r in repos():
        home = f"{ROOT}/{r}"
        try:
            names = sorted(os.listdir(f"{home}.agents"))
        except OSError:
            continue
        for name in names:
            d = f"{home}.agents/{name}"
            if not name.startswith("w-") or not os.path.isdir(f"{d}/.jj") or in_use(d):
                continue
            try:
                # not --ignore-working-copy: snapshot first, so unsnapshotted edits count
                empty = jj("log", "--no-graph", "-T", "change_id", "-r",
                           '@ & empty() & description(exact:"") & visible_heads()', cwd=d)
                if not empty.strip():
                    continue
                remove(home, name)
                sys.stderr.write(f"jw: removed {r}.agents/{name}\n")
            except Fail as e:
                sys.stderr.write(f"jw: kept {r}.agents/{name}" + (f": {e}" if str(e) else "") + "\n")


def main():
    p = argparse.ArgumentParser(prog="jw", description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd")
    s = sub.add_parser("new", aliases=["n"], help="create a workspace in a repo and go there")
    s.add_argument("repo", nargs="?", help="repo under ~/projects (default: the current one)")
    s.add_argument("-r", "--revision", default="trunk()", help="start from (default: trunk())")
    s.set_defaults(func=cmd_new)
    s = sub.add_parser("cd", aliases=["c"], help="go to a workspace (default: pick one)")
    s.add_argument("name", nargs="?")
    s.set_defaults(func=cmd_cd)
    s = sub.add_parser("rm", help="forget a workspace and delete its directory (its work stays)")
    s.add_argument("name", nargs="?")
    s.set_defaults(func=cmd_rm)
    s = sub.add_parser("clone", help="clone a repo into ~/projects and go there")
    s.add_argument("url")
    s.add_argument("name", nargs="?", help="directory name under ~/projects (default: from the url)")
    s.set_defaults(func=cmd_clone)
    s = sub.add_parser("prune", help="remove empty workspaces in all repos")
    s.set_defaults(func=cmd_prune)
    sub.add_parser("ls", help="list the workspaces")
    a = p.parse_args()
    try:
        if not hasattr(a, "func"):
            sys.stdout.write(jj("--ignore-working-copy", "workspace", "list"))
            return 0
        a.func(a)
    except Fail as e:
        if str(e):
            print(f"jw: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
