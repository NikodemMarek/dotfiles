{
  config,
  pkgs,
  lib,
  settings,
  ...
}: {
  imports = [
    ./hyprpaper.nix
    ./hyprlock.nix

    ../alacritty.nix
    ../joshuto
    ../anyrun.nix
  ];

  home.packages = with pkgs; [
    wl-clipboard
    grim
    slurp
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    settings = {
      monitor = [
        ", preferred, auto, 1"
      ];

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

      general = {
        "col.active_border" = "0xff${config.colorScheme.palette.base06}";
        "col.inactive_border" = "0xff${config.colorScheme.palette.base03}";
        gaps_in = 1;
        gaps_out = 2;
        border_size = 1;
        layout = "dwindle";
      };

      decoration = {
        rounding = 0;
        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "0xff${config.colorScheme.palette.base02}";
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
        new_is_master = true;
      };

      gestures = {
        workspace_swipe = true;
        workspace_swipe_create_new = true;
        workspace_swipe_forever = false;
      };

      misc = {
        disable_hyprland_logo = true;
      };

      "$mod" = "SUPER";

      bind =
        [
          # Toggle window states
          "$mod, V, togglefloating,"
          "$mod, F, fullscreen,"
          "$mod, P, pseudo," # dwindle
          "$mod, J, togglesplit," # dwindle

          # move focus between recent windows
          "$mod, d, focuscurrentorlast,"

          # Move focus with mod + arrow keys or hjkl
          "$mod, left, movefocus, l"
          "$mod, right, movefocus, r"
          "$mod, up, movefocus, u"
          "$mod, down, movefocus, d"
          "$mod, h, movefocus, l"
          "$mod, l, movefocus, r"
          "$mod, k, movefocus, u"
          "$mod, j, movefocus, d"

          # Move primary workspaces with mod + {A, S}
          "$mod, A, workspace, 1"
          "$mod, S, workspace, 2"

          # Kill active window
          "$mod, W, killactive,"

          # Execs
          "$mod, SPACE, exec, anyrun"
          "$mod, RETURN, exec, alacritty"
          "$mod SHIFT, RETURN, exec, alacritty --working-directory ~/projects/"
          "$mod, E, exec, alacritty -e joshuto"

          ", PRINT, exec, grim -g '$(slurp)' - | wl-copy" # screenshot
          "SHIFT, PRINT, exec, grim -g '$(slurp)' ~/screenshots/$(date +'%Y-%m-%d_%H:%M:%S').png" # screenshot

          "$mod SHIFT, ESCAPE, exec, hyprlock" # lock session
          "$mod ALT, ESCAPE, exit" # exit hyprland
        ]
        ++ (
          # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
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

      windowrule = [
        "workspace 1 silent, firefox"
      ];
      workspace = "1, monitor:HDMI-A-1";

      exec-once = ["hyprpaper"];
    };
  };
}
