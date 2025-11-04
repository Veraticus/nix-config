{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  programs.starship = {
    package = pkgs.starship;
    enable = true;
    enableZshIntegration = true;

    settings = {
      palette = "catppuccin_mocha";

      format = "[](fg:lavender)$directory$character";

      right_format = "[](fg:mauve)\${custom.coderspace}\${custom.devspace}\${custom.hostname}[](fg:sky bg:rosewater)$git_branch$git_status[](fg:peach bg:sky)$aws[](bg:peach fg:teal)$kubernetes[](fg:teal)";

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
      };

      "cmd_duration" = {
        style = "bg:mauve fg:base";
        format = "[ $duration ]($style)";
      };

      aws = {
        style = "bg:peach fg:base";
        format = "[  $profile ]($style)";
        force_display = true;
      };

      hostname = {
        style = "bg:rosewater fg:base";
        format = "[ 󰒋 $hostname ]($style)";
        ssh_only = true;
        ssh_symbol = "";
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
        format = "[ ☸ $context ]($style)";
        style = "bg:teal fg:base";
        symbol = "";
      };

      custom = {
        coderspace = {
          when = ''test -n "$CODER_WORKSPACE_NAME"'';
          command = ''echo "   $CODER_WORKSPACE_NAME"'';
          format = "[ $output ]($style)";
          style = "bg:mauve fg:base bold";
        };
        devspace = {
          when = ''test -n "$TMUX_DEVSPACE"'';
          command = ''
            case "$TMUX_DEVSPACE" in
              mercury) echo " ☿ mercury" ;;
              venus)   echo " ♀ venus" ;;
              earth)   echo " ♁ earth" ;;
              mars)    echo " ♂ mars" ;;
              jupiter) echo " ♃ jupiter" ;;
              *)       echo " ● $TMUX_DEVSPACE" ;;
            esac
          '';
          format = "[ $output ]($style)";
          style = "bg:mauve fg:base bold";
        };
        hostname = {
          when = ''test -z "$CODER_WORKSPACE_NAME"'';
          command = ''hostname'';
          format = "[](fg:rosewater bg:mauve)[ 󰒋 $output ]($style)";
          style = "bg:rosewater fg:base";
        };
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
