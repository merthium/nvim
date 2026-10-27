-- Run with: nvim --headless -u NONE -i NONE -l tests/editing_keys.lua
local child = vim.fn.jobstart({'nvim', '--embed', '--headless', '-i', 'NONE'}, {rpc = true})
local function call(method, ...) return vim.rpcrequest(child, method, ...) end
local function lua(code, ...) return call('nvim_exec_lua', code, {...}) end
local function keys(input)
  -- Let mode changes and multicursor's SafeState callbacks finish between keys.
  while #input > 0 do
    local key = input:match('^<[^>]+>') or input:sub(1, 1)
    call('nvim_input', key)
    vim.wait(60)
    input = input:sub(#key + 1)
  end
end
local function reset(lines, row)
  keys('<Esc><Esc>')
  call('nvim_command', 'enew!')
  call('nvim_buf_set_lines', 0, 0, -1, false, lines)
  call('nvim_win_set_cursor', 0, {row or 1, 0})
end
local function expect(lines)
  local actual = call('nvim_buf_get_lines', 0, 0, -1, false)
  assert(vim.deep_equal(actual, lines), 'unexpected buffer contents: ' .. vim.inspect(actual))
end
local ok, err = xpcall(function()
  call('nvim_ui_attach', 100, 35, {rgb = true})
  lua([[require('lazyvim.config').load('keymaps')
    if vim.env.NVIM_TEST_REAL_CLIPBOARD == '1' then
      assert(vim.fn.has('clipboard') == 1, 'system clipboard provider unavailable')
      return
    end
    -- An in-memory clipboard avoids changing the user's desktop clipboard.
    local value, kind = {'KEEP'}, 'v'
    local function copy(lines, regtype) value, kind = lines, regtype end
    local function paste() return {value, kind} end
    vim.g.clipboard = {
      name = 'editing-test', cache_enabled = 0,
      copy = {['+'] = copy, ['*'] = copy},
      paste = {['+'] = paste, ['*'] = paste},
    }
  ]])
  for _, select in ipairs({'viw', 'viw<C-g>'}) do
    reset({'one two'})
    lua([[vim.fn.setreg('+', 'KEEP', 'v')]])
    keys(select .. '<C-v>')
    expect({'KEEP two'})
    assert(lua([[return vim.fn.getreg('+')]]) == 'KEEP', 'paste overwrote clipboard')
    keys('w' .. select .. '<C-v>')
    expect({'KEEP KEEP'})
  end
  for _, select in ipairs({'viw', 'viw<C-g>'}) do
    reset({'source target'})
    keys(select .. '<C-c>')
    assert(lua([[return vim.fn.getreg('+')]]) == 'source', 'Ctrl+C did not copy selection')
    expect({'source target'})
  end
  for _, prefix in ipairs({'', 'i'}) do
    reset({'whole line', 'next'})
    keys(prefix .. '<C-c>')
    assert(lua([[return vim.fn.getreg('+')]]) == 'whole line\n', 'Ctrl+C must copy current line')
    assert(call('nvim_get_mode').mode == (prefix == '' and 'n' or 'i'), 'copy changed editor mode')
  end
  reset({'whole line', 'next'})
  keys('<C-c><C-v>')
  expect({'whole line', 'whole line', 'next'})
  reset({'abc'})
  lua([[vim.fn.setreg('+', {'İlk\t"satır"', 'ikinci'}, 'v')]])
  keys('i<C-v><Esc>')
  expect({'İlk\t"satır"', 'ikinciabc'})
  keys('u')
  expect({'abc'})
  reset({'abc'})
  lua([[vim.fn.setreg('+', 'literal.*[text]', 'v')]])
  keys('/<C-v>')
  assert(lua([[return vim.fn.getcmdline()]]) == 'literal.*[text]', 'command-line paste changed text')
  keys('<Esc>')
  reset({'first', 'second', 'last'})
  keys('Vj<C-c>')
  assert(lua([[return vim.fn.getreg('+')]]) == 'first\nsecond\n', 'multiline copy failed')
  keys('jV<C-v>')
  expect({'first', 'first', 'second', 'last'})
  assert(lua([[return vim.fn.getreg('+')]]) == 'first\nsecond\n', 'linewise paste overwrote clipboard')
  reset({'source delete'})
  keys('viw<C-c>wdw')
  assert(lua([[return vim.fn.getreg('+')]]) == 'source', 'deleting text overwrote clipboard')
  -- Old editor shortcuts must do nothing; letters remain normal insert-mode text.
  for _, old in ipairs({'y', 'Y', 'p', 'P', 'gp', 'gP', '[p', ']p', '[P', ']P',
    '<Space>y', '<Space>p', '<C-Insert>', '<S-Insert>'}) do
    for _, selection in ipairs({'', 'viw'}) do
      reset({'one two'})
      lua([[vim.fn.setreg('+', 'KEEP', 'v')]])
      keys(selection .. old)
      expect({'one two'})
      assert(lua([[return vim.fn.getreg('+')]]) == 'KEEP', 'old shortcut changed clipboard: ' .. old)
      assert(call('nvim_get_mode').mode == (selection == '' and 'n' or 'v'), 'old shortcut changed mode: ' .. old)
    end
  end
  reset({''})
  keys('iypYP<C-Insert><S-Insert><C-r><Esc>')
  expect({'ypYP'})
  reset({'foo foo foo'})
  keys('<C-d><C-d><C-d><C-c><Esc><Esc>')
  assert(lua([[return vim.fn.getreg('+')]]) == 'foo', 'multicursor copy failed')
  expect({'foo foo foo'})
  reset({'foo foo foo'})
  lua([[vim.fn.setreg('+', 'KEEP', 'v')]])
  keys('<C-d><C-d><C-d><C-v><Esc><Esc>')
  expect({'KEEP KEEP KEEP'})
  assert(lua([[return vim.fn.getreg('+')]]) == 'KEEP', 'multicursor paste overwrote clipboard')
  keys('u')
  expect({'foo foo foo'})
  reset({'one', 'two', 'three'}, 2)
  keys('<S-Up>')
  expect({'two', 'one', 'three'})
  keys('<S-Down>')
  expect({'one', 'two', 'three'})
  keys('i<S-Down>X<Esc>')
  expect({'one', 'three', 'Xtwo'})
  reset({'one', 'two', 'three', 'four'}, 2)
  keys('Vj<S-Up>')
  expect({'two', 'three', 'one', 'four'})
  assert(call('nvim_get_mode').mode == 'V', 'block selection lost')
  keys('<S-Down>')
  expect({'one', 'two', 'three', 'four'})
  reset({'foo foo foo untouched'})
  keys('<C-d>')
  assert(call('nvim_get_mode').mode == 'v', 'first Ctrl+D must select the word')
  assert(not lua([[return require('multicursor-nvim').hasCursors()]]), 'first press added extra cursors')
  keys('<C-d>')
  keys('<C-d>')
  assert(lua([[return require('multicursor-nvim').hasCursors()]]), 'repeated Ctrl+D did not add cursors')
  keys('cbar<Esc><Esc>')
  expect({'bar bar bar untouched'})
  assert(not lua([[return require('multicursor-nvim').hasCursors()]]), 'Escape did not clear cursors')
  keys('u')
  expect({'foo foo foo untouched'})
  assert(lua([[return vim.fn.maparg('<C-c>', 't')]]) == '', 'terminal interrupt was remapped')
  assert(lua([[return vim.v.errmsg]]) == '', 'Neovim reported an error')
  print('PASS: Ctrl+C/V, preserved clipboard, disabled legacy keys, multiline text, multicursor paste/undo, Shift+arrows and Ctrl+D')
end, debug.traceback)
vim.fn.jobstop(child)
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
