{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./shell.nix
  ];

  programs.wezterm = {
    enable = true;
    package = inputs.wezterm.packages.${pkgs.system}.default;
    extraConfig= ''
    return {
        enable_wayland = false,
        window_close_confirmation = "NeverPrompt",
    }
    '';
  };
}
