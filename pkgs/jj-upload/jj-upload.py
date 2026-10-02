#!/usr/bin/env python3
"""jj upload — push a stack of jj changes as stacked merge/pull requests.

Works with any forge that has a backend below (GitLab via `glab`, GitHub via
`gh`); add one by subclassing Forge and registering it in FORGES.

Every change in the revset gets its own bookmark (= git branch) and its own MR.
Each MR targets the branch of its parent change, or the trunk branch for the
bottom of the stack.  Running it again force-pushes rewritten changes and syncs
MR title / description / target branch with the commits.  Changes you abandoned
or squashed away get their MR closed and their branch deleted.

Usage:  jj upload [-r REVSET]... [--draft] [--dry-run]

Config (all optional, set with `jj config set --user <key> <value>`):
  upload.remote          git remote to push to             (default: origin)
  upload.bookmark-prefix prefix of managed bookmarks       (default: <email user>/)
  upload.target-branch   branch the bottom MR targets      (default: trunk() bookmark)
  upload.forge           gitlab | github                   (default: from host, else gitlab)
  upload.host            forge host for API calls          (default: from remote URL)
  upload.project         group/project (owner/repo) path   (default: from remote URL)
  upload.draft           open new MRs as drafts            (default: false)

Env: JJ_UPLOAD_GLAB / JJ_UPLOAD_GH override the CLI binaries.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.parse

DEFAULT_REVSET = 'trunk()..(@::) ~ (empty() & description(exact:""))'
STACK_START = "<!-- jj-stack:start -->"
STACK_END = "<!-- jj-stack:end -->"
FS, RS = "\x1f", "\x1e"


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def info(msg):
    print(msg, file=sys.stderr)


def run(cmd, check=True):
    p = subprocess.run(cmd, capture_output=True, text=True)
    if check and p.returncode != 0:
        die(f"`{' '.join(cmd)}` failed:\n{p.stderr.strip()}")
    return p


def jj(*args, check=True):
    return run(["jj", "--no-pager", "--color=never", *args], check).stdout


def jj_config(key, default=None):
    p = run(["jj", "config", "get", key], check=False)
    return p.stdout.strip() if p.returncode == 0 else default


# ---------------------------------------------------------------- repo state

COMMIT_TEMPLATE = (
    'change_id ++ "\\x1f" ++ commit_id ++ "\\x1f"'
    ' ++ parents.map(|p| p.commit_id()).join(",") ++ "\\x1f"'
    ' ++ local_bookmarks.map(|b| b.name()).join(",") ++ "\\x1f"'
    ' ++ if(conflict, "1", "0") ++ "\\x1f"'
    ' ++ if(immutable, "1", "0") ++ "\\x1f"'
    ' ++ description ++ "\\x1e"'
)


def load_commits(revset):
    """Commits matching revset, parents before children."""
    out = jj("log", "--no-graph", "--reversed", "-r", revset, "-T", COMMIT_TEMPLATE)
    commits = []
    for rec in out.split(RS):
        if not rec.strip():
            continue
        change, commit, parents, bookmarks, conflict, immutable, desc = rec.lstrip("\n").split(FS)
        commits.append({
            "change": change,
            "commit": commit,
            "parents": [p for p in parents.split(",") if p],
            "bookmarks": [b for b in bookmarks.split(",") if b],
            "conflict": conflict == "1",
            "immutable": immutable == "1",
            "description": desc.strip(),
        })
    return commits


def trunk_branch(remote):
    configured = jj_config("upload.target-branch")
    if configured:
        return configured
    out = jj("log", "--no-graph", "-r", "trunk()", "-T",
             'remote_bookmarks.map(|b| b.name() ++ "@" ++ b.remote()).join("\\n")')
    for line in out.splitlines():
        name, _, rem = line.rpartition("@")
        if rem == remote:
            return name
    die(f"cannot find a {remote} bookmark on trunk(); set upload.target-branch")


def remote_branches(remote):
    out = jj("bookmark", "list", "--all-remotes", "-T",
             'if(remote, name ++ "@" ++ remote ++ "\\n")')
    return {l.rpartition("@")[0] for l in out.splitlines() if l.rpartition("@")[2] == remote}


def deleted_managed_bookmarks(prefix, remote):
    """Local bookmarks deleted (abandoned/squashed change) that still exist on the remote."""
    out = jj("bookmark", "list", "--all-remotes", "-T",
             'name ++ "\\x1f" ++ remote ++ "\\x1f" ++ if(present, "1", "0") ++ "\\n"')
    local_gone, on_remote = set(), set()
    for line in out.splitlines():
        name, rem, present = line.split(FS)
        if not name.startswith(prefix):
            continue
        if rem == "" and present == "0":
            local_gone.add(name)
        elif rem == remote and present == "1":
            on_remote.add(name)
    return sorted(local_gone & on_remote)


def parse_remote_url(url):
    """-> (host, project path) for ssh / scp-like / https remote URLs."""
    m = re.match(r"^(?:ssh|https?|git)://(?:[^@/]+@)?([^/:]+)(?::\d+)?/(.+?)(?:\.git)?/?$", url)
    if not m:
        m = re.match(r"^(?:[^@/]+@)?([^/:]+):(.+?)(?:\.git)?/?$", url)
    if not m:
        die(f"cannot parse remote URL {url!r}; set upload.host and upload.project")
    return m.group(1), m.group(2)


def forge_target(remote):
    # upload.gitlab-* are the old names of upload.host / upload.project
    host = jj_config("upload.host") or jj_config("upload.gitlab-host")
    project = jj_config("upload.project") or jj_config("upload.gitlab-project")
    if not (host and project):
        url = None
        for line in jj("git", "remote", "list").splitlines():
            name, _, u = line.partition(" ")
            if name == remote:
                url = u.strip()
        if not url:
            die(f"remote {remote!r} not found")
        h, p = parse_remote_url(url)
        host, project = host or h, project or p
    return host, project


# ---------------------------------------------------------------- naming

def slugify(text, limit=40):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s[:limit].rstrip("-") or "change"


def default_prefix():
    email = jj_config("user.email", "")
    user = re.sub(r"[^a-zA-Z0-9._-]", "", email.split("@")[0]) if email else ""
    return f"{user or 'jj'}/"


def choose_bookmark(c, prefix):
    """-> (bookmark to use, managed bookmarks to drop from this commit)."""
    managed = [b for b in c["bookmarks"] if b.startswith(prefix)]
    own = [b for b in managed if c["change"].startswith(b.rsplit("-", 1)[-1])]
    if own:
        keep = own[0]
    elif managed:
        keep = managed[0]
    elif c["bookmarks"]:
        return c["bookmarks"][0], []  # a bookmark you named yourself
    else:
        title = c["description"].splitlines()[0]
        return f"{prefix}{slugify(title)}-{c['change'][:8]}", []
    # Extra managed bookmarks here come from `jj squash` moving them onto this
    # commit: the change they belonged to is gone, so its MR should go too.
    return keep, [b for b in managed if b != keep]


# ---------------------------------------------------------------- forges
#
# A backend turns forge API objects into plain dicts:
#   {"id", "ref" (e.g. "!12" / "#12"), "url", "state": open|closed|merged,
#    "draft": bool, "title" (without draft marker), "target", "description"}

class Forge:
    name = "?"
    term = "MR"  # what the forge calls a merge request

    def __init__(self, host, project):
        self.host, self.project = host, project

    def find(self, branch):
        """Newest MR whose source branch is `branch`, or None."""
        raise NotImplementedError

    def create(self, source, target, title, description, draft):
        raise NotImplementedError

    def update(self, mr, title=None, target=None, description=None):
        """Change the given fields; keeps the MR's draft state. Returns the new MR."""
        raise NotImplementedError

    def set_state(self, mr, state):
        """state: "open" (reopen) or "closed"."""
        raise NotImplementedError


def cli_api(cmd):
    out = run(cmd).stdout
    return json.loads(out) if out.strip() else None


class GitLab(Forge):
    name = "gitlab"
    DRAFT = re.compile(r"^\s*(?:\[draft\]|\(draft\)|draft:)\s*", re.I)

    def __init__(self, host, project):
        super().__init__(host, project)
        self.base = f"projects/{urllib.parse.quote(project, safe='')}/merge_requests"
        self.bin = os.environ.get("JJ_UPLOAD_GLAB", "glab")

    def api(self, method, path, **fields):
        cmd = [self.bin, "api", "--hostname", self.host, "-X", method, path]
        for k, v in fields.items():
            cmd += ["-f", f"{k}={v}"]
        return self.norm(cli_api(cmd))

    def norm(self, mr):
        if not isinstance(mr, dict):
            return mr
        draft = bool(mr.get("draft") or mr.get("work_in_progress"))
        return {"id": mr["iid"], "ref": f"!{mr['iid']}", "url": mr["web_url"],
                "state": {"opened": "open"}.get(mr["state"], mr["state"]), "draft": draft,
                "title": self.DRAFT.sub("", mr["title"]) if draft else mr["title"],
                "target": mr["target_branch"],
                "description": mr.get("description") or ""}

    def find(self, branch):
        q = urllib.parse.urlencode({"source_branch": branch, "order_by": "created_at", "sort": "desc"})
        cmd = [self.bin, "api", "--hostname", self.host, f"{self.base}?{q}"]
        mrs = cli_api(cmd)
        return self.norm(mrs[0]) if mrs else None

    def create(self, source, target, title, description, draft):
        return self.api("POST", self.base, source_branch=source, target_branch=target,
                        title=f"Draft: {title}" if draft else title,
                        description=description, remove_source_branch="true")

    def update(self, mr, title=None, target=None, description=None):
        fields = {}
        if title is not None:
            fields["title"] = f"Draft: {title}" if mr["draft"] else title
        if target is not None:
            fields["target_branch"] = target
        if description is not None:
            fields["description"] = description
        return self.api("PUT", f"{self.base}/{mr['id']}", **fields) if fields else mr

    def set_state(self, mr, state):
        event = {"open": "reopen", "closed": "close"}[state]
        return self.api("PUT", f"{self.base}/{mr['id']}", state_event=event)


class GitHub(Forge):
    name = "github"
    term = "PR"

    def __init__(self, host, project):
        super().__init__(host, project)
        self.base = f"repos/{project}/pulls"
        self.owner = project.split("/")[0]
        self.bin = os.environ.get("JJ_UPLOAD_GH", "gh")

    def api(self, method, path, **fields):
        cmd = [self.bin, "api", "--hostname", self.host, "-X", method, path]
        for k, v in fields.items():
            # -F sends booleans as JSON; -f always sends strings
            cmd += ["-F", f"{k}={str(v).lower()}"] if isinstance(v, bool) else ["-f", f"{k}={v}"]
        return self.norm(cli_api(cmd))

    def norm(self, pr):
        if not isinstance(pr, dict):
            return pr
        state = "merged" if pr.get("merged_at") else pr["state"]  # open | closed
        return {"id": pr["number"], "ref": f"#{pr['number']}", "url": pr["html_url"],
                "state": state, "draft": bool(pr.get("draft")), "title": pr["title"],
                "target": pr["base"]["ref"], "description": pr.get("body") or ""}

    def find(self, branch):
        q = urllib.parse.urlencode({"head": f"{self.owner}:{branch}", "state": "all",
                                    "sort": "created", "direction": "desc"})
        prs = cli_api([self.bin, "api", "--hostname", self.host, f"{self.base}?{q}"])
        return self.norm(prs[0]) if prs else None

    def create(self, source, target, title, description, draft):
        return self.api("POST", self.base, head=source, base=target, title=title,
                        body=description, draft=bool(draft))

    def update(self, mr, title=None, target=None, description=None):
        fields = {k: v for k, v in (("title", title), ("base", target), ("body", description))
                  if v is not None}
        return self.api("PATCH", f"{self.base}/{mr['id']}", **fields) if fields else mr

    def set_state(self, mr, state):
        if state == "open":
            # GitHub can't reopen a PR whose branch was force-pushed/recreated while
            # closed (which `jj upload` itself does); returning None makes main create a new PR
            p = run([self.bin, "api", "--hostname", self.host, "-X", "PATCH",
                     f"{self.base}/{mr['id']}", "-f", "state=open"], check=False)
            if p.returncode != 0:
                info(f"  cannot reopen {mr['ref']}; opening a new PR")
                return None
            return self.norm(json.loads(p.stdout))
        return self.api("PATCH", f"{self.base}/{mr['id']}", state=state)


FORGES = {f.name: f for f in (GitLab, GitHub)}


def make_forge(remote):
    host, project = forge_target(remote)
    kind = jj_config("upload.forge")
    if not kind and (jj_config("upload.gitlab-host") or jj_config("upload.gitlab-project")):
        kind = "gitlab"
    if not kind:
        # unrecognised hosts default to gitlab, like before forges were pluggable
        kind = next((n for n in FORGES if n in host.lower()), "gitlab")
    if kind not in FORGES:
        die(f"unknown upload.forge {kind!r}; known: {', '.join(FORGES)}")
    return FORGES[kind](host, project)


def stack_section(entries, current, term):
    lines = [STACK_START, "", "**Stack**:", ""]
    for e in entries:
        mark = f" 👈 this {term}" if e["branch"] == current else ""
        lines.append(f"- {e['mr']['ref']}{mark}")
    lines += ["", STACK_END]
    return "\n".join(lines)


def strip_stack(text):
    return re.sub(rf"\n*{re.escape(STACK_START)}.*?{re.escape(STACK_END)}\n*", "", text or "", flags=re.S).strip()


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(prog="jj upload", description=__doc__.split("\n\n")[1],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-r", "--revisions", action="append",
                    help=f"changes to upload (default: {DEFAULT_REVSET})")
    ap.add_argument("--draft", action="store_true", default=None, help="open new MRs as drafts")
    ap.add_argument("-n", "--dry-run", action="store_true", help="only print what would happen")
    args = ap.parse_args()

    remote = jj_config("upload.remote") or "origin"
    prefix = jj_config("upload.bookmark-prefix") or default_prefix()
    draft = args.draft if args.draft is not None else jj_config("upload.draft") == "true"
    revset = " | ".join(f"({r})" for r in args.revisions) if args.revisions else DEFAULT_REVSET

    commits = load_commits(revset)
    if not commits:
        die(f"revset {revset!r} is empty")
    for c in commits:
        short = c["change"][:8]
        if c["immutable"]:
            die(f"{short} is immutable (already in trunk?)")
        if c["conflict"]:
            die(f"{short} has conflicts; resolve them first")
        if not c["description"]:
            die(f"{short} has no description; `jj describe {short}` first")
        if len(c["parents"]) != 1:
            die(f"{short} is a merge commit; stacked MRs need a linear history")

    trunk = trunk_branch(remote)
    selected = {c["commit"]: c for c in commits}
    outside = [p for c in commits for p in c["parents"] if p not in selected]
    in_trunk = set()
    outside_bookmarks = {}
    if outside:
        ids = " | ".join(outside)
        in_trunk = set(jj("log", "--no-graph", "-r", f"({ids}) & ::trunk()",
                          "-T", 'commit_id ++ "\\n"').split())
        for c in load_commits(f"({ids}) ~ ::trunk()"):
            outside_bookmarks[c["commit"]] = c["bookmarks"]
    pushed = remote_branches(remote)

    # 1. decide bookmarks and MR targets
    plan, to_delete = [], []
    for c in commits:
        branch, extra = choose_bookmark(c, prefix)
        c["branch"] = branch
        to_delete += extra
        parent = c["parents"][0]
        if parent in selected:
            target = selected[parent]["branch"]
        elif parent in in_trunk:
            target = trunk
        else:
            candidates = [b for b in outside_bookmarks.get(parent, []) if b in pushed]
            if not candidates:
                die(f"parent of {c['change'][:8]} is neither uploaded nor in trunk; "
                    f"include it, e.g. -r 'trunk()..{c['change'][:8]}'")
            target = candidates[0]
        lines = c["description"].splitlines()
        plan.append({**c, "target": target, "title": lines[0].strip(),
                     "body": "\n".join(lines[1:]).strip()})

    info(f"Uploading {len(plan)} change(s) to {remote}, bottom MR targets {trunk}:")
    for e in plan:
        info(f"  {e['change'][:8]}  {e['branch']}  ->  {e['target']}   {e['title']}")

    fg = make_forge(remote)
    t = fg.term
    stale = sorted(set(to_delete) | set(deleted_managed_bookmarks(prefix, remote)))
    if stale:
        info(f"Closing {t}s / deleting branches of dropped changes: " + ", ".join(stale))
    if args.dry_run:
        return

    # 2. point bookmarks at the commits and push them
    for e in plan:
        if e["branch"] not in e["bookmarks"]:
            jj("bookmark", "set", e["branch"], "-r", e["commit"], "--allow-backwards")
    if to_delete:
        jj("bookmark", "delete", *[f"exact:{b}" for b in to_delete])
    push = ["git", "push", "--remote", remote]
    for e in plan:
        push += ["-b", f"exact:{e['branch']}"]
    p = run(["jj", "--no-pager", *push], check=False)
    sys.stderr.write(p.stderr)
    if p.returncode != 0:
        die("push failed")

    # 3. create / update MRs (parents first, so each target branch exists)
    for e in plan:
        mr = fg.find(e["branch"])
        if mr and mr["state"] == "merged":
            info(f"  {mr['ref']} {e['branch']} is already merged; run `jj sync` to drop it")
            e["mr"] = mr
            continue
        if mr and mr["state"] == "closed":
            mr = fg.set_state(mr, "open")
        if not mr:
            mr = fg.create(e["branch"], e["target"], e["title"], e["body"], draft)
            info(f"  created {mr['ref']}  {mr['url']}")
        else:
            # the draft state chosen in the forge is kept
            mr = fg.update(mr, title=e["title"] if mr["title"] != e["title"] else None,
                           target=e["target"] if mr["target"] != e["target"] else None)
            info(f"  updated {mr['ref']}  {mr['url']}")
        e["mr"] = mr

    # 4. stack overview in every MR description
    if len(plan) > 1:
        for e in plan:
            if e["mr"]["state"] == "merged":
                continue
            desc = (e["body"] + "\n\n" + stack_section(plan, e["branch"], t)).strip()
            if e["mr"]["description"].strip() != desc:
                fg.update(e["mr"], description=desc)
    else:
        e = plan[0]
        if e["mr"]["state"] != "merged" and strip_stack(e["mr"]["description"]) != e["body"]:
            fg.update(e["mr"], description=e["body"])

    # 5. dropped changes: close MR, then delete branch (after children were retargeted)
    if stale:
        for b in stale:
            mr = fg.find(b)
            if mr and mr["state"] == "open":
                fg.set_state(mr, "closed")
                info(f"  closed {mr['ref']} ({b})")
        cmd = ["jj", "--no-pager", "git", "push", "--remote", remote]
        for b in stale:
            cmd += ["-b", f"exact:{b}"]
        p = run(cmd, check=False)
        sys.stderr.write(p.stderr)


if __name__ == "__main__":
    main()
