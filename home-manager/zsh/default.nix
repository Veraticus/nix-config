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

    initExtraFirst = ''
      [ -d "/opt/homebrew/bin" ] && export PATH=''${PATH}:/opt/homebrew/bin

      function async-ssh-add {
        if [ -f "''${HOME}/.ssh/github" ] && ! ssh-add -l >/dev/null; then
          ssh-add "''${HOME}/.ssh/github"
        fi
      }
      async-ssh-add > /dev/null &!

      function set-title-precmd() {
        printf "\e]2;%s\a" "''${PWD/#$HOME/~}"
      }

      function set-title-preexec() {
        printf "\e]2;%s\a" "$1"
      }

      autoload -Uz add-zsh-hook
      add-zsh-hook precmd set-title-precmd
      add-zsh-hook preexec set-title-preexec
    '';
    initExtraBeforeCompInit = ''
      if type brew &>/dev/null
      then
        FPATH="$(brew --prefix)/share/zsh/site-functions:''${FPATH}"
        [[ -r "$(brew --prefix)/etc/bash_completion.d/ckutil" ]] && . "$(brew --prefix)/etc/bash_completion.d/ckutil"
        source $(brew --prefix)/opt/chruby/share/chruby/chruby.sh
        source $(brew --prefix)/opt/chruby/share/chruby/auto.sh
      fi
    '';
    initExtra = ''
      if [ -n "''${commands[fzf-share]}" ]; then
        source "$(fzf-share)/key-bindings.zsh"
        source "$(fzf-share)/completion.zsh"
          function zvm_after_init() {
            zvm_bindkey viins '^R' fzf-history-widget
          }
      fi

      source "$(fzf-share)/key-bindings.zsh"
      source "$(fzf-share)/completion.zsh"

      if type it &>/dev/null
      then
      source $(brew --prefix)/share/zsh/site-functions/_it
        eval "$(it wrapper)"
      fi

      export PATH=''${PATH}:''${PATH}:/Applications/Windsurf.app/Contents/Resources/app/bin:''${HOME}/go/bin:''${HOME}/.local/share/../bin

      cd ~
    '';
  };
}
