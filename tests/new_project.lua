local function check()
  vim.opt.rtp:prepend(vim.fn.stdpath('config'))
  vim.g.mapleader = ' '
  vim.cmd('filetype on')
  local loaded, new = pcall(require, 'custom.ide.new_project')
  assert(loaded, 'project creation module must be available')
  local base = vim.fn.tempname() .. ' projects [test]'
  vim.fn.mkdir(base, 'p')
  local function create(language, name)
    local finished, root, err = false
    new.create(language, base, name, function(path, message)
      finished, root, err = true, path, message
    end)
    assert(vim.wait(30000, function() return finished end, 20), 'creation timed out')
    return root, err
  end
  local registry = require('custom.ide.templates')
  local config = require('custom.ide.project_config')
  local old_executable, old_system = vim.fn.executable, vim.system
  vim.fn.executable = function() return 0 end
  vim.system = function() error('offline scaffolding must never launch a process') end
  for _, item in ipairs(registry.list()) do
    local root, err = create(item.id, 'offline_' .. item.id)
    assert(root, item.id .. ': ' .. tostring(err))
    assert(vim.fn.filereadable(root .. '/' .. item.main) == 1, 'missing entry point: ' .. item.id)
    local data, problem = config.load(root)
    assert(data and data.template == item.id, item.id .. ': ' .. tostring(problem))
    local vscode = vim.json.decode(table.concat(vim.fn.readfile(root .. '/.vscode/tasks.json'), '\n'))
    assert(vscode.version == '2.0.0' and #vscode.tasks > 0, 'VS Code/Overseer tasks must exist')
    vim.cmd.edit(vim.fn.fnameescape(root .. '/' .. item.main))
    assert(require('custom.ide.project').root() == root, item.id .. ': nested source must resolve to project')
  end
  vim.fn.executable, vim.system = old_executable, old_system
  print('PASS: all 33 projects create offline without SDKs; task manifests and source roots work')
  local cases = {
    {'csharp', 'Program.cs', {'dotnet', 'run', '--no-launch-profile'}},
    {'cpp', 'main.cpp', {'make', 'run'}},
    {'c', 'main.c', {'make', 'run'}},
    {'rust', 'src/main.rs', {'cargo', 'run', '--offline', '--quiet'}},
    {'python', 'main.py', {'python3', 'main.py'}},
    {'go', 'main.go', {'go', 'run', '.'}},
    {'asm', 'main.asm', {'make', 'run'}},
  }
  for _, case in ipairs(cases) do
    local root, err = create(case[1], 'demo_' .. case[1])
    assert(root, err)
    assert(vim.fn.filereadable(root .. '/' .. case[2]) == 1, 'missing source for ' .. case[1])
    vim.cmd.edit(vim.fn.fnameescape(root .. '/' .. case[2]))
    assert(require('custom.ide.project').root() == root, 'wrong project root for ' .. case[1])
    local result = vim.system(case[3], {cwd = root, text = true}):wait(60000)
    assert(result.code == 0, case[1] .. ': ' .. (result.stderr or '') .. (result.stdout or ''))
    assert(result.stdout:lower():find('hello', 1, true), case[1] .. ' starter must run')
    print('PASS: create and run ' .. case[1])
  end
  local original = base .. '/demo_python/main.py'
  vim.fn.writefile({'print("keep my edits")'}, original)
  local duplicate = create('python', 'demo_python')
  assert(not duplicate and vim.fn.readfile(original)[1] == 'print("keep my edits")', 'existing project must survive')
  for _, name in ipairs({'../escape', '', 'a/b', 'bad;name', '-option'}) do
    assert(not create('python', name), 'invalid name must fail: ' .. name)
  end
  assert(not create('unknown', 'unknown'), 'unknown language must fail')
  for _, name in ipairs({'demo-', 'demo_'}) do
    assert(not create('python', name), 'Python metadata names must end with a letter or digit')
    assert(not vim.uv.fs_lstat(base .. '/' .. name), 'invalid metadata must not leave a project directory')
  end
  assert(vim.uv.fs_symlink(base .. '/missing', base .. '/link'))
  assert(not create('python', 'link'), 'dangling symlink must not be followed')
  assert(not vim.uv.fs_stat(base .. '/missing'), 'symlink target must stay absent')

  new.setup()
  assert(type(vim.fn.maparg('<C-n>', 'n', false, true).callback) == 'function', 'Ctrl+n must open project chooser')
  assert(vim.fn.maparg('<C-n>', 'i') == '', 'insert Ctrl+n completion must stay unchanged')
  local original_select, original_input = vim.ui.select, vim.ui.input
  local cwd, buffer = vim.fn.getcwd(), vim.api.nvim_get_current_buf()
  vim.ui.select = function(_, _, callback) callback(nil) end
  vim.cmd.ProjeYeni()
  assert(vim.fn.getcwd() == cwd and vim.api.nvim_get_current_buf() == buffer, 'cancel must keep workspace')
  vim.ui.select = function(items, _, callback)
    for _, item in ipairs(items) do if item.id == 'python' then callback(item); return end end
    error('Python missing from menu')
  end
  local answers = {'wizard_demo', base}
  vim.ui.input = function(_, callback) callback(table.remove(answers, 1)) end
  local mapping = vim.fn.maparg('<Space>cn', 'n', false, true)
  assert(type(mapping.callback) == 'function', 'shortcut must be registered')
  mapping.callback()
  assert(vim.wait(3000, function() return vim.fn.getcwd() == base .. '/wizard_demo' end))
  assert(vim.api.nvim_buf_get_name(0) == base .. '/wizard_demo/main.py', 'wizard must open the main source')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'unsaved work'})
  vim.ui.select = function() error('wizard must stop before switching with unsaved work') end
  vim.cmd.ProjeYeni()
  assert(vim.bo.modified and vim.api.nvim_get_current_line() == 'unsaved work', 'unsaved changes must survive')
  vim.ui.select, vim.ui.input = original_select, original_input
  vim.cmd('enew!')
  vim.cmd.cd('/tmp')
  vim.fn.delete(base, 'rf')
  print('PASS: overwrite/path protection, cancellation, shortcut, workspace switch, unsaved protection')
end
local ok, err = xpcall(check, debug.traceback)
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
