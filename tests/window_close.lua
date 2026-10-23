-- Exercise the real close mapping with normal and floating windows.
local child = vim.fn.jobstart({'nvim', '--embed', '--headless', '-i', 'NONE'}, {rpc = true})
local function rpc(method, ...) return vim.rpcrequest(child, method, ...) end
local function lua(code) return rpc('nvim_exec_lua', code, {}) end
local ok, err = xpcall(function()
  rpc('nvim_ui_attach', 80, 30, {rgb = true})
  assert(vim.wait(5000, function() return lua([[return vim.fn.exists(':IDERun')]]) == 2 end, 20))
  lua([[
    local api = vim.api
    local close = vim.fn.maparg('q', 'n', false, true).callback
    local source = api.nvim_get_current_win()
    api.nvim_buf_set_lines(0, 0, -1, false, {'unsaved work'})
    local buf = api.nvim_create_buf(false, true)
    local floating = api.nvim_open_win(buf, false, {
      relative = 'editor', width = 20, height = 3, row = 2, col = 3, style = 'minimal',
    })
    local success, failure = pcall(close)
    assert(success, 'closing the last editor with a popup must not raise E444: ' .. tostring(failure))
    assert(api.nvim_win_is_valid(source), 'last editor must stay open')
    assert(vim.bo.modified and api.nvim_get_current_line() == 'unsaved work', 'unsaved work must be preserved')
    api.nvim_set_current_win(floating)
    close()
    assert(not api.nvim_win_is_valid(floating), 'focused popup must still close')
    api.nvim_set_current_win(source)
    vim.cmd('vnew')
    local split = api.nvim_get_current_win()
    close()
    assert(not api.nvim_win_is_valid(split) and api.nvim_win_is_valid(source), 'ordinary split must close')
    vim.cmd('tabnew')
    local tab = api.nvim_get_current_tabpage()
    close()
    assert(not api.nvim_tabpage_is_valid(tab) and api.nvim_win_is_valid(source), 'last window in a second tab must close')
  ]])
  print('PASS: last editor with popup, unsaved work, popup/split/second-tab close')
end, debug.traceback)
vim.fn.jobstop(child)
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
