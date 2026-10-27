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
    -- An in-memory clipboard avoids changing the user's desktop clipboard.
    local value = {'KEEP'}
    vim.g.clipboard = {
      name = 'editing-test', cache_enabled = 0,
      copy = {['+'] = function(lines) value = lines end, ['*'] = function(lines) value = lines end},
      paste = {['+'] = function() return {value, 'v'} end, ['*'] = function() return {value, 'v'} end},
    }
  ]])
  for _, paste in ipairs({'p', '<Space>p'}) do
    reset({'one two'})
    lua([[vim.fn.setreg('+', 'KEEP', 'v')]])
    keys('viw' .. paste)
    expect({'KEEP two'})
    assert(lua([[return vim.fn.getreg('+')]]) == 'KEEP', 'paste overwrote clipboard')
    keys('wviw' .. paste)
    expect({'KEEP KEEP'})
  end
  reset({'one', 'two', 'three'}, 2)
  keys('<A-Up>')
  expect({'two', 'one', 'three'})
  keys('<A-Down>')
  expect({'one', 'two', 'three'})
  keys('i<A-Down>X<Esc>')
  expect({'one', 'three', 'Xtwo'})
  reset({'one', 'two', 'three', 'four'}, 2)
  keys('Vj<A-Up>')
  expect({'two', 'three', 'one', 'four'})
  assert(call('nvim_get_mode').mode == 'V', 'block selection lost')
  keys('<A-Down>')
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
  print('PASS: repeated paste preserves clipboard; Alt+arrows move lines/blocks; Ctrl+D selects and edits matches; Escape and undo work')
end, debug.traceback)
vim.fn.jobstop(child)
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
