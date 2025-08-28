-- Ensure clipboard is set to use system clipboard
-- This needs to run after LazyVim sets its defaults

-- Set clipboard to use system clipboard for all operations
vim.opt.clipboard = "unnamedplus"

-- Configure linkpearl as clipboard provider if available
if vim.fn.executable('linkpearl') == 1 then
  -- Use sh -c to handle empty input gracefully
  vim.g.clipboard = {
    name = 'linkpearl',
    copy = {
      ['+'] = {'sh', '-c', 'input=$(cat); [ -n "$input" ] && echo -n "$input" | linkpearl copy'},
      ['*'] = {'sh', '-c', 'input=$(cat); [ -n "$input" ] && echo -n "$input" | linkpearl copy'},
    },
    paste = {
      ['+'] = {'linkpearl', 'paste'},
      ['*'] = {'linkpearl', 'paste'},
    },
    cache_enabled = 0,
  }
end