-- Drive the full configuration through a real Neovim UI/RPC connection.
local child
local base = vim.fn.tempname() .. ' lazyvim ui'
local function check()
  vim.fn.mkdir(base, 'p')
  local file = base .. '/hello.asm'
  vim.fn.writefile({
    'section .rodata', '    mesaj db "Hello, world!", 10', '    uzunluk equ $ - mesaj',
    '', 'section .text', '    global _start', '', '_start:',
    '    mov rax, 1', '    mov rdi, 1', '    mov rsi, mesaj', '    mov rdx, uzunluk',
    '    syscall', '', '    mov rax, 60', '    mov rdi, 0', '    syscall',
  }, file)
  child = vim.fn.jobstart({'nvim', '--embed', '--headless', '-i', 'NONE', file}, {rpc = true})
  local function rpc(method, ...) return vim.rpcrequest(child, method, ...) end
  local function lua(code, args) return rpc('nvim_exec_lua', code, args or {}) end
  rpc('nvim_command', 'doautocmd User VeryLazy')
  assert(vim.wait(5000, function() return lua([[return vim.fn.exists(':IDERun')]]) == 2 end, 10), 'Run key setup timed out')
  assert(lua([[return LazyVim ~= nil and Snacks ~= nil]]), 'Full LazyVim foundation must load')
  for i = 1, 3 do
    local previous = lua([[local t = require('custom.ide.tasks').last_task; return t and t.id or -1]])
    rpc('nvim_input', '<F6>')
    assert(vim.wait(10000, function()
      return lua([[local t = require('custom.ide.tasks').last_task; return t and t.id ~= ... and t:is_complete()]], {previous})
    end, 10), 'F6 did not finish a new run')
    local state = lua([[
      local task = require('custom.ide.tasks').last_task
      local terminals = 0
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buftype == 'terminal' then terminals = terminals + 1 end
      end
      return {status = task.status, windows = #vim.api.nvim_list_wins(), terminals = terminals,
        current = vim.api.nvim_buf_get_name(0),
        output = table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, false), '\n'),
        error = vim.v.errmsg}
    ]])
    assert(state.status == 'SUCCESS' and state.output:find('Hello, world!', 1, true), vim.inspect(state))
    assert(state.windows == 2 and state.terminals == 1 and state.current == file, vim.inspect(state))
    assert(state.error == '', state.error)
  end
  rpc('nvim_input', '<Space>rl')
  assert(vim.wait(1000, function() return lua([[return #vim.api.nvim_list_wins()]]) == 1 end, 10), 'Output toggle must close panel')
  rpc('nvim_input', '<Space>rl')
  assert(vim.wait(1000, function() return lua([[return #vim.api.nvim_list_wins()]]) == 2 end, 10), 'Output toggle must reopen existing panel')
  rpc('nvim_input', '<Space>?')
  assert(vim.wait(1000, function() return lua([[return #vim.api.nvim_list_wins()]]) >= 3 end, 10), 'Daily help must open')
  rpc('nvim_input', 'q')
  assert(vim.wait(1000, function() return lua([[return #vim.api.nvim_list_wins()]]) == 2 end, 10), 'Daily help must close')
  assert(lua([[return vim.v.errmsg]]) == '', 'No startup or UI errors expected')
  print('PASS: full LazyVim UI, actual F6 input x3, one output, source focus, toggle and concise help')
end
local ok, err = xpcall(check, debug.traceback)
if child then vim.fn.jobstop(child) end
vim.fn.delete(base, 'rf')
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
