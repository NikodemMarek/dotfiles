#!/usr/bin/env bash
# Install the config in ./claude into the Claude config dir (default ~/.claude).
# Idempotent: re-run after changing the repo or an extension.
#
# - Files/dirs are symlinked into the config dir. Existing real files in the way
#   are moved to $CLAUDE_DIR/backups/install-<timestamp>/ first.
# - MERGE_DIRS (skills, agents) get per-entry links, so local extensions can keep
#   their own real entries next to them (e.g. ~/.claude/skills/<ext-skill>/).
# - settings.json is generated: repo settings.json deep-merged with
#   $CLAUDE_DIR/settings.d/*.json (local extensions; arrays are concatenated).
#   If it was changed since the last install (e.g. by /config), the edited copy
#   is backed up and a warning shown — port those changes to the repo or settings.d.
#
# Usage: ./install.sh [-n|--dry-run]
#   CLAUDE_DIR=/some/dir ./install.sh   # target another config dir
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/claude"
DEST="${CLAUDE_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
BACKUP="$DEST/backups/install-$(date +%Y%m%d-%H%M%S)"
MERGE_DIRS=(skills agents)
GENERATED=(settings.json)
STAMP="$DEST/.settings.json.installed.sha256"

DRY=0
case "${1:-}" in -n|--dry-run) DRY=1 ;; "") ;; *) echo "usage: $0 [-n|--dry-run]" >&2; exit 2 ;; esac
run() { if [ "$DRY" = 1 ]; then echo "  would: $*"; else "$@"; fi; }
rel() { echo "${1#"$DEST"/}"; }
in_list() { local x="$1"; shift; local i; for i in "$@"; do [ "$x" = "$i" ] && return 0; done; return 1; }

backup() { # backup <target path>
  local bak="$BACKUP/$(rel "$1")"
  echo "backup   $(rel "$1") -> $(rel "$bak")"
  run mkdir -p -- "$(dirname -- "$bak")"
  run mv -- "$1" "$bak"
}

link() { # link <repo path> <target path>
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$src" ]; then echo "ok       $(rel "$dst")"; return; fi
  if [ -L "$dst" ] && [[ "$(readlink -- "$dst")" == "$SRC"/* ]]; then run rm -- "$dst"
  elif [ -e "$dst" ] || [ -L "$dst" ]; then backup "$dst"; fi
  echo "link     $(rel "$dst") -> $src"
  run mkdir -p -- "$(dirname -- "$dst")"
  run ln -s -- "$src" "$dst"
}

real_dir() { # real_dir <target dir>: replace a symlinked dir with a real one
  local d="$1"
  if [ -L "$d" ]; then
    if [[ "$(readlink -- "$d")" == "$SRC"/* ]]; then run rm -- "$d"; else backup "$d"; fi
  fi
  run mkdir -p -- "$d"
}

gen_settings() {
  local dst="$DEST/settings.json" tmp
  local parts=("$SRC/settings.json")
  local ext; for ext in "$DEST"/settings.d/*.json; do parts+=("$ext"); echo "merge    $(rel "$ext")"; done
  tmp="$(mktemp)"
  # deep merge: objects recurse, arrays concatenate (deduped), scalars: later wins
  jq -s 'def m($a; $b): if ($a|type)=="object" and ($b|type)=="object"
            then reduce ($b|keys_unsorted[]) as $k ($a; .[$k] = m($a[$k]; $b[$k]))
          elif ($a|type)=="array" and ($b|type)=="array" then reduce $b[] as $x ($a; if index([$x]) then . else . + [$x] end)
          elif $b == null then $a else $b end;
        reduce .[1:][] as $x (.[0]; m(.; $x))' "${parts[@]}" > "$tmp"
  if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$tmp" "$dst"; then echo "ok       settings.json (generated)"; rm -f "$tmp"; return; fi
  if [ -L "$dst" ] && [[ "$(readlink -- "$dst")" == "$SRC"/* ]]; then run rm -- "$dst"
  elif [ -f "$STAMP" ] && (cd "$DEST" && sha256sum --status -c "$STAMP") 2>/dev/null; then :  # untouched since last install
  elif [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "WARNING  settings.json was edited outside install.sh; port the changes to the repo or settings.d/" >&2
    backup "$dst"
  fi
  echo "generate settings.json"
  if [ "$DRY" = 1 ]; then echo "  would: write $dst"; rm -f "$tmp"; return; fi
  mv -- "$tmp" "$dst"; chmod 644 "$dst"
  (cd "$DEST" && sha256sum settings.json) > "$STAMP"
}

shopt -s nullglob dotglob
for entry in "$SRC"/*; do
  name="$(basename -- "$entry")"
  if in_list "$name" "${GENERATED[@]}"; then continue
  elif [ -d "$entry" ] && in_list "$name" "${MERGE_DIRS[@]}"; then
    real_dir "$DEST/$name"
    for child in "$entry"/*; do link "$child" "$DEST/$name/$(basename -- "$child")"; done
  else
    link "$entry" "$DEST/$name"
  fi
done
gen_settings

# Remove dangling links left behind by files removed from the repo
dirs=("$DEST"); for d in "${MERGE_DIRS[@]}"; do dirs+=("$DEST/$d"); done
for d in "${dirs[@]}"; do
  for l in "$d"/*; do
    if [ -L "$l" ] && [ ! -e "$l" ] && [[ "$(readlink -- "$l")" == "$SRC"/* ]]; then
      echo "dangling $(rel "$l") (removed from repo)"; run rm -- "$l"
    fi
  done
done
