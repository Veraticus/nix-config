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

      # Only set LS_COLORS if vivid is available
      if command -v vivid &>/dev/null; then
        export LS_COLORS="$(vivid generate catppuccin-mocha)"
      fi

      export ZVM_CURSOR_STYLE_ENABLED=false
      export XL_SECRET_PROVIDER=FILE
      export WINEDLLOVERRIDES="d3dcompiler_47=n;d3d11=n,b"

      # Set up Prisma to use Nix-provided engines on NixOS
      ${lib.optionalString pkgs.stdenv.isLinux ''
        export PRISMA_SCHEMA_ENGINE_BINARY="${pkgs.prisma-engines}/bin/schema-engine"
        export PRISMA_QUERY_ENGINE_LIBRARY="${pkgs.prisma-engines}/lib/libquery_engine.node"
        export PRISMA_QUERY_ENGINE_BINARY="${pkgs.prisma-engines}/bin/query-engine"
        export PRISMA_FMT_BINARY="${pkgs.prisma-engines}/bin/prisma-fmt"
      ''}

      # Source secrets file if it exists
      [ -f ~/.secrets ] && source ~/.secrets
    '';

    history = {
      size = 50000;
      save = 50000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    initContent = ''
      # Prepend Homebrew to PATH so it takes precedence over Nix packages
      # This fixes issues with broken Nix packages like shellspec
      [ -d "/opt/homebrew/bin" ] && export PATH=/opt/homebrew/bin:''${PATH}

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

      if [[ -z ${EE_SYNCED-} && -x ${HOME}/.local/bin/ee && -n ${OP_SERVICE_ACCOUNT_TOKEN:-} ]]; then
        "${HOME}/.local/bin/ee" sync --quiet || true
        export EE_SYNCED=1
      fi

      # Start atuin daemon if not running (for containers without systemd)
      # Run in subshell to suppress job control messages
      if command -v atuin &>/dev/null && ! pgrep -x "atuin" &>/dev/null; then
        mkdir -p ~/.local/share/atuin
        (atuin daemon &>/dev/null &)
      fi

      cd ~
    '';
  };
}
