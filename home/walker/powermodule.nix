{pkgs, ...}: let
  poweroff = pkgs.makeDesktopItem {
    name = "poweroff";
    desktopName = "poweroff";
    exec = "poweroff";
    terminal = true;
  };
  reboot = pkgs.makeDesktopItem {
    name = "reboot";
    desktopName = "reboot";
    exec = "reboot";
    terminal = true;
  };
  lock = pkgs.makeDesktopItem {
    name = "lock";
    desktopName = "lock";
    exec = "hyprlock";
    terminal = true;
  };
  logout = pkgs.makeDesktopItem {
    name = "logout";
    desktopName = "logout";
    exec = "hyprctl dispatch exit";
    terminal = true;
  };
  suspend = pkgs.makeDesktopItem {
    name = "suspend";
    desktopName = "suspend";
    exec = ''bash -c "hyprlock ; systemctl suspend"'';
    terminal = true;
  };
  hibernate = pkgs.makeDesktopItem {
    name = "hibernate";
    desktopName = "hibernate";
    exec = ''bash -c "hyprlock ; systemctl hibernate"'';
    terminal = true;
  };
in {
  home.packages = [poweroff reboot lock logout suspend hibernate];
}
