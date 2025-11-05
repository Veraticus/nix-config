{ fetchFromGitHub }:
{
  "blink-cmp-copilot" = fetchFromGitHub {
    owner = "giuxtaposition";
    repo = "blink-cmp-copilot";
    rev = "439cff78780c033aa23cf061d7315314b347e3c1";
    hash = "sha256-xEGAXv41UX9GUybCSzDODkhgdEd4cclBXl0k4UBmFbs=";
  };
  "blink.cmp" = fetchFromGitHub {
    owner = "saghen";
    repo = "blink.cmp";
    rev = "327fff91fe6af358e990be7be1ec8b78037d2138";
    hash = "sha256-eMUOjG2CtedCGVU1Pdp8PCCgGoFbjeVvK7lMS8E+ogg=";
  };
  "bufferline.nvim" = fetchFromGitHub {
    owner = "akinsho";
    repo = "bufferline.nvim";
    rev = "655133c3b4c3e5e05ec549b9f8cc2894ac6f51b3";
    hash = "sha256-ae4MB6+6v3awvfSUWlau9ASJ147ZpwuX1fvJdfMwo1Q=";
  };
  "catppuccin" = fetchFromGitHub {
    owner = "catppuccin";
    repo = "nvim";
    rev = "234fc048de931a0e42ebcad675bf6559d75e23df";
    hash = "sha256-WNOuJ+XdO0x3Vlc8mALwtFU6iwJXilOM/NF0F1161FQ=";
  };
  "conform.nvim" = fetchFromGitHub {
    owner = "stevearc";
    repo = "conform.nvim";
    rev = "26c02e1155a4980900bdccabca4516f4c712aae9";
    hash = "sha256-opOnJh5yjwPAndnopPoAXjPAu4riicBtxe7lmIbT6KY=";
  };
  "copilot.lua" = fetchFromGitHub {
    owner = "zbirenbaum";
    repo = "copilot.lua";
    rev = "389cfc58122b076e2aad1f9f34d1dfdd5a5bfd0e";
    hash = "sha256-1cMcUpTkFfJJ0NHklYDsMd8l1uZ94XENc46TqjhhAAw=";
  };
  "flash.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "flash.nvim";
    rev = "fcea7ff883235d9024dc41e638f164a450c14ca2";
    hash = "sha256-pHh0tJd/ynfjriu8xjnKunKVDHkoXii6ZbikdkIwovY=";
  };
  "friendly-snippets" = fetchFromGitHub {
    owner = "rafamadriz";
    repo = "friendly-snippets";
    rev = "572f5660cf05f8cd8834e096d7b4c921ba18e175";
    hash = "sha256-FzApcTbWfFkBD9WsYMhaCyn6ky8UmpUC2io/co/eByM=";
  };
  "gitsigns.nvim" = fetchFromGitHub {
    owner = "lewis6991";
    repo = "gitsigns.nvim";
    rev = "20ad4419564d6e22b189f6738116b38871082332";
    hash = "sha256-eGpB7YYWbyCCGYXEYAM432srSp/lUo5C1b0J3OYjwnY=";
  };
  "grug-far.nvim" = fetchFromGitHub {
    owner = "MagicDuck";
    repo = "grug-far.nvim";
    rev = "3e72397465f774b01aa38e4fe8e6eecf23d766d9";
    hash = "sha256-uk2y8I8Hl8ufTFKLQuzchGxSujSlohV/2zcjL1aF65o=";
  };
  "kitty-scrollback.nvim" = fetchFromGitHub {
    owner = "mikesmithgh";
    repo = "kitty-scrollback.nvim";
    rev = "36d19dc85c0a1d0193e7c52d41129c4aa28b72e8";
    hash = "sha256-UNBQMh7No5tMpgFFzjKPloqJNhy2V58nR4aFFjqOH0E=";
  };
  "lazy.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "lazy.nvim";
    rev = "e6a8824858757ca9cd4f5ae1a72d845fa5c46a39";
    hash = "sha256-+qL1OavVbW2VXpPsdtvc/+5dVmk/JpKD4e8DH+gI940=";
  };
  "LazyVim" = fetchFromGitHub {
    owner = "LazyVim";
    repo = "LazyVim";
    rev = "28db03f958d58dfff3c647ce28fdc1cb88ac158d";
    hash = "sha256-pm1B4tdHqSV8n+hM78asqw5WNdMfC5fUSiZcjg8ZtAg=";
  };
  "lazydev.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "lazydev.nvim";
    rev = "371cd7434cbf95606f1969c2c744da31b77fcfa6";
    hash = "sha256-WxcJyUROhvPe2rVflFNMQQ6gCaU1e/HnbjmnqPTAxqM=";
  };
  "lualine.nvim" = fetchFromGitHub {
    owner = "nvim-lualine";
    repo = "lualine.nvim";
    rev = "3946f0122255bc377d14a59b27b609fb3ab25768";
    hash = "sha256-hdrAdG3hC2sAevQ6a9xizqPgEgnNKxuc5rBYn0pKM1c=";
  };
  "mason-lspconfig.nvim" = fetchFromGitHub {
    owner = "mason-org";
    repo = "mason-lspconfig.nvim";
    rev = "d7b5feb6e769e995f7fcf44d92f49f811c51d10c";
    hash = "sha256-A6R7nd47SbnJrMPyqedJqe5JEW/9Aw4BxXlOoLxWiYg=";
  };
  "mason.nvim" = fetchFromGitHub {
    owner = "mason-org";
    repo = "mason.nvim";
    rev = "ad7146aa61dcaeb54fa900144d768f040090bff0";
    hash = "sha256-sNmurxBXs/2QZARgnI4J7YyEEkqhlKFi+OkzIp4gU6I=";
  };
  "mini.ai" = fetchFromGitHub {
    owner = "nvim-mini";
    repo = "mini.ai";
    rev = "0d3c9cf22e37b86b7a0dfbe7ef129ee7a5f4f93c";
    hash = "sha256-r62uon2i1mM2UkBQzMW4Yg78fXXEpcZI6bM1pINqV+k=";
  };
  "mini.icons" = fetchFromGitHub {
    owner = "nvim-mini";
    repo = "mini.icons";
    rev = "ff2e4f1d29f659cc2bad0f9256f2f6195c6b2428";
    hash = "sha256-yns7HZFklgkiXoQJheDRAAtmoKTW9g+hpT/gf5DzwAw=";
  };
  "mini.pairs" = fetchFromGitHub {
    owner = "nvim-mini";
    repo = "mini.pairs";
    rev = "b316e68f2d242d5bd010deaab645daa27ed86297";
    hash = "sha256-SZC9OE1ADiUFTRLQV6H8X26ghcI+E5tEwXUgkMFHKvQ=";
  };
  "noice.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "noice.nvim";
    rev = "7bfd942445fb63089b59f97ca487d605e715f155";
    hash = "sha256-FKzhFVmPxshDV4mWpD3LofjRpd6pXesf9QQei1s5rAo=";
  };
  "nui.nvim" = fetchFromGitHub {
    owner = "MunifTanjim";
    repo = "nui.nvim";
    rev = "de740991c12411b663994b2860f1a4fd0937c130";
    hash = "sha256-41slmnvt1z7sCxvpiVuFmQ9g7eCaxQi1dDCL3AxSL1A=";
  };
  "nvim-aider" = fetchFromGitHub {
    owner = "GeorgesAlkhouri";
    repo = "nvim-aider";
    rev = "c8a4f952937d54f17dc23bd378e9e3b373f502b2";
    hash = "sha256-LHSDfn9I+Ff83u8DZlom7fgZNwqSZ1h72y6NJq0eKTw=";
  };
  "nvim-lint" = fetchFromGitHub {
    owner = "mfussenegger";
    repo = "nvim-lint";
    rev = "8c694e1a1ee2ac14df931679cd54e6b8d402c2c2";
    hash = "sha256-Uiz8u0aPz8UMVPjPrMTqI3wsBzjuikvd4MwJPpKzE9w=";
  };
  "nvim-lspconfig" = fetchFromGitHub {
    owner = "neovim";
    repo = "nvim-lspconfig";
    rev = "2010fc6ec03e2da552b4886fceb2f7bc0fc2e9c0";
    hash = "sha256-NGnrfvcnChwaiWV+tt3E5aRvKcidzZ4ufDPh/1QtaNE=";
  };
  "nvim-tree.lua" = fetchFromGitHub {
    owner = "nvim-tree";
    repo = "nvim-tree.lua";
    rev = "64e2192f5250796aa4a7f33c6ad888515af50640";
    hash = "sha256-QCUp/6qX/FS8LrZ6K+pvC/mHkYW8xfzQZEB2y0VOStQ=";
  };
  "nvim-treesitter" = fetchFromGitHub {
    owner = "nvim-treesitter";
    repo = "nvim-treesitter";
    rev = "65a266bf693d3fc856dd341c25edea1a0917a30f";
    hash = "sha256-VySPuAZH2XT7QFd2H81D9vZHOifsSIFFpfLWGQz/XBk=";
  };
  "nvim-treesitter-textobjects" = fetchFromGitHub {
    owner = "nvim-treesitter";
    repo = "nvim-treesitter-textobjects";
    rev = "2e5b8735a61d3cfaa65d9a8ff787a7b0a0a81b70";
    hash = "sha256-/TGY01xK6Q+THnrS0Lxvd0UxtW3qexZlQkW3s6WEMaw=";
  };
  "nvim-ts-autotag" = fetchFromGitHub {
    owner = "windwp";
    repo = "nvim-ts-autotag";
    rev = "c4ca798ab95b316a768d51eaaaee48f64a4a46bc";
    hash = "sha256-nT2W5gKFEfzP7MztLjm7yqwam3ADk0svcMdLg2nmI/4=";
  };
  "persistence.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "persistence.nvim";
    rev = "b20b2a7887bd39c1a356980b45e03250f3dce49c";
    hash = "sha256-ACuDEp4MNiP2X2LnsEjVWmajedXdCQ9gg/EK55YF7uM=";
  };
  "plenary.nvim" = fetchFromGitHub {
    owner = "nvim-lua";
    repo = "plenary.nvim";
    rev = "b9fd5226c2f76c951fc8ed5923d85e4de065e509";
    hash = "sha256-9Un7ekhBxcnmFE1xjCCFTZ7eqIbmXvQexpnhduAg4M0=";
  };
  "snacks.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "snacks.nvim";
    rev = "6121b40a2d2fc07beee040209d59e579aad51d98";
    hash = "sha256-ybWzcZrdu7DgBTFXVBqjKQOWPn8/WxdjCizUSqjQsac=";
  };
  "tiny-inline-diagnostic.nvim" = fetchFromGitHub {
    owner = "rachartier";
    repo = "tiny-inline-diagnostic.nvim";
    rev = "523c4f4711309ef81a7979455294ccaba0eec0a9";
    hash = "sha256-1y05GtvDWwOxKW3/wYORaOqvE+x3VBE+K6Vy9Z569PQ=";
  };
  "todo-comments.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "todo-comments.nvim";
    rev = "411503d3bedeff88484de572f2509c248e499b38";
    hash = "sha256-VE7n/yoYPEkp4WQ89ftscspnijPrEMroPg5qVYyVcbM=";
  };
  "tokyonight.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "tokyonight.nvim";
    rev = "b13cfc1286d2aa8bda6ce137b79e857d5a3d5739";
    hash = "sha256-310tJN2Pl5rjyhQoSMYAaoJCNu8501Pxrl5MuxuC2io=";
  };
  "trim.nvim" = fetchFromGitHub {
    owner = "cappyzawa";
    repo = "trim.nvim";
    rev = "d0760a840ca2fe4958353dee567a90c2994e70a7";
    hash = "sha256-CZwIa9GccHS/nZ+lq27A6NfpBCqEHOrTC7Hd7skPwnc=";
  };
  "trouble.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "trouble.nvim";
    rev = "bd67efe408d4816e25e8491cc5ad4088e708a69a";
    hash = "sha256-6U/KWjvRMxWIxcsI2xNU/ltfgkaFG4E3BdzC7brK/DI=";
  };
  "ts-comments.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "ts-comments.nvim";
    rev = "123a9fb12e7229342f807ec9e6de478b1102b041";
    hash = "sha256-ORK3XpHANaqvp1bfMG2GJmAiaOsLoGW82ebL/FJtKaA=";
  };
  "which-key.nvim" = fetchFromGitHub {
    owner = "folke";
    repo = "which-key.nvim";
    rev = "3aab2147e74890957785941f0c1ad87d0a44c15a";
    hash = "sha256-rKaYnXM4gRkkF/+xIFm2oCZwtAU6CeTdRWU93N+Jmbc=";
  };
}
