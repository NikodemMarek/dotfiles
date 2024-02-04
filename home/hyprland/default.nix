{ config, pkgs, lib, settings, ... }: {
  imports = [
    ./hyprpaper.nix

    ../alacritty.nix
    ../joshuto
    ../gtklock.nix
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
    extraConfig = ''
      # Colors
      $rosewater = 0xfff5e0dc
      $flamingo  = 0xfff2cdcd
      $pink      = 0xfff5c2e7
      $mauve     = 0xffcba6f7
      $red       = 0xfff38ba8
      $maroon    = 0xffeba0ac
      $peach     = 0xfffab387
      $yellow    = 0xfff9e2af
      $green     = 0xffa6e3a1
      $teal      = 0xff94e2d5
      $sky       = 0xff89dceb
      $sapphire  = 0xff74c7ec
      $blue      = 0xff89b4fa
      $lavender  = 0xffb4befe

      $text      = 0xffcdd6f4
      $subtext1  = 0xffbac2de
      $subtext0  = 0xffa6adc8

      $overlay2  = 0xff9399b2
      $overlay1  = 0xff7f849c
      $overlay0  = 0xff6c7086

      $surface2  = 0xff585b70
      $surface1  = 0xff45475a
      $surface0  = 0xff313244

      $base      = 0xff1e1e2e
      $mantle    = 0xff181825
      $crust     = 0xff11111b

      monitor = , preferred, auto, 1

      input {
        kb_layout = pl, pl
        kb_variant = , dvp
        kb_model =
        kb_options = caps:escape
        kb_rules =
        numlock_by_default = true

        follow_mouse = 2

        touchpad {
          natural_scroll = false
          disable_while_typing = true
          middle_button_emulation = true
          tap-to-click = true
          tap-and-drag = true
        }

        sensitivity = 0
      }

      general {
        gaps_in = 1
        gaps_out = 2
        border_size = 1
        col.active_border = $rosewater
        col.inactive_border = $surface1

        layout = dwindle
      }

      decoration {
        rounding = 0

        drop_shadow = yes
        shadow_range = 4
        shadow_render_power = 3
        col.shadow = $overlay1
      }

      animations {
        enabled = true

        bezier = bezierWindow, 0.05, 0.9, 0.1, 1.05
        bezier = bezierWindowOut, 0.05, 0.9, 0.1, 1.05
        bezier = bezierWindowIn, 0.05, 0.9, 0.1, 1.05

        animation = windows, 1, 7, bezierWindow
        animation = windowsOut, 1, 7, bezierWindowOut, slide
        animation = windowsIn, 1, 7, bezierWindowIn, slide
        animation = border, 1, 10, default
        animation = fade, 1, 7, default
        animation = workspaces, 1, 6, default, slidevert
      }

      dwindle {
        pseudotile = true
        preserve_split = true
      }

      master {
        new_is_master = true
      }

      gestures {
        workspace_swipe = true
        workspace_swipe_create_new = true
        workspace_swipe_forever = false
      }

      misc {
        disable_hyprland_logo = true
        # disable_hypr_chan = true
      }

      $mod = SUPER

      # Toggle window states
      bind = $mod, V, togglefloating,
      bind = $mod, F, fullscreen,
      bind = $mod, P, pseudo, # dwindle
      bind = $mod, J, togglesplit, # dwindle

      # move focus between recent windows
      bind = $mod, d, focuscurrentorlast,

      # Move focus with mod + arrow keys or hjkl
      bind = $mod, left, movefocus, l
      bind = $mod, right, movefocus, r
      bind = $mod, up, movefocus, u
      bind = $mod, down, movefocus, d
      bind = $mod, h, movefocus, l
      bind = $mod, l, movefocus, r
      bind = $mod, k, movefocus, u
      bind = $mod, j, movefocus, d

      # Switch workspaces with mod + [0-9]
      bind = $mod, code:10, workspace, 1
      bind = $mod, code:11, workspace, 2
      bind = $mod, code:12, workspace, 3
      bind = $mod, code:13, workspace, 4
      bind = $mod, code:14, workspace, 5
      bind = $mod, code:15, workspace, 6
      bind = $mod, code:16, workspace, 7
      bind = $mod, code:17, workspace, 8
      bind = $mod, code:18, workspace, 9
      bind = $mod, code:19, workspace, 10
      # Switch to a special workspace with mod + {A, S}
      bind = $mod, A, workspace, 1
      bind = $mod, S, workspace, 2

      # Move active window to a workspace with mod + SHIFT + [0-9]
      bind = $mod SHIFT, code:10, movetoworkspace, 1
      bind = $mod SHIFT, code:11, movetoworkspace, 2
      bind = $mod SHIFT, code:12, movetoworkspace, 3
      bind = $mod SHIFT, code:13, movetoworkspace, 4
      bind = $mod SHIFT, code:14, movetoworkspace, 5
      bind = $mod SHIFT, code:15, movetoworkspace, 6
      bind = $mod SHIFT, code:16, movetoworkspace, 7
      bind = $mod SHIFT, code:17, movetoworkspace, 8
      bind = $mod SHIFT, code:18, movetoworkspace, 9
      bind = $mod SHIFT, code:19, movetoworkspace, 10
      # Move active window to a special workspace with mod + SHIFT + {A, S}
      # bind = $mod SHIFT, A, movetoworkspace, name:browser
      # bind = $mod SHIFT, S, movetoworkspace, name:code

      # Move/resize windows with mod + LMB/RMB and dragging
      bindm = $mod, mouse:272, movewindow
      bindm = $mod, mouse:273, resizewindow

      # Kill active window
      bind = $mod, W, killactive,

      # Execs
      bind = $mod, SPACE, exec, anyrun
      bind = $mod, RETURN, exec, alacritty
      bind = $mod SHIFT, RETURN, exec, alacritty --working-directory ~/projects/
      bind = $mod, E, exec, alacritty -e joshuto

      bind = , PRINT, exec, grim -g "$(slurp)" - | wl-copy # screenshot
      bind = SHIFT, PRINT, exec, grim -g "$(slurp)" ~/screenshots/$(date +'%Y-%m-%d_%H:%M:%S').png # screenshot

      bind = $mod, ESCAPE, exec, gtklock -d --no-input-inhibit # lock session
      bind = $mod SHIFT, ESCAPE, exit # exit hyprland

      # Media keys
      bindl = , XF86AudioPlay, exec, playerctl play-pause # player play/pause

      bindl = , XF86AudioPrev, exec, playerctl previous # player previous
      bindl = , XF86AudioNext, exec, playerctl next # player next

      bindl = , XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle # mute audio
      bindl = , XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5% # lower audio volume
      bindl = , XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5% # raise audio volume

      # Rules
      windowrule = workspace 1 silent, firefox
      workspace = 1, monitor:HDMI-A-1

      exec-once = hyprpaper
      exec-once = ${config.home.homeDirectory}/${config.xdg.configFile."autorun.sh".target}
    '';
  };
}
