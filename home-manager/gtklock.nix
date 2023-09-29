{ ... }: {
  programs.gtklock.enable = true;
  xdg.configFile."gtklock/style.css".text = ''
    window {
      color: white;
      background-image: url("${home.homeDirectory}/${xdg.configFile."assets/background.png".target}");
      background-size: cover;
      background-repeat: no-repeat;
      background-position: center;
      background-color: gray;
    }
  '';
  xdg.configFile."gtklock/config.ini".text = ''
    [main]
    style=${home.homeDirectory}/${xdg.configFile."gtklock/style.css".target}
  '';
}
