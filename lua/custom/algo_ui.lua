-- Shared presentation for AtCoder and the vocabulary deck.
local M = {}

function M.panel(title, lines, opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  local function geometry(count)
    local width = math.max(1, math.min(opts.width or 78, vim.o.columns - 4))
    local height = math.max(1, math.min(opts.height or count, vim.o.lines - 4))
    return { relative = 'editor', width = width, height = height,
      row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
      col = math.max(0, math.floor((vim.o.columns - width) / 2)) }
  end
  local config = vim.tbl_extend('force', geometry(#lines), {
    style = 'minimal', border = 'single', title = ' ' .. title .. ' ', title_pos = 'center',
  })
  local win = vim.api.nvim_open_win(buf, true, config)
  vim.wo[win].wrap, vim.wo[win].linebreak = true, true
  vim.wo[win].winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder'
  local view = { buf = buf, win = win }
  function view.close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  function view.map(key, fn)
    vim.keymap.set('n', key, function()
      local ok, err = pcall(fn)
      if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
    end, { buffer = buf, nowait = true, silent = true })
  end
  function view.set(content)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    lines = content
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    vim.bo[buf].modifiable = false
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_config(win, geometry(#content))
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
    end
  end
  local resize = vim.api.nvim_create_autocmd('VimResized', { callback = function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_set_config(win, geometry(#lines)) end
  end })
  vim.api.nvim_create_autocmd('BufWipeout', { buffer = buf, once = true,
    callback = function() pcall(vim.api.nvim_del_autocmd, resize) end })
  view.map('q', view.close)
  view.map('<Esc>', view.close)
  view.set(lines)
  return view
end

function M.select(items, opts, callback)
  require('mini.pick').ui_select(items, opts, function(item, index)
    vim.schedule(function() callback(item, index) end)
  end)
end

function M.input(opts, callback)
  local Input = require('nui.input')
  local input = Input({
    position = '50%', size = { width = math.max(1, math.min(76, vim.o.columns - 4)) },
    border = { style = 'single', text = { top = ' ' .. opts.prompt .. ' ', top_align = 'center' } },
    win_options = { winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder' },
  }, { prompt = '> ', default_value = opts.default or '', on_submit = callback })
  input:mount()
  for _, mode in ipairs({ 'i', 'n' }) do
    input:map(mode, '<Esc>', function() input:unmount() end, { noremap = true })
  end
  input:map('n', 'q', function() input:unmount() end, { noremap = true })
end

return M
