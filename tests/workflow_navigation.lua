local base = vim.fn.tempname() .. ' navigation'
local function check()
  require('lazy').load({plugins={'harpoon', 'oil.nvim'}})
  require('lazyvim.config').load('keymaps')
  local h = require('harpoon')
  local function list() return h:list(require('custom.ide.project').root()) end
  local root1, root2 = base .. '/one', base .. '/two'
  for _, root in ipairs({root1, root2}) do
    vim.fn.mkdir(root, 'p')
    vim.fn.writefile({'all:'}, root .. '/Makefile')
    vim.fn.writefile({'one', 'two', 'three'}, root .. '/main.cpp')
    vim.fn.writefile({'#pragma once'}, root .. '/helper.hpp')
  end
  vim.cmd.cd('/tmp')
  vim.cmd.edit(root1 .. '/main.cpp')
  list():add()
  vim.api.nvim_win_set_cursor(0, {3, 0})
  vim.cmd.edit(root1 .. '/helper.hpp')
  list():add()
  list():select(1)
  assert(vim.api.nvim_buf_get_name(0) == root1 .. '/main.cpp', 'mark must resolve outside cwd')
  vim.cmd.edit(root2 .. '/main.cpp')
  list():add()
  assert(list():length() == 1, 'second project must have independent marks')
  vim.cmd.edit(root1 .. '/helper.hpp')
  assert(list():length() == 2, 'first project marks must survive project switching')
  list():select(1)
  assert(vim.api.nvim_buf_get_name(0) == root1 .. '/main.cpp')
  h:sync()
  local child_code = "require('lazy').load({plugins={'harpoon'}}); local h=require('harpoon'); "
    .. "assert(h:list(" .. string.format('%q', root2) .. "):length()==1); "
    .. "assert(h:list(" .. string.format('%q', root1) .. "):length()==2)"
  local child = vim.system({'nvim', '--headless', '-u', vim.fn.stdpath('config') .. '/init.lua',
    '-c', 'lua ' .. child_code, '-c', 'qa!'}, {text=true}):wait(10000)
  assert(child.code == 0, 'marks must persist across restart and reverse project order: ' .. (child.stderr or ''))
  local setup = vim.fn.maparg('<leader>ri', 'n', false, true)
  assert(setup.desc == 'Proje bağımlılıklarını kur', 'debug step must not shadow dependency setup')
  assert(vim.fn.maparg('<leader>rj', 'n', false, true).desc == 'Debug: fonksiyona gir')
  for _, root in ipairs({root1, root2}) do
    vim.cmd.edit(root .. '/main.cpp')
    list():clear()
  end
  print('PASS absolute file navigation, independent project marks and setup/debug shortcuts')
end
local ok, err = xpcall(check, debug.traceback)
vim.cmd('enew!')
vim.fn.delete(base, 'rf')
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
