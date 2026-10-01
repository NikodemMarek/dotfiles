---
name: stack
description: Split a large git change into small, atomic, stacked commits and optionally stacked MRs. Use when the user asks to "stack", "split", or "break up" their changes into incremental pieces.
disable-model-invocation: true
allowed-tools: Bash(git *) Bash(glab *) mcp__glab__glab_stack_save mcp__glab__glab_stack_sync mcp__glab__glab_stack_amend mcp__glab__glab_stack_move mcp__glab__glab_stack_list mcp__glab__glab_stack_first mcp__glab__glab_stack_last mcp__glab__glab_stack_next mcp__glab__glab_stack_prev
---

# Stacked Diffs Skill

Split a large git change into a series of small, atomic, stacked commits (and optionally MRs) that build on each other. Each layer must compile, pass tests, and not break the system when merged in order.

## When to Use

- User has a big diff (staged, unstaged, or already committed) and wants it broken into incremental pieces.
- User explicitly asks to "stack", "split", or "break up" their changes.

## Steps

1. **Understand the full change**
   - Run `git diff` / `git diff --cached` / `git log origin/HEAD..HEAD --stat -p` (depending on where the changes live) to get the complete picture.
   - Run `git status` to see untracked files.
   - Identify the base branch (`origin/HEAD` or ask the user).

2. **Analyze and plan the split**
   - Group changes by logical concern: new types/interfaces, data layer, business logic, UI, tests, config, migrations, etc.
   - Order the groups so each layer only depends on layers below it (dependency-first ordering).
   - Rules for ordering:
     - Shared types, interfaces, and utilities come first.
     - Data / storage layer before business logic.
     - Business logic before presentation / API surface.
     - Tests for each layer belong with that layer's commit.
     - Breaking changes (API removals, renames, migration-only steps) go last.
   - Each slice must:
     - Be independently compilable / buildable.
     - Pass its own tests (and not break existing tests).
     - Be reviewable in isolation — a reviewer should understand the slice without seeing the rest.
   - Only the **final** slice is allowed to introduce a breaking change (if unavoidable).

3. **Present the plan to the user**
   - Show a numbered list of proposed commits with:
     - A short title (conventional commit format).
     - 1-2 sentence summary of what goes in.
     - List of files/hunks included.
   - Ask the user to approve, reorder, merge, or further split slices before proceeding.

4. **Execute the split**
   - For each slice, in order:
     a. Stage only the relevant files/hunks (`git add -p` or explicit file paths — never `git add -A`).
     b. If the project has a build step, run it to confirm the slice compiles.
     c. If the project has tests, run them to confirm nothing is broken.
     d. Commit using Conventional Commits format via HEREDOC.
   - If a build or test fails mid-stack, stop and report — ask the user how to proceed (fix in current slice, move code to an earlier slice, etc.).

5. **Optional: create stacked MRs**
   - If the user asks for stacked MRs (not just commits), prefer using `glab stack` commands (GitLab CLI) when available:
     - **`glab stack save`** — stages changes, creates a commit with a descriptive message, and auto-generates a branch for each slice. Use this when adding new logical slices to the stack.
     - **`glab stack sync`** — pushes all branches, creates MRs for new slices, and chains each MR to target the previous slice's branch (first MR targets the base branch). Run once after all slices are committed.
     - **`glab stack amend`** — use when responding to review feedback or fixing the current slice without creating a new one. Amends in-place and keeps the stack intact.
     - **`glab stack move`** — navigate to a specific point in the stack to insert or fix a slice mid-stack.
     - After `glab stack sync`, GitLab automatically rebases downstream MRs when an upstream slice is updated.
   - If `glab` is not available, fall back to manual branching:
     - Create a branch per slice, each branching off the previous one.
     - Branch naming: `stack/<base>/<N>-<short-slug>` (e.g. `stack/main/1-add-types`, `stack/main/2-data-layer`).
     - Push each branch and create an MR targeting the previous branch (first MR targets the base branch).
     - In each MR description, note which slice it is (e.g. "Stack 2/5") and link to the previous/next MRs.
   - Merge MRs in order (bottom of the stack first) — each MR can be merged independently as it is approved.
   - If the user only wants commits (default), just keep them on the current branch.

6. **Final summary**
   - Show the list of created commits (and MRs if applicable) with their hashes/URLs.

## Rules

- Never stage files automatically without showing the plan first.
- Never skip hooks (`--no-verify`).
- Never amend commits unless explicitly asked.
- Never force-push without explicit user approval.
- If unsure whether a slice is self-contained, err on the side of including more context in that slice rather than less.
- Prefer many small slices over few large ones — but don't split so finely that individual slices are meaningless.
- Do not add co-author trailers.
- If the change is already committed as a single commit, use `git reset --soft` to uncommit (after confirming with user) and then re-split.
- Always confirm the plan before executing. The user must approve the split.
