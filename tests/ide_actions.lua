-- nvim --headless -u NONE -i NONE -l ~/.config/nvim/tests/ide_actions.lua
-- A real child, terminal, clangd and pickers catch root, capability and mapping errors.
local child
local base = vim.fn.tempname() .. ' ide actions [a]'
local function check()
  local root = base .. '/project'
  vim.fn.mkdir(root .. '/src', 'p')
  vim.fn.mkdir(base .. '/elsewhere', 'p')
  vim.fn.writefile({'all:'}, root .. '/Makefile')
  local file = root .. '/src/main.cpp'
  vim.fn.writefile({'int answer() { return 42; }', 'int main() { return answer(); }'}, file)
  child = vim.fn.jobstart({'nvim', '--embed', '--headless', '-i', 'NONE', file}, {rpc = true, cwd = base .. '/elsewhere'})
  local function rpc(method, ...) return vim.rpcrequest(child, method, ...) end
  local function lua(code, args) return rpc('nvim_exec_lua', code, args or {}) end
  rpc('nvim_ui_attach', 120, 40, {rgb = true})
  local function wait(predicate, message, timeout)
    assert(vim.wait(timeout or 4000, predicate, 20), message .. '\n' .. vim.inspect(lua([[
      local windows = {}
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        windows[#windows + 1] = {ft = vim.bo[buf].filetype, name = vim.api.nvim_buf_get_name(buf)}
      end
      return {mode = vim.fn.mode(), error = vim.v.errmsg, windows = windows, messages = vim.fn.execute('messages')}
    ]])))
  end
  rpc('nvim_command', 'doautocmd User VeryLazy')
  wait(function() return lua([[return vim.fn.exists(':IDERun')]]) == 2 end, 'keymaps must load')
  rpc('nvim_input', '<F7>')
  wait(function() return lua([[return vim.bo.buftype]]) == 'terminal' end, 'F7 must open the project terminal')
  local terminal = lua([[return vim.api.nvim_get_current_buf()]])
  rpc('nvim_input', "printf '\\nIDE_CWD=%s\\n' \"$PWD\"<CR>")
  wait(function()
    return lua([[return table.concat(vim.api.nvim_buf_get_lines(..., 0, -1, false), '\n')]], {terminal}):find('IDE_CWD=' .. root, 1, true)
  end, 'terminal process must start at file project, not unrelated editor cwd')
  rpc('nvim_input', '<F7>')
  wait(function() return lua([[return vim.api.nvim_buf_get_name(0)]]) == file end, 'F7 in terminal input must return to source')
  rpc('nvim_input', '<F7>')
  wait(function() return lua([[return vim.api.nvim_get_current_buf()]]) == terminal end, 'F7 must reuse its project terminal')
  rpc('nvim_input', '<F7>')
  wait(function() return lua([[return vim.api.nvim_buf_get_name(0)]]) == file end, 'terminal closes again')

  wait(function()
    return lua([[local c = vim.lsp.get_clients({bufnr = 0, name = 'clangd'})[1]; return c and c.initialized or false]])
  end, 'real clangd must attach', 10000)
  rpc('nvim_input', 'gO')
  wait(function()
    return lua([[local p = Snacks.picker.get()[1]; return p and p:count() >= 2 or false]])
  end, 'gO must show document symbols from clangd')
  assert(lua([[local p = Snacks.picker.get()[1]; return p:cwd()]]) == root, 'symbol picker must use project root')
  lua([[Snacks.picker.get()[1]:close()]])
  rpc('nvim_input', '<Esc>')
  lua([[vim.api.nvim_win_set_cursor(0, {1, 4})]])
  rpc('nvim_input', '<F2>')
  wait(function() return lua([[return vim.bo.filetype]]) == 'snacks_input' end, 'F2 must request symbol name')
  rpc('nvim_input', '<C-u>result<CR>')
  wait(function()
    return lua([[return table.concat(vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, false), '\n')]], {file})
      == 'int result() { return 42; }\nint main() { return result(); }'
  end, 'F2 must apply clangd rename to definition and use')
  rpc('nvim_input', '<Esc>')
  rpc('nvim_command', 'write')
  rpc('nvim_input', '<Space>co')
  wait(function() return lua([[return require('trouble').is_open('symbols')]]) end, 'outline must open on demand')
  lua([[require('custom.ide.actions').outline()]])
  wait(function() return not lua([[return require('trouble').is_open('symbols')]]) end, 'outline must close on demand')

  rpc('nvim_command', 'IDEInfo')
  local info = lua([[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]])
  assert(info:find(root, 1, true) and info:find('clangd', 1, true), 'IDEInfo must report current project and attached language server')
  rpc('nvim_input', 'q')
  rpc('nvim_command', 'enew')
  lua([[vim.bo.filetype = 'text'; _G.ide_notice = nil; vim.notify = function(msg) _G.ide_notice = msg end]])
  rpc('nvim_input', '<F4>')
  wait(function() return lua([[return _G.ide_notice]]) ~= vim.NIL end, 'unsupported code actions must provide feedback')
  assert(lua([[return _G.ide_notice]]):find(':IDEInfo', 1, true), 'unsupported action must point to actionable language status')
  assert(lua([[return #vim.api.nvim_list_wins()]]) == 1, 'missing server must not open an empty panel')
  assert(lua([[return vim.v.errmsg]]) == '', 'IDE actions must not produce runtime errors')
  print('PASS: real project terminal/reuse, clangd symbols and rename, optional outline, current-file health, missing-server feedback')
end
local ok, err = xpcall(check, debug.traceback)
if child then vim.fn.jobstop(child) end
vim.fn.delete(base, 'rf')
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
