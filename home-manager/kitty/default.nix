{ inputs, lib, config, pkgs, kitty-pkgs, ... }: {
  xdg.configFile."kitty/macos-launch-services-cmdline".source = ./macos-launch-services-cmdline;

  programs.kitty = {
    enable = true;
    package = kitty-pkgs.kitty;

    font.name = "Maple Mono NF CN";
    themeFile = "Catppuccin-Mocha";

    keybindings = {
      "kitty_mod"   = "ctrl+shift";
      "kitty_mod+c" = "copy_to_clipboard";
      "kitty_mod+v" = "paste_from_clipboard";
      "kitty_mod+s" = "launch --type=overlay --cwd=current cursor -";
      "kitty_mod+l" = "clear_terminal scrollback active";
      "kitty_mod+t" = "new_tab";
      "kitty_mod+1" = "goto_tab 1";
      "kitty_mod+2" = "goto_tab 2";
      "kitty_mod+3" = "goto_tab 3";
      "kitty_mod+4" = "goto_tab 4";
      "kitty_mod+5" = "goto_tab 5";
      "kitty_mod+6" = "goto_tab 6";
      "kitty_mod+shift+]" = "next_tab";
      "kitty_mod+shift+[" = "previous_tab";
      "cmd+enter" = "no_op";
      "cmd+shift+enter" = "no_op";
      "kitty_mod+h" = "kitty_scrollback_nvim";
      "kitty_mod+g" = "kitty_scrollback_nvim --config ksb_builtin_last_cmd_output";
    };

    settings = {
      "cursor_shape" = "block";
      "cursor_stop_blinking_after" = 0;
      "confirm_os_window_close" = 0;
      "scrollback_lines" = 10000;
      "enable_audio_bell" = false;
      "visual_bell_duration" = "0.1";
      "window_alert_on_bell" = true;
      "bell_on_tab" = true;
      "remember_window_size" = true;
      "enabled_layouts" = "Tall";
      "window_border_width" = "0.0";
      "draw_minimal_borders" = true;
      "window_margin_width" = "0.0";
      "window_padding_width" = "5.0";
      "inactive_text_alpha" = "0.8";
      "tab_bar_margin_width" = "0.0";
      "tab_bar_style" = "powerline";
      "tab_separator" = " ┇";
      "allow_remote_control" = true;
      "listen_on" = "unix:/tmp/kitty";
      "shell_integration" = "enabled";
      "clipboard_control" = "write-clipboard write-primary";
      "term" = "xterm-kitty";
      "background_opacity" = "0.9";
      "hide_window_decorations" = true;
      "mouse_map ctrl+shift+right" = "press ungrabbed combine : mouse_select_command_output : kitty_scrollback_nvim --config ksb_builtin_last_visited_cmd_output";
      "action_alias" = "kitty_scrollback_nvim kitten ${config.home.homeDirectory}/.local/share/nvim/lazy/kitty-scrollback.nvim/python/kitty_scrollback_nvim.py";
      "exe_search_path" = "/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/opt/homebrew/bin";
    };
  };
}
