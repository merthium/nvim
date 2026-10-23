-- Workflow references: JakeAtLinux/nvim, ThePrimeagen/harpoon, tjdevries/config.nvim.
local function project_list()
  return require('harpoon'):list(require('custom.ide.project').root())
end

return {
  {
    'ThePrimeagen/harpoon', branch = 'harpoon2', dependencies = {'nvim-lua/plenary.nvim'},
    keys = (function()
      local keys = {
        {'<leader>ba', function()
          local name = vim.api.nvim_buf_get_name(0)
          if vim.bo.buftype ~= '' or name == '' then return end
          project_list():add()
          vim.notify('Hızlı erişime eklendi: ' .. vim.fs.basename(name))
        end, desc = 'Dosyayı hızlı erişime ekle'},
        {'<leader>bh', function()
          local h = require('harpoon')
          h.ui:toggle_quick_menu(project_list())
        end, desc = 'Projenin sabit dosyaları'},
      }
      for i = 1, 5 do
        keys[#keys + 1] = {'<leader>' .. i, function() project_list():select(i) end,
          desc = 'Sabit dosya ' .. i}
      end
      return keys
    end)(),
    opts = {
      settings = {key = function() return 'ide-project-files-v1' end, sync_on_ui_close = true},
      default = {
        -- Absolute paths keep marks valid when the editor cwd is outside the project.
        create_list_item = function(_, name)
          local pos = vim.api.nvim_win_get_cursor(0)
          return {value = name or vim.api.nvim_buf_get_name(0), context = {row = pos[1], col = pos[2]}}
        end,
        BufLeave = function(event, list)
          local item = list:get_by_value(vim.api.nvim_buf_get_name(event.buf))
          if item then
            local pos = vim.api.nvim_win_get_cursor(0)
            item.context.row, item.context.col = pos[1], pos[2]
          end
        end,
      },
    },
  },
  {
    'stevearc/oil.nvim', cmd = 'Oil',
    keys = {{'-', '<cmd>Oil<cr>', desc = 'Üst klasörü düzenle (taşı / yeniden adlandır)'}},
    opts = {skip_confirm_for_simple_edits = false, view_options = {show_hidden = true},
      keymaps = {['<C-h>'] = false, ['<C-j>'] = false, ['<C-k>'] = false, ['<C-l>'] = false}},
  },
  {'folke/snacks.nvim', opts = {picker = {sources = {projects = {
    dev = {'~/code', '~/Projects'}, max_depth = 6,
    patterns = {'.git', '.nvim-project.json', 'CMakeLists.txt', 'Makefile', 'Cargo.toml', 'package.json', 'pyproject.toml'},
    confirm = function(picker, item)
      if not item then return end
      local root = item.file
      picker:close()
      vim.schedule(function()
        vim.cmd.tcd(vim.fn.fnameescape(root))
        Snacks.picker.files({cwd = root})
      end)
    end,
  }}}}},
}
