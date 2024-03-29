{ inputs, lib, config, pkgs, ... }: {
  imports = [
    inputs.hyprland.homeManagerModules.default
  ];

  nixpkgs = {
    overlays = [
      inputs.nixpkgs-wayland.overlay
    ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland = {
      enable = true;
    };

    extraConfig = ''
      exec-once=${pkgs.unstable.polkit-kde-agent}/libexec/polkit-kde-authentication-agent-1
      exec-once=systemctl --user restart xremap
      exec-once=eww daemon && eww open-many main-bar main-bar-background
      exec-once=swww init && swww img ~/Backgrounds/Paisley.jpg
      exec-once=${inputs.nixpkgs-wayland.packages.${pkgs.system}.wl-clipboard}/bin/wl-paste --type text --watch cliphist store
      exec-once=${inputs.nixpkgs-wayland.packages.${pkgs.system}.wl-clipboard}/bin/wl-paste --type image --watch cliphist store
      exec-once=${inputs.nixpkgs-wayland.packages.${pkgs.system}.wl-clipboard}/bin/wl-paste --type text -w sh -c 'xclip -selection clipboard -o > /dev/null 2> /dev/null || xclip -selection clipboard'
      exec-once=${pkgs.unstable.wl-clip-persist}/bin/wl-clip-persist --clipboard both
      exec-once=rm "$HOME/.cache/cliphist/db"
      exec-once="${pkgs.libratbag}/bin/ratbagctl thundering-gerbil dpi set 750"
      exec-once="${pkgs.libratbag}/bin/ratbagctl warbling-mara dpi set 750"
      exec-once="${pkgs.libratbag}/bin/ratbagctl hollering-marmot dpi set 750"
      exec-once=dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY
      exec-once=''${HOME}/.config/hypr/scripts/lock.sh

      source=./catppuccin.conf

      monitor=HDMI-A-1,preferred,auto,1

      input {
        kb_layout = us
        follow_mouse = 1
        sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
        repeat_rate=60
        repeat_delay=200
      }

      general {
        gaps_in=5
        gaps_out=5
        border_size=2
        no_border_on_floating = false
        layout = dwindle
        col.inactive_border = 0xff313244
        col.active_border = 0xff9399b2
      }

      misc {
        disable_hyprland_logo = true
        disable_splash_rendering = true
        mouse_move_enables_dpms = true
      }

      decoration {
        rounding = 8
        active_opacity = 1.0
        inactive_opacity = 0.8
        drop_shadow = true
        shadow_ignore_window = true
        shadow_offset = 0 0
        shadow_range = 0
        shadow_render_power = 2
        col.shadow = 0x66000000
        blurls = gtk-layer-shell
        blurls = waybar
        blurls = lockscreen
        blurls = apply-blur
        blurls = remove,no-blur

        blur {
          enabled = true
          size = 3
          passes = 1
        }
      }

      animations {
        enabled = true

        bezier = overshot, 0.05, 0.9, 0.1, 1.05
        bezier = smoothOut, 0.36, 0, 0.66, -0.56
        bezier = smoothIn, 0.25, 1, 0.5, 1

        animation = windows, 1, 3, overshot, slide
        animation = windowsOut, 1, 3, smoothOut, slide
        animation = windowsMove, 1, 3, default
        animation = border, 1, 3, default
        animation = fade, 1, 3, smoothIn
        animation = fadeDim, 1, 3, smoothIn
        animation = workspaces, 1, 3, default
      }

      dwindle {
        no_gaps_when_only = false
        pseudotile = true # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        preserve_split = true # you probably want this
      }

      layerrule = blur, gtk-layer-shell
      layerrule = blur, lockscreen
      layerrule = blur, waybar
      layerrule = blur, apply-blur

      windowrule = float, org.kde.polkit-kde-authentication-agent-1
      windowrule = float, title:Confirm to replace files
      windowrule = float, file_progress
      windowrule = float, title:File Operation Progress
      windowrule = float, confirm
      windowrule = float, dialog
      windowrule = float, download
      windowrule = float, notification
      windowrule = float, error
      windowrule = float, splash
      windowrule = float, confirmreset
      windowrule = float, title:Open File
      windowrule = float, title:branchdialog
      windowrule = float, Lxappearance
      windowrule = fullscreen, wlogout
      windowrule = float, title:wlogout
      windowrule = fullscreen, title:wlogout
      windowrule = idleinhibit focus, mpv
      windowrule = idleinhibit fullscreen, firefox
      windowrulev2 = float, title:^(Media viewer)$
      windowrulev2 = float, title:^(Volume Control)$
      windowrulev2 = float, title:^(Picture-in-Picture)$
      windowrulev2 = float, title:^(1Password)$
      windowrulev2 = size 600 400, title:^(Volume Control)$
      windowrulev2 = nomaxsize, title:^(Wine configuration)$
      windowrulev2 = tile, title:^(Wine configuration)$
      windowrulev2 = forceinput, title:^(Wine configuration)$

      ## Assign applications to certain workspaces

      windowrulev2 = workspace 1, class:^(kitty)$
      windowrulev2 = workspace 2, class:^(firefox)$
      windowrulev2 = workspace 3, class:^(Spotify)$
      windowrulev2 = fullscreen, class:^(Spotify)$
      windowrulev2 = workspace 4, class:^(Slack)$
      windowrulev2 = workspace 5, class:^(discord)$
      windowrulev2 = workspace 5, title:^(Signal Beta)$
      windowrulev2 = workspace 6, class:^(Steam)$
      windowrulev2 = workspace 6, class:^(XIVLauncher.Core)$
      windowrulev2 = workspace 6, title:^(FINAL FANTASY XIV)$
      windowrulev2 = workspace 6, class:^(.gamescope-wrapped)$

      bind = ALT, C, pass, ^(discord)$
      bind = CTRL ALT, L, exec, swaylock
      bind = SUPER, Space, exec, wofi --show drun -n
      bind = SUPER, Return, exec, kitty
      bind = SUPER, P, exec, 1password
      bind = SUPER, Escape, exec, wlogout --protocol layer-shell -b 4 -T 400 -B 400hyp
      bind = SUPER SHIFT, V, exec, cliphist list | wofi --show dmenu | cliphist decode | wl-copy
      bind = , PRINT, exec, grimblast --freeze copysave area ~/Downloads/$(date +%s).png
      bind = SUPER, up, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bind = SUPER, down, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bind = SUPER, M, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

      ################################## Window Management ###########################################
      bind = SUPER, Q, killactive,
      bind = SUPER SHIFT, Q, exit,
      bind = SUPER SHIFT, F, fullscreen,
      # bind = SUPER, S, togglesplit, # dwindle

      bind = SUPER, H, movefocus, l
      bind = SUPER, L, movefocus, r
      bind = SUPER, K, movefocus, u
      bind = SUPER, J, movefocus, d

      bind = SUPER SHIFT, H, movewindow, l
      bind = SUPER SHIFT, L, movewindow, r
      bind = SUPER SHIFT, K, movewindow, u
      bind = SUPER SHIFT, J, movewindow, d

      bind = SUPER ALT, h, resizeactive, -50 0
      bind = SUPER ALT, l, resizeactive, 50 0
      bind = SUPER ALT, k, resizeactive, 0 -50
      bind = SUPER ALT, j, resizeactive, 0 50

      bind = SUPER CTRL, h, workspace, e-1
      bind = SUPER CTRL, l, workspace, e+1
      bind = SUPER CTRL, up, resizeactive, 0 -20
      bind = SUPER CTRL, down, resizeactive, 0 20

      bind= SUPER, g, togglegroup
      bind= SUPER, tab, changegroupactive

      bind = SUPER, x, togglespecialworkspace
      bind = SUPERSHIFT, x, movetoworkspace, special

      bind = SUPER, 1, workspace, 1
      bind = SUPER, 2, workspace, 2
      bind = SUPER, 3, workspace, 3
      bind = SUPER, 4, workspace, 4
      bind = SUPER, 5, workspace, 5
      bind = SUPER, 6, workspace, 6
      bind = SUPER, 7, workspace, 7
      bind = SUPER, 8, workspace, 8
      bind = SUPER, 9, workspace, 9
      bind = SUPER, 0, workspace, 10
      bind = SUPER ALT, up, workspace, e+1
      bind = SUPER ALT, down, workspace, e-1

      bind = SUPER SHIFT, 1, movetoworkspace, 1
      bind = SUPER SHIFT, 2, movetoworkspace, 2
      bind = SUPER SHIFT, 3, movetoworkspace, 3
      bind = SUPER SHIFT, 4, movetoworkspace, 4
      bind = SUPER SHIFT, 5, movetoworkspace, 5
      bind = SUPER SHIFT, 6, movetoworkspace, 6
      bind = SUPER SHIFT, 7, movetoworkspace, 7
      bind = SUPER SHIFT, 8, movetoworkspace, 8
      bind = SUPER SHIFT, 9, movetoworkspace, 9
      bind = SUPER SHIFT, 0, movetoworkspace, 10

      bindm = SUPER, mouse:272, movewindow
      bindm = SUPER, mouse:273, resizewindow
    '';
  };

  xdg.configFile."hypr" = {
    source = ./hypr;
    recursive = true;
  };
}
