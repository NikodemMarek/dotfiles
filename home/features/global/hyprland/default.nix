{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: {
  imports = [
    ./hyprlock.nix

    ../wezterm.nix
    ../yazi.nix
    ../walker
  ];

  home.packages = with pkgs; [
    wl-clipboard
    (config.lib.nixGL.wrap wl-mirror)
    grim
    slurp
    pulseaudio
    (config.lib.nixGL.wrap wdisplays)
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = config.lib.nixGL.wrap inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = config.lib.nixGL.wrap inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
    settings = {
      monitor = [", preferred, auto, 1"];

      input = {
        kb_layout = "pl";
        numlock_by_default = true;
        follow_mouse = 1;
        touchpad = {
          natural_scroll = false;
          disable_while_typing = true;
          middle_button_emulation = true;
          tap-to-click = true;
          tap-and-drag = true;
        };
        sensitivity = 0;
      };

      "debug:disable_logs" = false;
      "debug:enable_stdout_logs" = true;

      general = {
        gaps_in = 5;
        gaps_out = 5;
        border_size = 0;
        layout = "master";
      };

      decoration = {
        rounding = 8;
      };

      animations = {
        enabled = true;
        bezier = [
          "bezierWindow, 0.05, 0.9, 0.1, 1.05"
          "bezierWindowOut, 0.05, 0.9, 0.1, 1.05"
          "bezierWindowIn, 0.05, 0.9, 0.1, 1.05"
        ];

        animation = [
          "windows, 1, 7, bezierWindow"
          "windowsOut, 1, 7, bezierWindowOut, slide"
          "windowsIn, 1, 7, bezierWindowIn, slide"
          "border, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default, slidevert"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
        mfact = 0.75;
        orientation = "right";
      };

      gesture = "3, vertical, workspace";

      misc = {
        disable_hyprland_logo = true;
      };

      "$mod" = "SUPER";

      bind = let
        wezterm = lib.getExe config.programs.wezterm.package;
      in
        [
          # Toggle window states
          "$mod, V, togglefloating,"
          "$mod, F, fullscreen,"

          # Master layout
          "$mod, o, layoutmsg, focusmaster"
          "$mod SHIFT, o, layoutmsg, swapwithmaster"
          "$mod, t, layoutmsg, rollnext"

          # Move focus between recent windows
          "$mod, d, focuscurrentorlast,"

          # Move focus with mod + arrow keys or hl
          "$mod, left, movefocus, l"
          "$mod, right, movefocus, r"
          "$mod, up, movefocus, u"
          "$mod, down, movefocus, d"
          "$mod, h, movefocus, l"
          "$mod, l, movefocus, r"

          # Go to {next, prev, empty, 1, 2} workspace with mod + {j, k, n, a, s}
          "$mod, k, workspace, m-1"
          "$mod, j, workspace, m+1"
          "$mod, n, workspace, emptynm"
          "$mod, a, workspace, 1"
          "$mod, s, workspace, 2"

          # Move window to {next, prev, empty, 1, 2} workspace with mod + shift + {j, k, n, a, s}
          "$mod SHIFT, k, movetoworkspace, r-1"
          "$mod SHIFT, j, movetoworkspace, r+1"
          "$mod SHIFT, n, movetoworkspace, empty"
          "$mod SHIFT, a, movetoworkspace, 1"
          "$mod SHIFT, s, movetoworkspace, 2"

          # Kill active window
          "$mod, W, killactive,"

          # Execs
          "$mod, SPACE, exec, walker"
          "$mod, RETURN, exec, ${wezterm} start --always-new-process"
          "$mod, E, exec, ${wezterm} start --always-new-process ${pkgs.yazi}/bin/yazi"

          ", PRINT, exec, grim -g \"$(slurp)\" - | wl-copy" # screenshot
          "SHIFT, PRINT, exec, grim -g \"$(slurp)\" ~/screenshots/$(date +'%Y-%m-%d_%H:%M:%S').png" # screenshot

          "$mod SHIFT, ESCAPE, exec, hyprlock" # lock session
          "$mod ALT, ESCAPE, exit" # exit hyprland
        ]
        ++ (
          # binds $mod + [shift +] {1..10} to go to [/ move to] workspace {1..10}
          builtins.concatLists (builtins.genList (
              x: let
                ws = let
                  c = (x + 1) / 10;
                in
                  builtins.toString (x + 1 - (c * 10));
              in [
                "$mod, ${ws}, workspace, ${toString (x + 1)}"
                "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
              ]
            )
            10)
        );

      bindm = [
        # Move/resize windows with mod + LMB/RMB and dragging
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      bindl = [
        # Media keys
        ", XF86AudioPlay, exec, playerctl play-pause" # player play/pause

        ", XF86AudioPrev, exec, playerctl previous" # player previous
        ", XF86AudioNext, exec, playerctl next" # player next

        ", XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle" # mute audio
        ", XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%" # lower audio volume
        ", XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%" # raise audio volume
      ];

      workspace = "1, monitor:HDMI-A-1";
    };
  };
}
