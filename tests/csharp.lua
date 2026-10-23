-- Run with: nvim --headless -u NONE -l ~/.config/nvim/tests/csharp.lua
local function check()
  vim.opt.rtp:prepend(vim.fn.stdpath('config'))
  local base = vim.fn.tempname() .. '/CSharp workspace [test]'
  local app = base .. '/src/My App'
  vim.fn.mkdir(app .. '/nested', 'p')
  vim.fn.writefile({ '<Project />' }, app .. '/My App.csproj')
  vim.fn.writefile({ '// test' }, app .. '/nested/Program.cs')
  vim.cmd.edit(vim.fn.fnameescape(app .. '/nested/Program.cs'))
  local flow = require('custom.workflow')
  assert(flow.root() == app, 'C# source in a subdirectory must resolve to its csproj')
  vim.fn.writefile({ '<Solution />' }, base .. '/Workspace.slnx')
  assert(flow.root() == base, 'solution must group nested C# projects into one session')

  local cs = require('custom.csharp')
  local source = app .. '/nested/Program.cs'
  local targets = cs.targets('run', source)
  assert(vim.deep_equal(targets, { app .. '/My App.csproj' }), 'run must target nearest project')
  targets = cs.targets('build', source)
  assert(vim.deep_equal(targets, { base .. '/Workspace.slnx' }), 'build must target solution')
  targets = cs.targets('test', source)
  assert(vim.deep_equal(targets, { base .. '/Workspace.slnx' }), 'test must include solution projects')
  vim.fn.mkdir(base .. '/obj/Generated', 'p')
  vim.fn.writefile({ '<Project />' }, base .. '/obj/Generated/Generated.csproj')
  targets = cs.targets('run', base .. '/Workspace.slnx')
  assert(vim.deep_equal(targets, { app .. '/My App.csproj' }), 'project search must ignore generated obj projects')
  vim.fn.mkdir(base .. '/src/Second', 'p')
  vim.fn.writefile({ '<Project />' }, base .. '/src/Second/Second.csproj')
  targets = cs.targets('run', base .. '/Workspace.slnx')
  assert(#targets == 2, 'solution run must offer all actual projects')
  assert(#cs.targets('build', '/tmp/not-a-dotnet-project/Orphan.cs') == 0, 'unrelated file must not run the cwd project')
  local original_select = vim.ui.select
  local buffers = #vim.api.nvim_list_bufs()
  vim.ui.select = function(_, _, callback) callback(nil) end
  vim.cmd.edit(vim.fn.fnameescape(base .. '/Workspace.slnx'))
  cs.run('run')
  vim.ui.select = original_select
  assert(#vim.api.nvim_list_bufs() == buffers + 1, 'cancelling selection must not open a terminal')
  cs.setup()
  vim.g.mapleader = ' '
  vim.cmd('filetype on')
  for _, file in ipairs({ source, app .. '/My App.csproj', base .. '/Workspace.slnx', base .. '/Legacy.sln' }) do
    vim.cmd.enew()
    vim.cmd.edit(vim.fn.fnameescape(file))
    -- Revisit existing buffers as well as newly detected project files.
    vim.cmd('filetype detect')
    assert(vim.fn.maparg(' cr', 'n') ~= '', 'C# run shortcut missing for ' .. file .. ' (' .. vim.bo.filetype .. ')')
  end
  vim.cmd.edit(vim.fn.fnameescape(base .. '/unrelated.xml'))
  assert(vim.fn.maparg(' cr', 'n') == '', 'unrelated XML must not receive C# shortcuts')
  vim.fn.delete(vim.fs.dirname(base), 'rf')
  print('PASS: C# project/solution roots, build/run/test targets, generated files excluded, selection cancellation')
end
local ok, err = xpcall(check, debug.traceback)
if not ok then
  io.stderr:write(err .. '\n')
  vim.cmd('cquit 1')
end
vim.cmd('qa!')
