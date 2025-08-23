-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- Basic vim options
local opt = vim.opt

opt.wrap = true

-- Clipboard will be configured after LazyVim loads to prevent overrides
-- See config/clipboard-setup.lua which is loaded via autocmd
-- opt.textwidth = 0
-- opt.scrolloff = 4
-- opt.wildmode = "longest:full,full"
-- opt.wildoptions = "pum"
-- opt.inccommand = "nosplit"
-- opt.lazyredraw = true
-- opt.showmatch = true
-- opt.ignorecase = true
-- opt.smartcase = true
-- opt.tabstop = 2
-- opt.softtabstop = 0
-- opt.expandtab = true
-- opt.shiftwidth = 2
-- opt.number = true
-- opt.backspace = "indent,eol,start"
-- opt.smartindent = true
-- opt.laststatus = 3
-- opt.showmode = false
-- opt.shada = "'20,<50,s10,h,/100"
-- opt.hidden = true
-- opt.joinspaces = false
-- opt.updatetime = 100
-- opt.conceallevel = 2
-- opt.concealcursor = "nc"
-- opt.previewheight = 5
-- opt.synmaxcol = 500
-- opt.display = "msgsep"
-- opt.cursorline = true
-- opt.modeline = false
-- opt.mouse = "nivh"
-- opt.signcolumn = "yes:1"
-- opt.ruler = true
opt.termguicolors = true
