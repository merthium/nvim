local function check()
  vim.opt.rtp:prepend(vim.fn.stdpath('config'))
  vim.g.mapleader = ' '
  local flow = require('custom.workflow')
  flow.setup()
  local base = vim.fn.tempname()
  local a, b = base .. '/one/project [a]', base .. '/two/project [a]'
  for _, root in ipairs({ a, b }) do
    vim.fn.mkdir(root .. '/.git', 'p')
    vim.fn.writefile({'ref: refs/heads/main'}, root .. '/.git/HEAD')
    vim.fn.mkdir(root .. '/src', 'p')
    vim.fn.writefile({ 'one', 'two', 'three', 'four' }, root .. '/src/main.txt')
  end
  vim.cmd.cd(vim.fn.fnameescape(a))
  vim.cmd.edit(vim.fn.fnameescape(a .. '/src/main.txt'))
  vim.api.nvim_win_set_cursor(0, { 3, 1 })
  vim.fn.writefile({ 'helper one', 'helper two' }, a .. '/src/helper.txt')
  vim.cmd.vsplit(vim.fn.fnameescape(a .. '/src/helper.txt'))
  vim.cmd('wincmd p')
  assert(flow.root() == a, 'nested file must resolve to project root')
  assert(flow.save(), 'session should save')
  local a_session = flow.paths(a).session
  assert(vim.fn.filereadable(a_session) == 1)
  assert(a_session ~= flow.paths(b).session, 'same basename projects need separate sessions')

  vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'unsaved' })
  assert(not flow.resume(), 'resume must protect unsaved edits')
  assert(vim.api.nvim_get_current_line() ~= nil)
  assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'unsaved')
  vim.cmd('edit!')
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  assert(flow.resume(), 'saved session should restore')
  assert(vim.api.nvim_win_get_cursor(0)[1] == 3, 'cursor position must restore')
  assert(#vim.api.nvim_tabpage_list_wins(0) == 2, 'split layout must restore')
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  vim.api.nvim_exec_autocmds('VimLeavePre', {})
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  assert(flow.resume())
  assert(vim.api.nvim_win_get_cursor(0)[1] == 4, 'tracked session should update on clean exit')

  flow.note()
  local note = vim.api.nvim_buf_get_name(0)
  assert(not vim.startswith(note, a .. '/'), 'notes must stay out of project')
  assert(flow.root() == a, 'note must retain project context')
  assert(vim.bo.modified, 'new template must not silently write a file')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '# Sonraki adım', '', '- [ ] Bir örnek çalıştır' })
  vim.cmd.write()
  assert(flow.resume())
  flow.note()
  assert(vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == '- [ ] Bir örnek çalıştır')

  vim.v.oldfiles = { a .. '/src/main.txt', b .. '/src/main.txt', a .. '/missing.txt', note }
  local recent = flow.recent_files(a)
  assert(vim.tbl_contains(recent, a .. '/src/main.txt'))
  for _, file in ipairs(recent) do
    assert(vim.startswith(file, a .. '/') and vim.fn.filereadable(file) == 1, 'recent files must be relevant and readable')
  end
  local current = vim.api.nvim_buf_get_name(0)
  local select = vim.ui.select
  vim.ui.select = function(_, _, callback) callback(nil) end
  flow.open_recent()
  vim.ui.select = select
  assert(vim.api.nvim_buf_get_name(0) == current, 'cancelling recent-file selection must preserve current file')
  vim.cmd('enew')
  vim.cmd.cd(vim.fn.fnameescape(b))
  vim.cmd.edit(vim.fn.fnameescape(b .. '/src/main.txt'))
  assert(flow.root() == b)
  assert(not flow.resume(), 'another project must not restore the previous session')
  assert(flow.save())
  assert(vim.fn.filereadable(flow.paths(b).session) == 1)
  vim.cmd('enew')
  vim.cmd.cd(vim.fn.fnameescape(base))
  assert(flow.resume(), 'empty startup may resume the last saved project')
  assert(vim.fn.getcwd() == b)
  assert(vim.fn.filereadable(a_session) == 1, 'saving project B must not replace project A')
  assert(vim.fn.maparg('<Space>a', 'n') ~= '')
  print('PASS: project sessions, splits, cursor, clean-exit update, unsaved protection, notes, recent files, last-project resume')
  vim.fn.delete(base, 'rf')
end
local ok, err = xpcall(check, debug.traceback)
if not ok then
  io.stderr:write(err .. '\n')
  vim.cmd('cquit 1')
else
  vim.cmd('qa!')
end
