local child
local base = vim.fn.tempname() .. ' project menu [a]'
local function check()
  child = vim.fn.jobstart({'nvim', '--embed', '--headless', '-i', 'NONE'}, {rpc=true})
  local function rpc(method, ...) return vim.rpcrequest(child, method, ...) end
  local function lua(code, args) return rpc('nvim_exec_lua', code, args or {}) end
  local function wait(fn, reason)
    if not vim.wait(5000, fn, 20) then
      error(reason .. '\n' .. lua([[local p=Snacks.picker.get()[1]; return vim.inspect({mode=vim.fn.mode(),current=p and p:current(),count=p and p:count(),messages=vim.fn.execute('messages')})]]))
    end
  end
  rpc('nvim_ui_attach', 130, 40, {rgb=true})
  wait(function() return lua([[return vim.fn.exists(':IDERun')]]) == 2 end, 'startup')
  rpc('nvim_input', '<C-n>')
  wait(function() return lua([[local p=Snacks.picker.get()[1]; return p and p:count()==33 or false]]) end, 'Ctrl+n must show all 33 templates')
  rpc('nvim_input', 'react')
  wait(function() return lua([[local p=Snacks.picker.get()[1]; local i=p and p:current(); return p and p.input.filter.pattern=='react' and i and i.item.id=='react' or false]]) end, 'language chooser must be searchable')
  rpc('nvim_input', '<CR>')
  wait(function() return lua([[return vim.bo.filetype]]) == 'snacks_input' end, 'project name prompt')
  rpc('nvim_input', 'menu_demo<CR>')
  wait(function() return lua([[return vim.api.nvim_get_current_line()]]) == '~/Projeler' end, 'project location prompt')
  rpc('nvim_input', '<C-u>' .. base .. '<CR>')
  wait(function() return lua([[return vim.api.nvim_buf_get_name(0)]]) == base .. '/menu_demo/src/main.tsx' end, 'wizard must open React entry source')
  assert(vim.fn.filereadable(base .. '/menu_demo/package.json') == 1, 'React project manifest')
  assert(vim.fn.filereadable(base .. '/menu_demo/.nvim-project.json') == 1, 'IDE task manifest')
  assert(lua([[return require('custom.ide.project').root()]]) == base .. '/menu_demo', 'new project root')
  assert(lua([[return vim.v.errmsg]]) == '', 'wizard must have no runtime errors')
  rpc('nvim_input', '<Space>cn')
  wait(function() return lua([[return #Snacks.picker.get()>0]]) end, 'Space cn alias remains available')
  lua([[Snacks.picker.get()[1]:close()]])
  assert(lua([[return vim.fn.getcwd()]]) == base .. '/menu_demo', 'cancel must retain project')
  print('PASS: actual Ctrl+n, 33 searchable templates, React wizard, entry source/root, Space cn alias, cancellation')
end
local ok, err = xpcall(check, debug.traceback)
if child then vim.fn.jobstop(child) end
vim.fn.delete(base, 'rf')
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
