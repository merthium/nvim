-- LazyVim supplies the standard editing autocmds.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('LocalIDEWindows', {clear = true}),
  pattern = {'OverseerOutput', 'snacks_terminal'},
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
  end,
})
