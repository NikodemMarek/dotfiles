#!/usr/bin/env bash
# PostToolUse hook for the architect: auto-commit every change to the project memory repo.
set -uo pipefail
MEM="$HOME/projects/ai/projects"
input="$(cat)"
path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
cd "$MEM" || exit 0
git add -A >/dev/null 2>&1
git diff --cached --quiet && exit 0
rel="${path#"$MEM"/}"
git commit -q --no-verify -m "architect: update ${rel:-memory}" >/dev/null 2>&1 || true
exit 0
