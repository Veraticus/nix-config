{ inputs, lib, config, pkgs, ... }: {
  programs.starship = {
    package = pkgs.unstable.starship;
    enable = true;
    enableZshIntegration = true;

    settings = {
      palette = "catppuccin_mocha";

      format = "[](fg:lavender)$directory$character";

      right_format = "[](fg:mauve)$hostname[](fg:rosewater bg:mauve)$hostname[](fg:sky bg:rosewater)$git_branch$git_status[](fg:peach bg:sky)$aws[](bg:peach fg:teal)$kubernetes[](fg:teal)";

      add_newline = false;

      "line_break" = {
        disabled = true;
      };

      fill = {
        disabled = true;
      };

      directory = {
        style = "bg:lavender fg:base";
        format = "[ $path ]($style)";

        truncation_length = 2;
        truncation_symbol = "…/";
        fish_style_pwd_dir_length = 2;
      };

      character = {
        success_symbol = "[](bg:green fg:lavender)[](fg:green)";
        error_symbol = "[](bg:red fg:lavender)[](fg:red)";
        vimcmd_symbol = "[](fg:yellow bg:lavender)[](bg:yellow fg:base)";
        vimcmd_replace_one_symbol = "[](fg:flamingo bg:lavender)[](bg:flamingo fg:base)";
        vimcmd_replace_symbol = "[](fg:flamingo bg:lavender)[](bg:flamingo fg:base)";
        vimcmd_visual_symbol = "[](fg:yellow bg:lavender)[](bg:yellow fg:base)";
      };

      "cmd_duration" = {
        style = "bg:mauve fg:base";
        format = "[ $duration ]($style)";
      };

      aws = {
        style = "bg:peach fg:base";
        format = "[ $profile ]($style)";
        force_display = true;
      };

      hostname = {
        style = "bg:rosewater fg:base";
        format = "[ $hostname ]($style)";
      };

      "git_branch" = {
        style = "bg:sky fg:base";
        format = "[ $symbol$branch ]($style)";
      };

      "git_status" = {
        style = "bg:sky fg:base";
        format = "[$all_status$ahead_behind ]($style)";
      };

      kubernetes = {
        disabled = false;
        format = "[ $symbol$context ]($style)";
        style = "bg:teal fg:base";
      };

      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
      };
    };
  };
}
