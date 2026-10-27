-- Run: nvim --headless -u NONE -i NONE -l tests/ctrl_arrows.lua
local child = vim.fn.jobstart({vim.v.progpath, '--embed', '--headless', '-i', 'NONE'}, {rpc = true})
local function rpc(method, ...) return vim.rpcrequest(child, method, ...) end
local function lua(code) return rpc('nvim_exec_lua', code, {}) end
local function key(value)
  rpc('nvim_input', value)
  vim.wait(70)
end
local lines = {'top', 'top', '', 'first', 'middle', 'last', '', 'next', 'next', '', 'end'}
local ok, err = xpcall(function()
  rpc('nvim_ui_attach', 90, 30, {rgb = true})
  lua([[require('lazyvim.config').load('keymaps')]])
  rpc('nvim_buf_set_lines', 0, 0, -1, false, lines)
  for _, case in ipairs({{'', 'n'}, {'i', 'i'}, {'v', 'v'}, {'gh', 's'}}) do
    for _, motion in ipairs({{'<C-Up>', 3}, {'<C-Down>', 7}}) do
      key('<Esc>')
      rpc('nvim_win_set_cursor', 0, {5, 0})
      if case[1] ~= '' then key(case[1]) end
      key(motion[1])
      assert(rpc('nvim_win_get_cursor', 0)[1] == motion[2], case[2] .. ' ' .. motion[1] .. ': wrong block boundary')
      assert(rpc('nvim_get_mode').mode == case[2], 'navigation changed mode')
      assert(vim.deep_equal(rpc('nvim_buf_get_lines', 0, 0, -1, false), lines), 'navigation inserted text')
    end
  end
  key('<Esc>')
  rpc('nvim_win_set_cursor', 0, {5, 0})
  key('i')
  key('<C-Down>')
  key('<C-Down>')
  assert(rpc('nvim_win_get_cursor', 0)[1] == 10, 'repeated Ctrl+Down did not reach next boundary')
  key('<C-Up>')
  key('<C-Up>')
  assert(rpc('nvim_win_get_cursor', 0)[1] == 3, 'repeated Ctrl+Up did not reach previous boundary')
  for _, case in ipairs({{1, '<C-Up>'}, {#lines, '<C-Down>'}}) do
    rpc('nvim_win_set_cursor', 0, {case[1], 0})
    key(case[2])
    assert(rpc('nvim_win_get_cursor', 0)[1] == case[1], 'file boundary navigation moved unexpectedly')
  end
  assert(vim.deep_equal(rpc('nvim_buf_get_lines', 0, 0, -1, false), lines), 'repeated navigation changed text')
  assert(lua([[return vim.v.errmsg]]) == '', 'Neovim reported an error')
  print('PASS Ctrl+Up/Down: block boundaries, repeat, file edges, normal/insert/visual/select modes; no text inserted')
end, debug.traceback)
vim.fn.jobstop(child)
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
