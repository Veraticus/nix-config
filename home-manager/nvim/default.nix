{ inputs, lib, config, pkgs, ... }: {
  home.packages = with pkgs; [
    nodejs_24
    ripgrep
    fd
    rustup
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    package = inputs.neovim-nightly.packages.${pkgs.system}.default;

    # Ensure git and other tools are available to Neovim plugins
    extraPackages = with pkgs; [
      git
      gcc # For treesitter compilation
      gnumake # For various build processes
    ];

    # Wrapper to ensure neovim has access to git
    withNodeJs = true;
    withPython3 = true;

    # Set up wrapper to ensure PATH includes git
    extraConfig = ''
      " Ensure git is in PATH for plugins
      let $PATH = $PATH . ':${pkgs.git}/bin'
    '';
  };

  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
  };
}
