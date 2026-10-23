-- Real Overseer/process integration: nvim --headless -u NONE -l tests/ide_output.lua
local base = vim.fn.tempname() .. " output [a]; 'quoted' $dollar"
local csharp_base = vim.fn.tempname() .. ' csharp output'
local function check()
  vim.opt.rtp:prepend(vim.env.NVIM_IDE_CONFIG or vim.fn.stdpath('config'))
  vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/overseer.nvim')
  vim.cmd('filetype on')
  local overseer = require('overseer')
  overseer.setup()
  local notifications = {}
  vim.notify = function(message) notifications[#notifications + 1] = message end
  local tasks = require('custom.ide.tasks')
  vim.fn.mkdir(base, 'p')
  local file = base .. '/hello world.asm'
  vim.fn.writefile({
    'global _start', 'section .data', 'message: db "NASM output OK", 10',
    'length: equ $ - message', 'section .text', '_start:',
    'mov rax, 1', 'mov rdi, 1', 'mov rsi, message', 'mov rdx, length', 'syscall',
    'mov rax, 60', 'xor rdi, rdi', 'syscall',
  }, file)
  vim.cmd.edit(vim.fn.fnameescape(file))
  vim.bo.filetype = 'nasm'
  local source, source_win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  for _ = 1, 3 do
    vim.api.nvim_set_current_win(source_win)
    vim.api.nvim_win_set_buf(source_win, source)
    local completed
    tasks.run('run', {on_complete = function(ok) completed = ok end})
    assert(vim.wait(10000, function() return completed ~= nil end, 10), 'NASM task timed out')
    assert(completed, 'NASM compile/link/run must succeed')
  end
  local terminals = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == 'terminal' then terminals = terminals + 1 end
  end
  local windows = #vim.api.nvim_list_wins()
  print(('Observed repeated NASM: %d windows, %d terminals, %d tasks'):format(windows, terminals, #overseer.list_tasks()))
  assert(windows == 2, 'Repeated NASM run must leave source plus one output window')
  assert(terminals == 1, 'Repeated NASM run must leave one runner terminal')
  assert(#overseer.list_tasks() == 1, 'Compile/link/run must use one managed task')
  assert(vim.api.nvim_get_current_win() == source_win, 'Run must return focus to source')
  assert(vim.api.nvim_win_get_height(vim.fn.bufwinid(tasks.last_task:get_bufnr())) == math.max(6, math.floor(vim.o.lines * 0.35)), 'Output must use 35 percent of screen height')
  local function output(task)
    return table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, false), '\n')
  end
  local function await(task)
    assert(task, 'Runner did not create a task')
    assert(vim.wait(10000, function() return task:is_complete() end, 10), 'Task timed out')
    return output(task)
  end
  local function terminal_count()
    local count = 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buftype == 'terminal' then count = count + 1 end
    end
    return count
  end
  assert(output(tasks.last_task):find('NASM output OK', 1, true), 'Program output must be visible')
  assert(#notifications == 0, 'Successful runs must not create notification popups')

  -- A failed compile must never launch the executable left by an earlier run.
  vim.fn.writefile({'this is not valid assembly'}, file)
  vim.cmd('edit!')
  local failed_result
  local failed = tasks.run('run', {on_complete = function(success) failed_result = success end})
  local failed_output = await(failed)
  assert(vim.wait(1000, function() return failed_result ~= nil end, 10) and not failed_result,
    'Failure must reach completion callbacks')
  assert(failed.status == 'FAILURE' and not failed_output:find('NASM output OK', 1, true),
    'Invalid NASM must stop the chain before the old executable')
  assert(#vim.fn.getqflist() > 0, 'Compiler errors must populate quickfix')
  assert(vim.fn.getqflist({winid = 0}).winid ~= 0, 'Compiler errors must open navigable quickfix')
  vim.cmd.cclose()
  assert(#vim.api.nvim_list_wins() == 2 and terminal_count() == 1, 'Failures must use the same output panel')

  -- Changing cwd between steps and hostile-looking argv must preserve exact data.
  local second_dir = base .. '/second [cwd]'
  vim.fn.mkdir(second_dir, 'p')
  local argument = "literal 'quote' ; $HOME $(touch injected) `touch injected` \\\" "
  local safe = tasks.start({
    {cwd = base, cmd = {'python3', '-c', 'from pathlib import Path; Path("first-step").write_text("first")'}},
    {cwd = second_dir, cmd = {'python3', '-c', 'import os,sys,json; from pathlib import Path; Path("arguments.json").write_text(json.dumps([os.getcwd(),sys.argv[1:]]))', argument, ''}},
  }, {buf = source})
  await(safe)
  assert(safe.status == 'SUCCESS' and vim.fn.readfile(base .. '/first-step')[1] == 'first', 'Each build step must execute')
  local decoded = vim.json.decode(table.concat(vim.fn.readfile(second_dir .. '/arguments.json'), '\n'))
  assert(decoded and decoded[1] == second_dir and decoded[2][1] == argument and decoded[2][2] == '',
    'Shell quoting must preserve cwd, metacharacters, quotes, and empty arguments')
  assert(vim.fn.filereadable(second_dir .. '/injected') == 0, 'Arguments must not execute shell substitutions')

  local python = base .. '/interactive.py'
  vim.fn.writefile({'name = input("Your name: ")', 'print("Hello " + name, flush=True)'}, python)
  vim.cmd.edit(vim.fn.fnameescape(python))
  vim.bo.filetype = 'python'
  source = vim.api.nvim_get_current_buf()
  -- Input needs a running editor event loop, rather than feedkeys inside this
  -- blocking test. Drive an embedded real Neovim through its public input API.
  local child = vim.fn.jobstart({'nvim', '--embed', '--headless', '-u', 'NONE'}, {rpc = true})
  local function rpc(method, ...) return vim.rpcrequest(child, method, ...) end
  local child_ok, child_err = xpcall(function()
    rpc('nvim_exec_lua', [[
      local config, data, file = ...
      vim.opt.rtp:prepend(config)
      vim.opt.rtp:append(data .. '/lazy/overseer.nvim')
      require('overseer').setup()
      vim.cmd.edit(vim.fn.fnameescape(file))
      vim.bo.filetype = 'python'
      local task = require('custom.ide.tasks').run('run')
      vim.api.nvim_set_current_win(vim.fn.bufwinid(task:get_bufnr()))
    ]], {vim.env.NVIM_IDE_CONFIG or vim.fn.stdpath('config'), vim.fn.stdpath('data'), python})
    local function child_output()
      return rpc('nvim_exec_lua', [[
        return table.concat(vim.api.nvim_buf_get_lines(require('custom.ide.tasks').last_task:get_bufnr(), 0, -1, false), '\n')
      ]], {})
    end
    assert(vim.wait(5000, function() return child_output():find('Your name:', 1, true) ~= nil end, 10), 'Python must prompt in output')
    rpc('nvim_input', 'i')
    assert(vim.wait(1000, function() return rpc('nvim_get_mode').mode == 't' end, 10), 'i must enter terminal mode')
    rpc('nvim_input', 'Ada<CR>')
    assert(vim.wait(5000, function() return child_output():find('Hello Ada', 1, true) ~= nil end, 10),
      'Terminal i must forward interactive stdin to Python')
    rpc('nvim_input', '<Esc>')
    assert(vim.wait(1000, function() return rpc('nvim_get_mode').mode:sub(1, 1) == 'n' end, 10), 'Escape must return terminal to normal mode')
  end, debug.traceback)
  vim.fn.jobstop(child)
  assert(child_ok, child_err)

  -- Running while output has focus must target the remembered source buffer.
  vim.fn.writefile({'print("Run from output OK")'}, python)
  vim.api.nvim_buf_call(source, function() vim.cmd('edit!') end)
  local first_python = tasks.run('run')
  await(first_python)
  local old_buf = first_python:get_bufnr()
  vim.api.nvim_set_current_win(vim.fn.bufwinid(old_buf))
  local rerun = tasks.run('run')
  assert(await(rerun):find('Run from output OK', 1, true), 'Run from output must reuse source')
  assert(not vim.api.nvim_buf_is_valid(old_buf), 'Replaced output terminal must be disposed')
  assert(vim.api.nvim_get_current_win() == source_win, 'Run from output must restore source focus')
  tasks.toggle_output()
  assert(#vim.api.nvim_list_wins() == 1, 'Output toggle must hide panel')
  tasks.toggle_output()
  assert(#vim.api.nvim_list_wins() == 2 and terminal_count() == 1, 'Reopening output must reuse its terminal')
  vim.api.nvim_set_current_win(vim.fn.bufwinid(rerun:get_bufnr()))
  vim.api.nvim_feedkeys('q', 'xt', false)
  assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == source, 'q must hide output and restore source')
  tasks.toggle_output()

  -- A separate user terminal/task must survive managed run replacement and stop.
  vim.cmd('vsplit')
  local unrelated_win = vim.api.nvim_get_current_win()
  local unrelated_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(unrelated_win, unrelated_buf)
  local unrelated_job = vim.fn.jobstart({'sh', '-c', 'read value'}, {term = true})
  local unrelated_task = overseer.new_task({cmd = {'sh', '-c', 'sleep 60'}, components = {'on_exit_set_status'}})
  unrelated_task:start()
  vim.api.nvim_set_current_win(source_win)
  local callbacks = 0
  local running = tasks.start({{cwd = base, cmd = {'python3', '-c', 'import time; print("ready", flush=True); time.sleep(60)'}}},
    {buf = source, on_complete = function(ok) assert(not ok); callbacks = callbacks + 1 end})
  assert(vim.wait(5000, function() return output(running):find('ready', 1, true) ~= nil end, 10), 'Long task must start')
  assert(tasks.stop() and running.status == 'CANCELED', 'Stop must cancel the managed task')
  assert(not tasks.stop(), 'Stopping a completed task must be harmless')
  local restarted = tasks.run('run')
  assert(await(restarted):find('Run from output OK', 1, true), 'Runner must restart after stop')
  local replaced = tasks.start({{cwd = base, cmd = {'python3', '-c', 'import time; print("replace me", flush=True); time.sleep(60)'}}}, {buf = source})
  assert(vim.wait(5000, function() return output(replaced):find('replace me', 1, true) ~= nil end, 10), 'Replacement task must start')
  await(tasks.run('run'))
  assert(replaced:is_disposed(), 'Run must stop and dispose its previously running task')
  assert(vim.wait(1000, function() return callbacks == 1 end, 10), 'Cancellation callback must fire once')
  assert(vim.api.nvim_win_is_valid(unrelated_win) and vim.api.nvim_win_get_buf(unrelated_win) == unrelated_buf,
    'Managed output must preserve unrelated terminal windows')
  assert(vim.fn.jobwait({unrelated_job}, 0)[1] == -1 and unrelated_task:is_running(), 'Stop/restart must preserve unrelated jobs')
  assert(#vim.api.nvim_list_wins() == 3 and terminal_count() == 3, 'Only one managed output and terminal may remain')
  unrelated_task:dispose(true)
  vim.fn.jobstop(unrelated_job)
  vim.api.nvim_win_close(unrelated_win, true)
  vim.api.nvim_buf_delete(unrelated_buf, {force = true})
  assert(#notifications == 0, 'Tasks must not create notification popups')

  -- A shared output buffer must follow the tab where it is requested.
  local tab_a = vim.api.nvim_get_current_tabpage()
  vim.cmd('vsplit')
  local preserved_win = vim.api.nvim_get_current_win()
  local preserved_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(preserved_win, preserved_buf)
  vim.api.nvim_set_current_win(source_win)
  local other_python = base .. '/other.py'
  vim.fn.writefile({'print("Tab B output")'}, other_python)
  vim.cmd('tabnew')
  vim.cmd.edit(vim.fn.fnameescape(other_python))
  vim.bo.filetype = 'python'
  local tab_b, source_b = vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win()
  local from_b = tasks.run('run')
  assert(await(from_b):find('Tab B output', 1, true), 'Tab B must run its own source')
  assert(vim.api.nvim_get_current_win() == source_b and vim.fn.bufwinid(from_b:get_bufnr()) ~= -1,
    'Run in tab B must show output in B and keep its source focused')
  assert(#vim.api.nvim_tabpage_list_wins(tab_a) == 2, 'Migrating output must remove its old split from tab A')
  vim.api.nvim_set_current_win(source_win)
  tasks.toggle_output()
  assert(vim.api.nvim_get_current_tabpage() == tab_a and vim.fn.bufwinid(from_b:get_bufnr()) ~= -1,
    'Toggle from tab A must bring remote output to A')
  assert(#vim.api.nvim_tabpage_list_wins(tab_b) == 1, 'Toggle migration must remove output from B')

  -- Users can move output to a tab of its own. Migration must still leave just
  -- one visible output, without replacing unrelated windows or a source tab.
  local old_output_win = vim.fn.bufwinid(from_b:get_bufnr())
  vim.api.nvim_set_current_win(old_output_win)
  vim.cmd('tab split')
  local output_only_tab = vim.api.nvim_get_current_tabpage()
  vim.api.nvim_win_close(old_output_win, true)
  assert(#vim.api.nvim_tabpage_list_wins(output_only_tab) == 1, 'Fixture must have an output-only tab')
  vim.api.nvim_set_current_win(source_b)
  local migrated = tasks.run('run')
  await(migrated)
  local output_count = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == migrated:get_bufnr() then output_count = output_count + 1 end
  end
  assert(output_count == 1 and vim.fn.bufwinid(migrated:get_bufnr()) ~= -1 and terminal_count() == 1,
    'Migrating an output-only tab must leave one output split and one terminal in source tab B')
  assert(vim.api.nvim_win_is_valid(source_win) and vim.api.nvim_win_is_valid(preserved_win)
      and vim.api.nvim_win_get_buf(preserved_win) == preserved_buf,
    'Cross-tab output migration must preserve unrelated source and scratch windows')
  vim.api.nvim_set_current_tabpage(tab_a)
  vim.cmd('tabclose')
  vim.api.nvim_buf_delete(preserved_buf, {force = true})
  vim.api.nvim_set_current_win(source_b)

  -- The legacy :DotnetRun path must share the same output lifecycle.
  vim.fn.mkdir(csharp_base, 'p')
  vim.fn.writefile({'<configuration><packageSources><clear /></packageSources></configuration>'}, csharp_base .. '/NuGet.Config')
  vim.fn.writefile({'<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'}, csharp_base .. '/Output.csproj')
  vim.fn.writefile({'System.Console.WriteLine("CSharp output OK");'}, csharp_base .. '/Program.cs')
  vim.cmd.edit(vim.fn.fnameescape(csharp_base .. '/Program.cs'))
  vim.bo.filetype = 'cs'
  for _ = 1, 2 do
    local previous_task = tasks.last_task
    require('custom.csharp').run('run')
    assert(tasks.last_task ~= previous_task, 'Legacy C# must use the shared runner')
    assert(await(tasks.last_task):find('CSharp output OK', 1, true), 'Legacy C# must execute its project')
  end
  assert(#vim.api.nvim_list_wins() == 2 and terminal_count() == 1 and #overseer.list_tasks() == 1,
    'Legacy C# runs must reuse one output window and task')
  print('PASS NASM lifecycle/failure, quoted argv/cwd, Python stdin, source reuse, toggle/q, stop/restart, unrelated terminals, cross-tab migration, legacy C#')
end
local ok, err = xpcall(check, debug.traceback)
vim.fn.delete(base, 'rf')
vim.fn.delete(csharp_base, 'rf')
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
