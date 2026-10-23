local text_kinds = {Control = 'C', Collapsed = '>', Copilot = 'AI', Unknown = '?'}
for _, names in ipairs({vim.lsp.protocol.SymbolKind, vim.lsp.protocol.CompletionItemKind}) do
  for _, name in ipairs(names) do text_kinds[name] = name:sub(1, 1) end
end

return {
  {'amedoeyes/eyes.nvim', lazy = false, priority = 1000, opts = {
    extend = {highlights = {IDETabHover = {link = 'Visual'}}},
  }},
  {'LazyVim/LazyVim', opts = {
    colorscheme = 'eyes', news = {lazyvim = false, neovim = false},
    icons = {kinds = text_kinds, diagnostics = {Error = 'E', Warn = 'W', Info = 'I', Hint = 'H'},
      git = {added = '+', modified = '~', removed = '-'}},
  }},
  {'folke/noice.nvim', enabled = false},
  {'akinsho/bufferline.nvim', enabled = false},
  {'folke/flash.nvim', enabled = false},
  {'folke/persistence.nvim', enabled = false},
  {'folke/trouble.nvim', keys = {{'<leader>cs', false}, {'<leader>cS', false}}},
  {'folke/tokyonight.nvim', enabled = false},
  {'catppuccin/nvim', enabled = false},
  {'nvim-mini/mini.icons', opts = {style = 'ascii'}},
  {'folke/snacks.nvim', opts = {
    dashboard = {enabled = false}, notifier = {enabled = false},
    indent = {enabled = false}, scroll = {enabled = false}, scope = {enabled = false},
    input = {enabled = true, icon = ''}, statuscolumn = {enabled = false},
    picker = {
      prompt = '> ',
      icons = {files = {enabled = false}, git = {enabled = false}, kinds = text_kinds,
        lsp = {unavailable = '-', enabled = '+', disabled = '-', attached = '*'},
        keymaps = {nowait = '!'}, undo = {saved = 'S'},
        diagnostics = {Error = 'E', Warn = 'W', Info = 'I', Hint = 'H'},
        ui = {live = '*', selected = '+', unselected = ' '}},
      sources = {explorer = {
        title = 'Proje dosyaları',
        layout = {layout = {width = 28, min_width = 28}},
        win = {
          list = {keys = {
            ['q'] = 'close', ['<leader>e'] = 'close', ['<leader>q'] = 'close',
          }},
          input = {keys = {
            ['<leader>e'] = {'close', mode = {'n', 'i'}},
            ['<leader>q'] = {'close', mode = 'n'},
          }},
        },
      }},
    },
    terminal = {win = {position = 'bottom', height = 0.35}},
  }, keys = {{'<leader><space>', false}, {'<leader>n', false}}},
  {'folke/which-key.nvim', opts = function(_, opts)
    opts.delay = 500
    opts.win = vim.tbl_deep_extend('force', opts.win or {}, {border = 'rounded'})
    opts.icons = {mappings = false, group = '+', separator = '->',
      keys = {Space = 'Space', Esc = 'Esc', BS = 'BS', CR = 'Enter', Tab = 'Tab'}}
    opts.spec = {
      {'<leader>c', group = 'Kod / proje'}, {'<leader>r', group = 'Çalıştır / debug'},
      {'<leader>x', group = 'Hatalar'}, {'<leader>b', group = 'Dosyalar / oturum'},
      {'<leader>f', group = 'Dosya bul'},
      {'<leader>m', group = 'Exercism'},
    }
  end},
  {'nvim-lualine/lualine.nvim', opts = function(_, opts)
    local visible = function() return require('custom.ide.ui').has_document() end
    opts.options.icons_enabled = false
    opts.options.component_separators = ''
    opts.options.section_separators = ''
    opts.options.theme = 'eyes'
    -- Compact modes and width-aware detail, inspired by mini.statusline.
    opts.sections = {
      lualine_a = {{'mode', cond = visible, fmt = function(mode) return mode:sub(1, 1) end}},
      lualine_b = {{'branch', cond = function() return visible() and vim.o.columns >= 100 end}},
      lualine_c = {{'filename', path = 1, cond = visible, symbols = {modified = '+', readonly = '-', unnamed = '', newfile = ''}},
        {'diagnostics', cond = visible, symbols = {error = 'E ', warn = 'W ', info = 'I ', hint = 'H '}}},
      lualine_x = {{'filetype', cond = function() return visible() and vim.o.columns >= 100 end}},
      lualine_y = {{'location', cond = visible}}, lualine_z = {},
    }
    opts.inactive_sections = {lualine_a = {}, lualine_b = {},
      lualine_c = {{'filename', cond = visible, symbols = {unnamed = ''}}}, lualine_x = {}, lualine_y = {}, lualine_z = {}}
  end},
  {'mason-org/mason.nvim', opts = {PATH = 'append', ensure_installed = {}},
    config = function(_, opts) require('mason').setup(opts) end},
  -- Existing toolchains are configured explicitly; Mason remains available on demand.
  {'mason-org/mason-lspconfig.nvim', enabled = false},
  {'neovim/nvim-lspconfig', event = {'BufReadPre', 'BufNewFile', 'BufWritePre'}, opts = function(_, opts)
    opts.servers = vim.tbl_deep_extend('force', opts.servers, require('custom.ide.languages').servers())
    -- C# already owns Space cr; rename remains available as Space rn.
    table.insert(opts.servers['*'].keys, {'<leader>cr', false})
    opts.inlay_hints.enabled = false
    opts.diagnostics.virtual_text = false
    opts.diagnostics.float = {border = 'rounded', source = true}
  end},
  {'saghen/blink.cmp', opts = {
    fuzzy = {implementation = 'lua'},
    keymap = {preset = 'enter', ['<Tab>'] = {'snippet_forward', 'select_next', 'fallback'},
      ['<S-Tab>'] = {'snippet_backward', 'select_prev', 'fallback'}},
    signature = {enabled = true, window = {border = 'rounded'}},
    completion = {documentation = {auto_show = true, auto_show_delay_ms = 400, window = {border = 'rounded'}},
      menu = {border = 'rounded', draw = {columns = {{'label', 'label_description'}, {'kind'}}}},
      list = {selection = {preselect = true, auto_insert = false}}, ghost_text = {enabled = false}},
    cmdline = {enabled = false},
  }},
  {'nvim-treesitter/nvim-treesitter', opts = function(_, opts)
    opts.ensure_installed = {}
    opts.folds = {enable = false}
  end},
  {'stevearc/conform.nvim', opts = {formatters_by_ft = {
    lua = {'stylua'}, python = {'ruff_format'}, c = {'clang_format'}, cpp = {'clang_format'},
    rust = {'rustfmt'}, zig = {'zigfmt'}, go = {'gofmt'}, sh = {'shfmt'}, bash = {'shfmt'},
    javascript = {'prettier'}, typescript = {'prettier'}, json = {'prettier'},
  }}},
  {'stevearc/overseer.nvim', cmd = {'OverseerRun', 'OverseerToggle'}, opts = {
    task_list = {direction = 'bottom', min_height = 8, max_height = 12},
  }},
  {'mfussenegger/nvim-dap', lazy = true, config = function() require('custom.ide.debug').setup() end,
    dependencies = {'mfussenegger/nvim-dap-python', 'igorlfs/nvim-dap-view'}},
  {'mfussenegger/nvim-dap-python', lazy = true},
  {'igorlfs/nvim-dap-view', lazy = true, opts = {windows = {size = 0.35}}},
  {'yioneko/nvim-vtsls', ft = {'javascript', 'javascriptreact', 'typescript', 'typescriptreact'}},
  {'mfussenegger/nvim-jdtls', ft = 'java', config = function() require('custom.ide.languages').java() end},
  {'mrcjkb/rustaceanvim', lazy = false, init = function()
    vim.g.rustaceanvim = {
      server = {
        capabilities = {workspace = {fileOperations = require('custom.ide.languages').file_operations()}},
        cmd_env = {RUST_SRC_PATH = vim.fn.expand('~/.local/share/nvim-learning/toolchains/rust-src-1.98.0/rust-src/lib/rustlib/src/rust/library')},
        before_init = function(_, config)
          if config.init_options and config.init_options.detachedFiles then
            config.init_options.checkOnSave = false
            config.settings['rust-analyzer'].checkOnSave = false
          end
        end,
        default_settings = {['rust-analyzer'] = {check = {command = 'check'},
          cargo = {allTargets = true, sysrootSrc = vim.fn.expand('~/.local/share/nvim-learning/toolchains/rust-src-1.98.0/rust-src/lib/rustlib/src/rust/library')}}},
      },
    }
  end},
}
