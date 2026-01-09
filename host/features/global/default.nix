{
  imports = [
    ./networking.nix
    ./openssh.nix
    ./sops.nix
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  programs = {
    git.enable = true;
    neovim.defaultEditor = true;
  };
  environment.variables.EDITOR = "nvim";
  security.sudo.enable = true;
}
