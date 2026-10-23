local M = {}
local held = false

function M.extend()
  if not held or vim.fn.mode() ~= 'v' then return end
  local mouse = vim.fn.getmousepos()
  if mouse.winid == vim.api.nvim_get_current_win() and mouse.line > 0 and mouse.column > 0 then
    vim.api.nvim_win_set_cursor(0, {mouse.line, mouse.column - 1})
  end
end

-- Only terminals take focus on hover; code windows never take focus from the mouse alone.
-- Do not steal focus from prompts, selections, or an active mouse drag.
function M.follow_terminal()
  local mode = vim.fn.mode()
  if held or not (mode == 'n' or mode == 'i' or mode == 't') or vim.fn.pumvisible() == 1 then return end
  local mouse = vim.fn.getmousepos()
  local target, current = mouse.winid, vim.api.nvim_get_current_win()
  local function focusable(win)
    if vim.api.nvim_win_get_config(win).relative == '' then return true end
    -- Explorer lists may be floating children of a split layout.
    if _G.Snacks and Snacks.picker then
      for _, picker in ipairs(Snacks.picker.get({source = 'explorer'})) do
        if picker.list and picker.list.win and picker.list.win.win == win then return true end
      end
    end
    return false
  end
  if target == 0 or not vim.api.nvim_win_is_valid(target)
      or mouse.winrow < 1 or mouse.winrow > vim.api.nvim_win_get_height(target)
      or not focusable(current) or not focusable(target) then return end
  local buf = vim.api.nvim_win_get_buf(target)
  local terminal = vim.bo[buf].buftype == 'terminal'
  if not terminal then return end
  if target ~= current then
    if mode == 't' then vim.cmd.stopinsert() end
    vim.api.nvim_set_current_win(target)
  end
  local job = vim.b[buf].terminal_job_id
  if terminal and job and vim.fn.jobwait({job}, 0)[1] == -1 then vim.cmd.startinsert() end
end

-- Decide q's destination from pointer coordinates, not keyboard focus.
function M.explorer_under_mouse()
  if not (_G.Snacks and Snacks.picker) then return end
  local mouse = vim.fn.getmousepos()
  for _, picker in ipairs(Snacks.picker.get({source = 'explorer'})) do
    if picker:on_current_tab() then
      for _, part in ipairs({'list', 'input'}) do
        local win = picker[part] and picker[part].win and picker[part].win.win
        if win and vim.api.nvim_win_is_valid(win) then
          local pos = vim.api.nvim_win_get_position(win)
          if mouse.screenrow > pos[1] and mouse.screenrow <= pos[1] + vim.api.nvim_win_get_height(win)
              and mouse.screencol > pos[2] and mouse.screencol <= pos[2] + vim.api.nvim_win_get_width(win) then
            return picker
          end
        end
      end
    end
  end
end

function M.close_hovered_explorer()
  local picker = M.explorer_under_mouse()
  if picker then picker:close() end
end

function M.q()
  if M.explorer_under_mouse() then
    return '<Cmd>lua require("custom.mouse").close_hovered_explorer()<CR>'
  end
  -- In code, q is text in insert mode; in normal mode it never closes a window.
  return vim.fn.mode() == 'n' and '<Ignore>' or 'q'
end

function M.setup()
  for _, event in ipairs({'LeftMouse', 'LeftDrag', 'LeftRelease'}) do
    vim.keymap.set({'n', 'i', 'x'}, '<' .. event .. '>', function()
      held = event ~= 'LeftRelease'
      return '<' .. event .. '>'
    end, {expr = true, silent = true, desc = 'Fareyle seçim takibi'})
  end
  for _, direction in ipairs({'Up', 'Down'}) do
    local key = '<ScrollWheel' .. direction .. '>'
    vim.keymap.set('x', key, function()
      return key .. (held and '<Cmd>lua require("custom.mouse").extend()<CR>' or '')
    end, {expr = true, silent = true, desc = 'Kaydırırken fare seçimini uzat'})
  end
  vim.api.nvim_create_autocmd({'FocusLost', 'BufLeave'}, {
    group = vim.api.nvim_create_augroup('LocalMouseSelection', {clear = true}),
    callback = function() held = false end,
  })
end

return M
