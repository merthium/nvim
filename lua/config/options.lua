local opt, g = vim.opt, vim.g
-- Keep NASM detection independent of optional practice tools.
vim.filetype.add({extension = {asm = 'nasm', nasm = 'nasm'}})
-- User-local language tools are also available from desktop-launched editors.
vim.env.PATH = vim.fn.expand("~/.local/bin") .. ":"
    .. vim.fn.expand("~/.dotnet") .. ":" .. vim.fn.expand("~/.dotnet/tools") .. ":"
    .. vim.fn.expand("~/.local/share/nvim-learning/tools/node_modules/.bin")
    .. ":" .. (vim.env.PATH or "")
if not vim.env.DOTNET_ROOT and vim.fn.isdirectory(vim.fn.expand("~/.dotnet")) == 1 then
    vim.env.DOTNET_ROOT = vim.fn.expand("~/.dotnet")
end
-- CORE OPTIONS
opt.number = false
opt.relativenumber = false
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.wrap = false
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.background = 'dark'
opt.winborder = 'rounded'
opt.signcolumn = "no"
opt.laststatus = 2
opt.updatetime = 50
opt.clipboard = "unnamedplus"
opt.mouse = "a"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.splitright = true
opt.splitbelow = true
opt.confirm = true
opt.grepprg = "rg --vimgrep --smart-case"
opt.grepformat = "%f:%l:%c:%m"
opt.tags = { "./tags;", "tags;" }
opt.timeoutlen = 350

-- GUI istemcileri için de terminalle aynı, sade outline font.
opt.guifont = "Terminus:h24"

g.mapleader = " "
g.maplocalleader = " "


-- Quiet LazyVim defaults, using the installed language tools.
g.autoformat = false
g.snacks_animate = false
g.lazyvim_picker = 'snacks'
g.lazyvim_explorer = 'snacks'
g.lazyvim_cmp = 'blink.cmp'
g.trouble_lualine = false
opt.number = true
opt.relativenumber = false
opt.laststatus = 3
opt.signcolumn = 'yes:1'
opt.numberwidth = 3
opt.updatetime = 250
opt.timeoutlen = 600
opt.list = false
opt.showmode = false
opt.showcmd = false
opt.ruler = false
opt.shortmess:append('I')
opt.fillchars:append({eob = ' '})
