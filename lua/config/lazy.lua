local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazypath})
  if vim.v.shell_error ~= 0 then error('lazy.nvim kurulamadı: ' .. out) end
end
vim.opt.rtp:prepend(lazypath)
require('lazy').setup({
  spec = {
    {'LazyVim/LazyVim', import = 'lazyvim.plugins', version = false},
    {import = 'plugins'},
  },
  defaults = {lazy = false, version = false},
  install = {colorscheme = {'eyes', 'habamax'}},
  checker = {enabled = false},
  change_detection = {notify = false},
  performance = {rtp = {disabled_plugins = {'gzip', 'tarPlugin', 'tohtml', 'tutor', 'zipPlugin'}}},
})
