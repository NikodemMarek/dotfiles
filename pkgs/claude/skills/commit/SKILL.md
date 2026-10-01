---
name: commit
description: Stage and commit the current changes using Conventional Commits format. Use when the user asks to commit, create a commit, or write a commit message. Prefers git MCP tools when available.
disable-model-invocation: true
allowed-tools: Bash(git diff*) Bash(git log*) Bash(git status*) Bash(git commit*) Bash(git push*) mcp__git__git_diff_staged mcp__git__git_status mcp__git__git_commit mcp__git__git_push
---

# Commit Skill

Generate conventional commit messages from staged git changes and create the commit(s).

## Tool preference

Prefer git MCP tools (e.g. `mcp__git__*`) over Bash `git` commands whenever they are available in the session. Fall back to Bash only if the git MCP server is not connected.

## Steps

1. Get staged changes and working-tree status — use `mcp__git__git_diff_staged` and `mcp__git__git_status` if available, otherwise `git diff --cached` and `git status`.
2. If nothing is staged, say so and stop — never stage files automatically.
3. Analyze the staged changes:
   - If the changes span multiple unrelated concerns, propose splitting them into separate commits and ask the user to confirm before proceeding.
   - Otherwise, draft a single commit message.
4. Follow Conventional Commits format:
   - `<type>(<optional scope>): <short description>`
   - Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`, `ci`, `build`
   - Subject line: short, descriptive, under 72 characters, imperative mood
   - Add a body only when the change genuinely needs more explanation
5. Show the proposed message(s) to the user and ask for approval or edits.
6. Once approved, create the commit — use `mcp__git__git_commit` if available, otherwise `git commit` via Bash with a HEREDOC for correct formatting.
7. Push to remote immediately — use `mcp__git__git_push` if available, otherwise Bash `git push`.

## Rules

- Never use `git add -A` or `git add .`
- Never skip hooks (`--no-verify`)
- Never amend unless explicitly asked
- Do not add co-author trailers
