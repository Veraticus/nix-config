-- Ensure clipboard is set to use system clipboard
-- This needs to run after LazyVim sets its defaults

-- Set clipboard to use system clipboard for all operations
vim.opt.clipboard = "unnamedplus"

-- Configure linkpearl as clipboard provider if available
if vim.fn.executable('linkpearl') == 1 then
  vim.g.clipboard = {
    name = 'linkpearl',
    copy = {
      ['+'] = {'linkpearl', 'copy'},
      ['*'] = {'linkpearl', 'copy'},
    },
    paste = {
      ['+'] = {'linkpearl', 'paste'},
      ['*'] = {'linkpearl', 'paste'},
    },
    cache_enabled = 0,
  }
end