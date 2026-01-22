{config, ...}: {
  programs.kitty = {
    enable = true;

    font.name = "Maple Mono NF CN";
    themeFile = "Catppuccin-Mocha";

    keybindings = {
      "kitty_mod" = "ctrl+shift";
      # Keep default macOS clipboard behavior
      "cmd+c" = "copy_to_clipboard";
      "cmd+v" = "paste_from_clipboard";
      # Also map Ctrl+V for consistency in terminal apps
      "ctrl+v" = "paste_from_clipboard";
      # Also allow kitty modifier versions
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
      "kitty_mod+h" = "show_scrollback";
      "kitty_mod+g" = "show_last_non_empty_command_output";
    };

    settings = {
      "cursor_trail" = 1;
      "cursor_trail_decay" = "0.1 0.4";
      "cursor_trail_start_threshold" = 2;
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
      "clipboard_control" = "write-clipboard write-primary read-clipboard read-primary";
      "term" = "xterm-kitty";
      # SSH configuration
      "ssh_env" = "TERM=xterm-256color"; # Use compatible TERM for SSH
      # SSH clipboard integration
      "share_connections" = true;
      "remote_kitty" = "if-needed";
      # macOS clipboard integration
      "copy_on_select" = false; # Don't auto-copy on select
      "paste_actions" = "quote-urls-at-prompt";
      "strip_trailing_spaces" = "smart";
      "background_opacity" = "0.9";
      "sync_to_monitor" = true;
      "hide_window_decorations" = true;
      "scrollback_pager" = "moar --terminal-fg --wrap --no-statusbar --no-linenumbers --quit-if-one-screen +INPUT_LINE_NUMBER";
      "mouse_map ctrl+shift+right" = "press ungrabbed combine : mouse_select_command_output : show_last_visited_command_output";
      "exe_search_path" = "/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/opt/homebrew/bin";
      # Enable hyperlink handling
      "open_url_with" = "default";
      "detect_urls" = "yes";
      "url_prefixes" = "file ftp ftps gemini git gopher http https irc ircs kitty mailto news sftp ssh";
      "url_style" = "curly";
    };
  };
}
