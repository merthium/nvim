-- Full configuration with a real attached UI and mouse input.
local children = {}
local root = vim.fn.tempname() .. '-ide-layout'
local function check()
  vim.fn.mkdir(root, 'p')
  local file, header = root .. '/main.cpp', root .. '/helper.hpp'
  vim.fn.writefile({'#include <cstdio>', 'int main() { std::puts("IDE layout OK"); }'}, file)
  vim.fn.writefile({'#pragma once'}, header)
  local function start(width, empty)
    local args = {'nvim', '--embed', '--headless', '-i', 'NONE'}
    if not empty then args[#args + 1] = file end
    local child = vim.fn.jobstart(args, {rpc = true})
    children[#children + 1] = child
    local function rpc(method, ...) return vim.rpcrequest(child, method, ...) end
    local function lua(code, args) return rpc('nvim_exec_lua', code, args or {}) end
    rpc('nvim_ui_attach', width, 40, {rgb = true})
    assert(vim.wait(5000, function() return lua([[return vim.fn.exists(':IDERun')]]) == 2 end, 20))
    return rpc, lua
  end
  local empty_rpc, empty = start(140, true)
  assert(empty([[return vim.o.showtabline]]) == 0, 'empty startup must not have a tab or toolbar')
  assert(vim.wait(3000, function()
    return empty([[vim.cmd.redraw(); local text = ''
      for row=1,vim.o.lines do for col=1,vim.o.columns do text=text..vim.fn.screenstring(row,col) end end
      return text:match('^%s*$') ~= nil]])
  end, 20), 'empty startup must be free of labels, line numbers and welcome text')
  empty_rpc('nvim_command', 'vnew')
  empty_rpc('nvim_command', 'edit ' .. vim.fn.fnameescape(header))
  assert(empty([[return vim.wo.number and vim.wo.cursorline and vim.wo.signcolumn ~= 'no']]),
    'a file opened in a split from the blank screen must regain editor indicators')
  empty_rpc('nvim_command', 'wincmd p')
  empty_rpc('nvim_command', 'tabnew')
  empty_rpc('nvim_command', 'edit ' .. vim.fn.fnameescape(header))
  assert(empty([[return vim.wo.number and vim.wo.cursorline and vim.wo.signcolumn ~= 'no']]),
    'a file opened in a tab from the blank screen must regain editor indicators')
  local rpc, lua = start(140)
  assert(lua([[return #Snacks.picker.get({source = 'explorer'})]]) == 0, 'project tree must wait for an explicit request')
  assert(lua([[return vim.o.showtabline]]) == 0, 'one document needs no tab row')
  assert(lua([[return vim.api.nvim_buf_get_name(0)]]) == file, 'startup must keep focus in code')
  rpc('nvim_input', '<Space>e')
  assert(vim.wait(3000, function() return lua([[return #Snacks.picker.get({source='explorer'})]]) == 1 end, 20))
  assert(lua([[return Snacks.picker.get({source='explorer'})[1]:cwd()]]) == root, 'tree must follow the file project')
  local function column(label)
    return lua([[
      vim.cmd.redraw()
      local line = vim.api.nvim_eval_statusline(vim.o.tabline, {use_tabline=true, maxwidth=vim.o.columns}).str
      local first = assert(line:find(..., 1, true), 'missing tab: '..line)
      return vim.fn.strdisplaywidth(line:sub(1, first-1))
    ]], {label})
  end
  local function click(label)
    rpc('nvim_input_mouse', 'left', 'press', '', 0, 0, column(label))
    rpc('nvim_input_mouse', 'left', 'release', '', 0, 0, column(label))
  end
  lua([[require('custom.ide.ui').focus_source()]])
  rpc('nvim_command', 'edit ' .. vim.fn.fnameescape(header))
  assert(lua([[return vim.o.showtabline]]) == 2, 'multiple documents must expose clickable tabs')
  rpc('nvim_input', 'i')
  assert(vim.wait(1000, function() return rpc('nvim_get_mode').mode == 'i' end, 10))
  rpc('nvim_input_mouse', 'move', '', '', 0, 0, column('main.cpp'))
  assert(vim.wait(1000, function()
    return lua([[local result=vim.api.nvim_eval_statusline(vim.o.tabline,{use_tabline=true,maxwidth=140,highlights=true})
      for _,hl in ipairs(result.highlights) do if vim.tbl_contains(hl.groups,'IDETabHover') then return true end end return false]])
  end, 10), 'hovering a tab must visibly highlight it')
  assert(rpc('nvim_get_mode').mode == 'i', 'hover must not leave insert mode')
  rpc('nvim_input', '<Esc>')
  rpc('nvim_input_mouse', 'move', '', '', 0, 5, 60)
  assert(vim.wait(1000, function()
    return lua([[local result=vim.api.nvim_eval_statusline(vim.o.tabline,{use_tabline=true,maxwidth=140,highlights=true})
      for _,hl in ipairs(result.highlights) do if vim.tbl_contains(hl.groups,'IDETabHover') then return false end end return true]])
  end, 10), 'moving into code must clear tab hover')
  rpc('nvim_input_mouse', 'move', '', '', 0, 0, column('main.cpp'))
  assert(vim.wait(1000, function()
    return lua([[local result=vim.api.nvim_eval_statusline(vim.o.tabline,{use_tabline=true,maxwidth=140,highlights=true})
      for _,hl in ipairs(result.highlights) do if vim.tbl_contains(hl.groups,'IDETabHover') then return true end end return false]])
  end, 10), 'file tabs must highlight under the pointer')
  lua([[Snacks.picker.get({source='explorer'})[1]:focus()]])
  click('main.cpp')
  assert(vim.wait(1000, function() return lua([[return vim.api.nvim_buf_get_name(0)]]) == file end, 10),
    'clicking a file tab from the tree must focus an editor window')
  assert(lua([[return Snacks.picker.get({source='explorer'})[1].list.win:buf_valid()]]), 'tree must survive a file tab click')
  lua([[vim.api.nvim_buf_set_lines(0, -1, -1, false, {'// saved using Ctrl-S'})]])
  rpc('nvim_input', '<C-s>')
  assert(vim.wait(1000, function() return not lua([[return vim.bo.modified]]) end, 10), 'Ctrl-S must write the source')
  rpc('nvim_input', '<F6>')
  assert(vim.wait(10000, function()
    return lua([[local t=require('custom.ide.tasks').last_task; return t and t:is_complete() or false]])
  end, 20), 'F6 must compile and finish')
  assert(lua([[local t=require('custom.ide.tasks').last_task; return t.status]]) == 'SUCCESS')
  assert(lua([[local t=require('custom.ide.tasks').last_task; return table.concat(vim.api.nvim_buf_get_lines(t:get_bufnr(),0,-1,false),'\n')]]):find('IDE layout OK', 1, true))
  assert(lua([[return vim.api.nvim_buf_get_name(0)]]) == file, 'run must return focus to code')
  lua([[
    vim.api.nvim_buf_set_lines(0,0,-1,false,{
      '/// Toplamı hesaplar.', 'int topla(int sol, int sag) { return sol + sag; }',
      'int main() {', '  ', '}',
    })
    vim.api.nvim_win_set_cursor(0,{4,2})
  ]])
  rpc('nvim_input', 'Atopla(')
  assert(vim.wait(5000, function()
    return lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do
      if vim.wo[w].winhighlight:find('BlinkCmpSignatureHelp',1,true) then return true end
    end return false]])
  end, 20), 'typing a function call must display parameter help')
  rpc('nvim_input', '<Esc>')
  lua([[vim.api.nvim_buf_set_lines(0, -1, -1, false, {'int broken = ;'})]])
  assert(vim.wait(10000, function() return lua([[return #vim.diagnostic.get(0)]]) > 0 end, 50), 'real C++ error must be diagnosed')
  rpc('nvim_input', '<Space>xx')
  assert(vim.wait(3000, function()
    return lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='trouble' then return true end end return false]])
  end, 20), 'errors shortcut must open the problems panel')
  assert(lua([[return vim.v.errmsg]]) == '', 'UI must remain free of Lua errors')

  local _, narrow = start(80)
  assert(narrow([[return #Snacks.picker.get({source='explorer'})]]) == 0, 'narrow UI must leave room for code')
  assert(narrow([[return vim.o.showtabline]]) == 0, 'narrow single-file UI needs no tab row')
  assert(narrow([[return vim.v.errmsg]]) == '', 'narrow UI must load cleanly')
  -- Save must target the current unnamed editor, not the previously named split.
  rpc('nvim_command', 'vnew')
  lua([[vim.api.nvim_buf_set_lines(0,0,-1,false,{'new unsaved work'})]])
  local unnamed = lua([[return vim.api.nvim_get_current_buf()]])
  rpc('nvim_input', '<C-s>')
  assert(vim.wait(1000, function()
    return lua([[return vim.bo.filetype]]) == 'snacks_input'
  end, 10), 'saving an unnamed source must ask for its file name')
  rpc('nvim_input', '<Esc>')
  assert(vim.wait(1000, function() return rpc('nvim_get_mode').mode == 'n' end, 10))
  rpc('nvim_input', '<Esc>')
  assert(vim.wait(1000, function() return lua([[return vim.api.nvim_get_current_buf()]]) == unnamed end, 10),
    'cancelling Save must return to the unnamed editor')
  assert(lua([[return vim.bo.modified and vim.api.nvim_buf_get_name(0)=='' ]]), 'cancel must preserve unnamed changes')
  assert(lua([[return vim.api.nvim_eval_statusline(vim.o.tabline,{use_tabline=true,maxwidth=140}).str]]):find('+',1,true),
    'unsaved work must retain a visible modified marker')
  rpc('nvim_input', '<C-s>')
  assert(vim.wait(1000, function() return lua([[return vim.bo.filetype]]) == 'snacks_input' end, 10))
  lua([[vim.api.nvim_buf_set_lines(0,0,-1,false,{...})]], {root .. '/new.cpp'})
  rpc('nvim_input', '<CR>')
  assert(vim.wait(1000, function() return lua([[return vim.api.nvim_buf_get_name(0)]]) == root .. '/new.cpp' end, 10),
    'confirming Save must name the new buffer')
  assert(vim.fn.readfile(root .. '/new.cpp')[1] == 'new unsaved work', 'new source must be written')
  assert(not table.concat(vim.fn.readfile(file),'\n'):find('broken',1,true), 'Save must not write unrelated unsaved source')
  -- The first save must attach analysis without forcing a sidebar open.
  local first_rpc, first = start(140, true)
  first([[vim.api.nvim_buf_set_lines(0,0,-1,false,{'int first;'})]])
  first_rpc('nvim_input', '<C-s>')
  assert(vim.wait(1000, function() return first([[return vim.bo.filetype]]) == 'snacks_input' end, 10))
  first([[vim.api.nvim_buf_set_lines(0,0,-1,false,{...})]], {root .. '/first.cpp'})
  first_rpc('nvim_input', '<CR>')
  assert(vim.wait(3000, function()
    return first([[return require('custom.ide.ui').project_name()]]) == vim.fs.basename(root)
  end, 20), 'first save must update the project name')
  assert(first([[return #Snacks.picker.get({source='explorer'})]]) == 0, 'first save must keep the sidebar closed')
  assert(first([[return vim.api.nvim_buf_get_name(0)]]) == root .. '/first.cpp', 'first save must keep focus in code')
  assert(vim.wait(10000, function()
    return first([[return #vim.lsp.get_clients({bufnr=0, name='clangd'})]]) > 0
  end, 50), 'first saved C++ source must attach clangd')
  rpc('nvim_command', 'only!')
  lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do if b~=vim.api.nvim_get_current_buf() and vim.bo[b].buflisted then Snacks.bufdelete({buf=b,force=true}) end end]])
  assert(vim.wait(1000, function() return lua([[return vim.o.showtabline]]) == 0 end, 10), 'closing other files must hide the tab row')
  print('PASS: blank startup, on-demand tree, tabs/hover, Ctrl-S/F6/errors, C++ execution/signatures, narrow UI, unnamed save/cancel, first save')
end
local ok, err = xpcall(check, debug.traceback)
for _, child in ipairs(children) do vim.fn.jobstop(child) end
vim.fn.delete(root, 'rf')
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
