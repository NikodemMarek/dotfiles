{ ... }: {
  imports = [
    ./shell.nix
  ];

  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      window.padding = {
        x = 5;
        y = 5;
      };
      cursor = {
        style = "Block";
        unfocused_hollow = true;
      };
    };
  };
}
