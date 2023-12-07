{ config, pkgs, lib, ... }: {
  home.packages = with pkgs; [
    gtklock
  ];

  xdg.configFile."gtklock/style.css".text = ''
    window {
      color: white;
      background-image: url("${config.home.homeDirectory}/${config.xdg.configFile."assets/background.png".target}");
      background-size: cover;
      background-repeat: no-repeat;
      background-position: center;
      background-color: gray;
    }
  '';
  xdg.configFile."gtklock/config.ini".text = ''
    [main]
    style=${config.home.homeDirectory}/${config.xdg.configFile."gtklock/style.css".target}
  '';
}
