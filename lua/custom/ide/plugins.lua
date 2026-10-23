return {
  {'mason-org/mason.nvim', lazy = false, opts = {PATH = 'append', ui = {border = 'single'}}},
  {'nvim-mini/mini.extra', lazy = true, dependencies = {'nvim-mini/mini.pick'}, opts = {}},
  {'rafamadriz/friendly-snippets', lazy = true},
  {'folke/which-key.nvim', event = 'VeryLazy', opts = {
    delay = 450, preset = 'classic', icons = {mappings = false, group = '+', separator = '->'},
    spec = {{'<leader>c', group = 'Kod / proje'}, {'<leader>r', group = 'Çalıştır / debug'},
      {'<leader>x', group = 'Hatalar'}, {'<leader>b', group = 'Dosyalar / oturum'}, {'<leader>m', group = 'AtCoder'}},
  }},
  {'stevearc/oil.nvim', cmd = 'Oil', opts = {
    columns = {}, delete_to_trash = true, skip_confirm_for_simple_edits = false,
    lsp_file_methods = {enabled = true, timeout_ms = 3000, autosave_changes = false},
    view_options = {show_hidden = true},
    keymaps = {['q'] = 'actions.close', ['<Esc>'] = 'actions.close'},
  }},
  {'folke/trouble.nvim', cmd = 'Trouble', opts = {focus = true, auto_preview = false}},
  {'j-hui/fidget.nvim', event = 'LspAttach', opts = {
    progress = {display = {progress_icon = {'line'}, done_icon = 'OK'}},
    notification = {window = {winblend = 0, border = 'none', normal_hl = 'Comment'}},
  }},
  {'nvim-lualine/lualine.nvim', event = 'VeryLazy', opts = {
    options = {icons_enabled = false, theme = {
      normal = {a = {fg = '#101510', bg = '#b8c7ad'}, b = {fg = '#bcbcbc', bg = '#171717'}, c = {fg = '#a0a0a0', bg = '#0b0b0b'}},
      insert = {a = {fg = '#101510', bg = '#a0b7c5'}}, visual = {a = {fg = '#101510', bg = '#d8bc83'}},
      inactive = {a = {fg = '#777777', bg = '#0b0b0b'}, b = {fg = '#777777', bg = '#0b0b0b'}, c = {fg = '#777777', bg = '#0b0b0b'}},
    }, component_separators = '', section_separators = '', globalstatus = true},
    sections = {lualine_a = {'mode'}, lualine_b = {'branch'}, lualine_c = {{'filename', path = 1}, {'diagnostics', symbols = {error = 'E:', warn = 'W:', info = 'I:', hint = 'H:'}}},
      lualine_x = {function() return require('custom.ide').status() end, 'filetype'}, lualine_y = {'progress'}, lualine_z = {'location'}},
    extensions = {'quickfix', 'oil', 'overseer'},
  }},
  {'stevearc/conform.nvim', cmd = 'ConformInfo', opts = {
    notify_on_error = true,
    formatters_by_ft = {
      lua = {'stylua'}, python = {'ruff_format'}, c = {'clang_format'}, cpp = {'clang_format'},
      rust = {'rustfmt'}, zig = {'zigfmt'}, go = {'gofmt'}, sh = {'shfmt'}, bash = {'shfmt'},
      javascript = {'prettier'}, javascriptreact = {'prettier'}, typescript = {'prettier'}, typescriptreact = {'prettier'},
      json = {'prettier'}, jsonc = {'prettier'}, html = {'prettier'}, css = {'prettier'}, yaml = {'prettier'}, markdown = {'prettier'},
    },
  }},
  {'stevearc/overseer.nvim', cmd = {'OverseerRun', 'OverseerToggle'}, opts = {
    task_list = {direction = 'bottom', min_height = 8, max_height = 14},
  }},
  {'mfussenegger/nvim-dap', lazy = true, config = function() require('custom.ide.debug').setup() end,
    dependencies = {'mfussenegger/nvim-dap-python', 'igorlfs/nvim-dap-view'}},
  {'mfussenegger/nvim-dap-python', lazy = true},
  {'igorlfs/nvim-dap-view', lazy = true, opts = {}},
  {'yioneko/nvim-vtsls', ft = {'javascript', 'javascriptreact', 'typescript', 'typescriptreact'}},
  {'mfussenegger/nvim-jdtls', ft = 'java', config = function() require('custom.ide.languages').java() end},
  {'mrcjkb/rustaceanvim', lazy = false, init = function()
    vim.g.rustaceanvim = {
      server = {capabilities = {workspace = {fileOperations = require('custom.ide.languages').file_operations()}},
        cmd_env = {RUST_SRC_PATH = vim.fn.expand('~/.local/share/nvim-learning/toolchains/rust-src-1.98.0/rust-src/lib/rustlib/src/rust/library')},
        before_init = function(_, config)
          if config.init_options and config.init_options.detachedFiles then
            -- Cargo's single-file check needs nightly; native build handles standalone files.
            config.init_options.checkOnSave = false
            config.settings['rust-analyzer'].checkOnSave = false
          end
        end,
        default_settings = {['rust-analyzer'] = {
        check = {command = 'check'}, cargo = {allTargets = true,
          sysrootSrc = vim.fn.expand('~/.local/share/nvim-learning/toolchains/rust-src-1.98.0/rust-src/lib/rustlib/src/rust/library')},
      }}},
    }
  end},
}
