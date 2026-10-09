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
}
