# Applied as the `additions` overlay with the final package set (it refers to its own attrs).
{pkgs}: {
  wrapped = {
    zellij = pkgs.callPackage ./zellij {};
    hyprland = pkgs.callPackage ./hyprland {};
    hyprlock = pkgs.callPackage ./hyprlock {};
    hypridle = pkgs.callPackage ./hypridle {};
    hyprpaper = pkgs.callPackage ./hyprpaper {};
    rofi = pkgs.callPackage ./rofi {};
    dunst = pkgs.callPackage ./dunst {};
    git = pkgs.callPackage ./git {};
    gitui = pkgs.callPackage ./gitui {};
    jujutsu = pkgs.callPackage ./jujutsu {};
    waybar = pkgs.callPackage ./waybar {};
    kanshi = pkgs.callPackage ./kanshi {};
    signal-desktop = pkgs.callPackage ./signal-desktop {};
    # `pkgs.glab` is the upstream package here (wrapped.glab is not top level);
    # passed explicitly, and never aliased top-level (callPackage would recurse).
    glab = pkgs.callPackage ./glab {inherit (pkgs) glab;};
    # The nulls pin the "use the bundled default" arguments so a same-named
    # top-level package (e.g. `skills`) is never auto-injected by callPackage.
    claude = pkgs.callPackage ./claude {
      instructions = null;
      agents = null;
      skills = null;
      settings = null;
    };
  };

  # Standalone tools. claude takes knowledge, claude-hooks, claude-statusline
  # and jj-upload from the package set, so overrides of them propagate.
  jj-upload = pkgs.callPackage ./jj-upload {};
  agent-skills = pkgs.callPackage ./agent-skills {};
  claude-hooks = pkgs.callPackage ./claude-hooks {};
  claude-statusline = pkgs.callPackage ./claude-statusline {};
  knowledge = pkgs.callPackage ./knowledge {};

  event-handlers = {
    notify = pkgs.callPackage ./event-handlers/notify {};
    notify-critical = pkgs.event-handlers.notify.override {urgency = "critical";};
    # claude is only in `wrapped`: callPackage would not find it (and would
    # recurse on a top-level alias)
    knowledge = pkgs.callPackage ./event-handlers/knowledge {
      claude = pkgs.wrapped.claude;
    };
  };

  # `handlers` stays explicit so `.override (old: {handlers = old.handlers // ...})`
  # can extend it.
  event-router = pkgs.callPackage ./event-router {
    handlers = {
      default = pkgs.event-handlers.notify;
      knowledge = pkgs.event-handlers.knowledge;
      # exact type wins over the `knowledge` prefix
      "knowledge.review_needed" = pkgs.event-handlers.notify;
    };
  };

  knowledge-timers = pkgs.callPackage ./knowledge-timers {};
}
