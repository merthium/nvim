local base = vim.fn.tempname() .. " generated [tasks] 'quoted'"
local function check()
  vim.opt.rtp:prepend(vim.fn.stdpath('config'))
  vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/overseer.nvim')
  vim.cmd('filetype on')
  require('overseer').setup()
  local creator, tasks = require('custom.ide.new_project'), require('custom.ide.tasks')
  local function execute(action, expected)
    local task = tasks.run(action, {open=false})
    assert(task, 'no task for ' .. action)
    assert(vim.wait(20000, function() return task:is_complete() end, 20), 'task timed out')
    local output = table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, false), '\n')
    assert(task.status == 'SUCCESS', output)
    if expected then assert(output:find(expected, 1, true), output) end
    return task
  end
  for _, id in ipairs({'javascript', 'python', 'java'}) do
    local root
    creator.create(id, base, 'demo_' .. id, function(path, err) assert(path, err); root = path end)
    local spec = require('custom.ide.templates').render(id, 'demo_' .. id)
    vim.cmd.edit(vim.fn.fnameescape(root .. '/' .. spec.main))
    execute('run', 'Hello, world!')
    if id == 'javascript' then
      execute('test')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'console.log("Fresh unsaved changes");'})
      execute('run', 'Fresh unsaved changes')
      assert(not vim.bo.modified, 'explicit run must save project source')
    elseif id == 'python' then
      execute('test', 'OK')
    elseif id == 'java' then
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'not valid Java'})
      local task = tasks.run('run', {open=false})
      assert(vim.wait(15000, function() return task:is_complete() end, 20))
      local output = table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, false), '\n')
      assert(task.status == 'FAILURE' and not output:find('Hello, world!', 1, true), 'failed compile must stop before stale program runs')
    end
    print('PASS: generated ' .. id .. ' through real IDE runner')
  end
  vim.cmd('enew!')
end
local ok, err = xpcall(check, debug.traceback)
vim.fn.delete(base, 'rf')
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
