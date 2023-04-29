{ inputs, lib, config, pkgs, ... }: {
  imports = [
    inputs.nixneovim.nixosModules.default
  ];

  nixpkgs = {
    overlays = [
      inputs.nixneovim.overlays.default
    ];
  };

  programs.nixneovim = {
    enable = true;
    colorscheme = "catppuccin";

    plugins = {
      lsp = {
        enable = true;
        bashls.enable = true;
        html.enable = true;
        jsonls.enable = true;
        nix-lsp.enable = true;
        gopls.enable = true;
        rust-analyzer.enable = true;
      };
      treesitter = {
        enable = true;
        indent = true;
      };
      mini = {
        enable = true;
        ai.enable = true;
        jump.enable = true;
      };
      gitsigns = {
        enable = true;
      };
    };

    extraPlugins = [
      pkgs.vimExtraPlugins.catppuccin
      pkgs.vimExtraPlugins.leap
      pkgs.vimExtraPlugins.nvim-web-devicons
    ];
  };
}
