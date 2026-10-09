# claude config

Nix flake that builds a wrapped `claude` (Claude Code) with the whole config bundled in the Nix store: `CLAUDE.md`, agents, skills, settings, hook scripts and the statusline.

```sh
nix run .#claude                                  # try it
```

Packages: `claude`, `claude-hooks`, `claude-statusline`, `jj-upload`, `agent-skills`, `knowledge`.

## Installing

Add this repo as an input of your system / home-manager flake and use the overlay, rather than `nix profile install`:

```nix
{
  inputs.ai.url = "github:NikodemMarek/ai";

  outputs = { nixpkgs, home-manager, ai, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ ai.overlays.default ];
        config.allowUnfreePredicate = p: builtins.elem (nixpkgs.lib.getName p) [ "claude-code" "claude" ];
      };
      modules = [ ({ pkgs, ... }: { home.packages = [ pkgs.claude pkgs.jj-upload ]; }) ];
    };
  };
}
```

(On NixOS the same goes into `nixpkgs.overlays` + `environment.systemPackages`.) After changing this repo, `nix flake update ai` in that flake and rebuild.

## Layout

- `skills/` - `*/SKILL.md`, tool-agnostic skills shared by Claude and other tools
- `claude/` - `CLAUDE.md`, `agents/*.md`, `settings.nix` (rendered to `settings.json`), `permissions.nix` (imported by `settings.nix`)
- `pkgs/` - `claude` (the wrapper), `claude-hooks`, `claude-statusline`, `jj-upload`, `agent-skills`, `knowledge` (the knowledge curator CLI: `knowledge submit`, `curate`, `undo`/`restore`/`drop`, hooks)
- `nix/overlay.nix` - overlay exposing all of the above

`@memoryDir@` and `@dataDir@` in the markdown files and the settings are substituted at build time.

## Settings

`claude/settings.nix` (hooks, statusLine, plugins, marketplaces, `effortLevel`, `theme`, ...; `permissions` live in `claude/permissions.nix`) is rendered to JSON in the store and `$CLAUDE_CONFIG_DIR/settings.json` is a **read-only** symlink to it.

- In-session changes (`/theme`, `/config`, `/plugin`, "don't ask again" permission answers) apply only to the current session and are not persisted.
- To persist a change, edit `claude/settings.nix` (or `claude/permissions.nix`), or use `extend { settings = ...; }` in an overlay / separate flake (see below).
- Project `.claude/settings.json` and `.claude/settings.local.json` work as usual.
- An existing real `settings.json` (or a symlink not managed by Nix) is moved to `$CLAUDE_CONFIG_DIR/backups/settings.json.<YYYYmmdd-HHMMSS>` on first launch (a one-line notice is printed) and replaced by the link.

## Other tools

`agent-skills` holds the shared skills (`skills/`) in the Agent Skills `SKILL.md` format: `$out/<name>/SKILL.md`. Link its entries into the skills directory of OpenCode (`~/.config/opencode/skills/`) or Antigravity, e.g. with home-manager:

```nix
xdg.configFile."opencode/skills".source = "${pkgs.agent-skills}";
```

Claude-only frontmatter (`allowed-tools`, and `disable-model-invocation` in `commit`) is ignored by other tools. `skills/knowledge` ships with a literal `@memoryDir@` in `agent-skills` (only the `claude` build substitutes it).

## Data dir

On launch the wrapper uses `CLAUDE_CONFIG_DIR` (default: the package's `dataDir`, `$HOME/.local/share/claude`) and sets `CLAUDE_MEMORY_DIR=$CLAUDE_CONFIG_DIR/memory` (always; the agents' prose has that path baked in). The memory dir is `git init`ed if it is not a repo yet.

```
~/.local/share/claude/
  CLAUDE.md          -> /nix/store/...-claude-config/CLAUDE.md
  agents/<name>.md   -> /nix/store/...-claude-config/agents/<name>.md
  skills/<name>      -> /nix/store/...-claude-config/skills/<name>
  settings.json      -> /nix/store/...-claude-config/settings.json (read-only)
  backups/           unmanaged settings.json files moved aside on launch
  memory/            project memory (a git repo, not managed by Nix), shared: the architect owns
                     projects/<slug>/{overview,decisions,log}.md and notes/, the knowledge curator the rest
  ...                sessions, credentials, etc. (claude's own state)
~/.local/state/knowledge/   the curator's state (inbox of pending submissions, decisions, rejected.md)
```

Managed entries are symlinks refreshed on every launch; stale ones from older builds are pruned. Real files or foreign symlinks are never overwritten (a warning is printed), except `settings.json`, which is moved to `backups/` first.

`dataDir` is shell-expanded at runtime and should start with `$HOME` (the markdown prose shows it as `~/...`). Variants (e.g. different `extend` results) sharing one `dataDir` re-link each other's entries on every launch; give a variant its own `dataDir` to run them side by side.

## Migrating from ~/.claude

1. Quit all running claude sessions.
2. `mv ~/.claude ~/.local/share/claude`
3. `mv ~/.claude.json ~/.local/share/claude/.claude.json`
4. Remove the old symlinks into this repo (e.g. `CLAUDE.md`, `agents/*`, `skills/*`, `settings.json`, hook scripts under `~/.local/share/claude`).
5. The old memory repo must become the memory dir itself, not a subdirectory of it. Before the first launch: `mv ~/projects/ai/projects ~/.local/share/claude/memory`. If the wrapper already created `memory/`: `rm -rf ~/.local/share/claude/memory/.git && mv ~/projects/ai/projects/* ~/projects/ai/projects/.git ~/.local/share/claude/memory/`.
6. Add `claude` and `jj-upload` to your flake (see Installing) and rebuild.
7. Add the jj alias below.

## jj

```toml
[aliases]
upload = ["util", "exec", "--", "jj-upload"]
```

## Extending (overlay)

```nix
final: prev: { claude = prev.claude.extend {
  skills.changelog = ./skills/changelog;
  settings.permissions.allow = [ "mcp__grafana__query_loki_stats" ];
  extraPackages = [ final.glab ];
}; }
```

`extend` deep-merges `settings`, `agents` and `skills`, concatenates `extraPackages`, and replaces `instructions` / `dataDir`. A `null` agent/skill removes it: `claude.extend { skills.atomic-commits = null; }`. Use `.override { ... }` to replace them wholesale instead.

## Local/private extensions

Keep private settings, skills or agents out of this repo with a separate flake that takes it as input:

```nix
{
  inputs.ai.url = "github:NikodemMarek/ai";
  outputs = { ai, ... }: {
    packages.x86_64-linux.default = ai.packages.x86_64-linux.claude.extend {
      settings = { ... };
    };
  };
}
```

Or do the same inside your system / home-manager flake: apply `ai.overlays.default`, then `home.packages = [ (pkgs.claude.extend { ... }) ];`.
