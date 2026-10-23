-- Real compiler/runner; only the debugger launch boundary is intercepted.
local base = vim.fn.tempname() .. " cpp workflow's"
local function check()
  local creator = require('custom.ide.new_project')
  local tasks, dap = require('custom.ide.tasks'), require('dap')
  local root
  creator.create('cpp', base, 'example', function(path, err) assert(path, err); root = path end)
  vim.cmd.edit(vim.fn.fnameescape(root .. '/main.cpp'))
  local task = tasks.run('build', {open=false})
  assert(vim.wait(30000, function() return task:is_complete() end, 20))
  assert(task.status == 'SUCCESS', 'generated C++ build failed')
  assert(vim.fn.filereadable(root .. '/build/compile_commands.json') == 1, 'C++ template must give clangd the actual build commands')
  local launches = {}
  dap.run = function(config) launches[#launches+1] = config end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'#include <iostream>', 'int main() { std::cout << "saved-before-debug"; }'})
  require('custom.ide.debug').start()
  assert(vim.wait(30000, function() return #launches == 1 end, 20), 'F5 did not build and launch generated project')
  assert(not vim.bo.modified and launches[1].program == root .. '/build/app')
  local result = vim.system({launches[1].program}, {text=true}):wait()
  assert(result.code == 0 and result.stdout == 'saved-before-debug', 'F5 launched an outdated program')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'invalid C++ !'})
  require('custom.ide.debug').start()
  assert(vim.wait(30000, function() return tasks.last_task:is_complete() end, 20))
  vim.wait(100)
  assert(tasks.last_task.status == 'FAILURE' and #launches == 1, 'failed build must not launch stale binary')
  assert(#vim.fn.getqflist() > 0, 'compiler errors must be navigable')
  print('PASS C++ compile database, F5 saves/builds/launches, failed compile blocks debugger')
end
local ok, err = xpcall(check, debug.traceback)
vim.cmd('enew!')
vim.fn.delete(base, 'rf')
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
