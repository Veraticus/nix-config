{ inputs, lib, config, pkgs, ... }:
{
  xdg.configFile."zsh" = {
    source = ./zsh;
    recursive = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    historySubstringSearch.enable = true;

    syntaxHighlighting.enable = true;

    autosuggestion.enable = true;

    shellAliases = {
      ll = "eza -a -F -l -B --git";
      ls = "ls --color=auto";
      vim = "nvim";
      vimdiff = "nvim -d";
    };

    envExtra = ''
      export NIX_CONFIG="experimental-features = nix-command flakes"
      export LS_COLORS="$(vivid generate catppuccin-mocha)"
      export ZVM_CURSOR_STYLE_ENABLED=false
      export XL_SECRET_PROVIDER=FILE
      export WINEDLLOVERRIDES="d3dcompiler_47=n;d3d11=n,b"
      source ~/.secrets
    '';

    history = {
      size = 50000;
      save = 50000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    initContent = ''
      [ -d "/opt/homebrew/bin" ] && export PATH=''${PATH}:/opt/homebrew/bin

      # Disable mouse reporting in shell when not in tmux
      # This prevents raw mouse escape sequences from appearing
      if [ -z "$TMUX" ] && [ -n "$SSH_TTY" ]; then
        printf '\e[?1000l'  # Disable mouse tracking
        printf '\e[?1002l'  # Disable cell motion tracking
        printf '\e[?1003l'  # Disable all motion tracking
        printf '\e[?1006l'  # Disable SGR extended mode
      fi

      # Import TMUX_DEVSPACE from tmux environment if we're in tmux
      if [ -n "$TMUX" ]; then
        TMUX_DEVSPACE=$(tmux show-environment TMUX_DEVSPACE 2>/dev/null | cut -d= -f2)
        if [ -n "$TMUX_DEVSPACE" ]; then
          export TMUX_DEVSPACE
        fi
      fi

      # SSH agent is now managed by systemd (Linux) or launchd (macOS)
      # Keys are automatically loaded by the ssh-agent service
      # Use 'ssh-add-git-keys' to manually reload keys if needed

      function set-title-precmd() {
        printf "\e]2;%s\a" "''${PWD/#$HOME/~}"
      }

      function set-title-preexec() {
        printf "\e]2;%s\a" "$1"
      }

      autoload -Uz add-zsh-hook
      add-zsh-hook precmd set-title-precmd
      add-zsh-hook preexec set-title-preexec

      # Ensure emacs mode (not vi mode)
      bindkey -e
      
      if [ -n "''${commands[fzf-share]}" ]; then
        source "$(fzf-share)/key-bindings.zsh"
        source "$(fzf-share)/completion.zsh"
      fi

      if type it &>/dev/null; then
        # Only source brew completions on macOS where brew is available
        if [[ "$(uname)" == "Darwin" ]] && type brew &>/dev/null; then
          source $(brew --prefix)/share/zsh/site-functions/_it
        fi
        eval "$(it wrapper)"
      fi

      export PATH=''${PATH}:''${HOME}/go/bin:''${HOME}/.local/share/../bin

      cd ~
    '';
  };
}
