#!/usr/bin/env python3
"""jw: quick jj workspaces at <repo>.agents/<name> (the layout the claude wrapper uses too).

new, cd and rm print the directory to go to on stdout; the `jw` fish function cds there.
Everything else goes to stderr.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import time

NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")


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


def cmd_new(a):
    _, home = locate()
    name = a.name or time.strftime("w-%m%d-%H%M%S")
    if not NAME.match(name):
        raise Fail(f"invalid name {name!r}")
    # resolve first: `workspace add` leaves its directory behind on a bad revision
    commits = jj("--ignore-working-copy", "log", "--no-graph", "-r", a.revision,
                 "-T", 'commit_id ++ "\\n"').split()
    if len(commits) != 1:
        raise Fail(f"{a.revision!r} must be exactly one commit, not {len(commits)}")
    d = f"{home}.agents/{name}"
    os.makedirs(os.path.dirname(d), exist_ok=True)
    jj("workspace", "add", "--name", name, "-r", commits[0], d)
    print(d)


def cmd_cd(a):
    _, home = locate()
    d = f"{home}.agents/{a.name}" if a.name else home
    if not os.path.isdir(d):
        raise Fail(f"no workspace at {d}")
    print(d)


def untracked(d):
    """Files in d that jj does not track (ignored or too large): they die with the directory."""
    on_disk = 0
    for _, dirs, files in os.walk(d):
        if ".jj" in dirs:
            dirs.remove(".jj")
        on_disk += len(files)
    return on_disk - len(jj("--ignore-working-copy", "file", "list", cwd=d).splitlines())


def cmd_rm(a):
    root, home = locate()
    name = a.name or (os.path.basename(root) if root != home else None)
    if not name:
        raise Fail("give a workspace name (this is the main one)")
    d = f"{home}.agents/{name}"
    if name == "default" or not NAME.match(name) or not os.path.isdir(f"{d}/.jj"):
        raise Fail(f"no workspace at {d}")
    jj("status", cwd=d)  # snapshot: its work stays in its change after the workspace is gone
    n = untracked(d)
    if n > 0:
        sys.stderr.write(f"jw: {n} file(s) in {d} are not tracked by jj (ignored or too large) "
                         "and will be lost. Delete? [y/N] ")
        with open("/dev/tty") as tty:  # stdout is captured by the fish function
            answer = tty.readline()
        if answer.strip().lower() != "y":
            raise Fail("nothing removed")
    inside = (os.path.realpath(os.getcwd()) + "/").startswith(os.path.realpath(d) + "/")
    jj("--ignore-working-copy", "workspace", "forget", name, cwd=home)
    shutil.rmtree(d)
    try:
        os.rmdir(f"{home}.agents")
    except OSError:
        pass
    if inside:
        print(home)


def main():
    p = argparse.ArgumentParser(prog="jw", description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd")
    s = sub.add_parser("new", help="create a workspace and go there")
    s.add_argument("name", nargs="?")
    s.add_argument("-r", "--revision", default="trunk()", help="start from (default: trunk())")
    s = sub.add_parser("cd", help="go to a workspace (default: the main one)")
    s.add_argument("name", nargs="?")
    s = sub.add_parser("rm", help="forget a workspace and delete its directory (its work stays)")
    s.add_argument("name", nargs="?")
    sub.add_parser("ls", help="list the workspaces")
    a = p.parse_args()
    try:
        if a.cmd in (None, "ls"):
            sys.stdout.write(jj("--ignore-working-copy", "workspace", "list"))
            return 0
        {"new": cmd_new, "cd": cmd_cd, "rm": cmd_rm}[a.cmd](a)
    except Fail as e:
        if str(e):
            print(f"jw: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
