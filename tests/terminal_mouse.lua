-- Real attached UI: mouse hover must focus terminal and allow typing without i.
local child
local base = vim.fn.tempname() .. '-mouse-terminal'
local function check()
  vim.fn.mkdir(base .. '/project/src', 'p')
  vim.fn.mkdir(base .. '/elsewhere', 'p')
  local root = base .. '/project'
  local file = root .. '/src/main.cpp'
  vim.fn.writefile({'all:'}, root .. '/Makefile')
  vim.fn.writefile({'int main() {return 0;}'}, file)
  child = vim.fn.jobstart({'nvim','--embed','--headless','-i','NONE',file}, {rpc=true,cwd=base .. '/elsewhere'})
  local function rpc(method, ...) return vim.rpcrequest(child, method, ...) end
  local function lua(code, args) return rpc('nvim_exec_lua', code, args or {}) end
  rpc('nvim_ui_attach',120,40,{rgb=true})
  assert(vim.wait(5000,function() return lua([[return vim.fn.exists(':IDERun')]])==2 end,20))
  local source = lua([[return vim.api.nvim_get_current_win()]])
  rpc('nvim_input','<F7>')
  assert(vim.wait(5000,function() return lua([[return vim.bo.buftype=='terminal' and vim.fn.mode()=='t']]) end,20))
  local termwin = lua([[return vim.api.nvim_get_current_win()]])
  local termbuf = lua([[return vim.api.nvim_get_current_buf()]])
  local esc = lua([[return vim.fn.maparg('<Esc>','t')]])
  local function hover(win)
    local pos = lua([[return vim.api.nvim_win_get_position(...)]],{win})
    rpc('nvim_input_mouse','move','', '',0,pos[1]+1,pos[2]+4)
  end
  hover(source)
  assert(vim.wait(2000,function() return lua([[return vim.api.nvim_get_current_win()]])==source end,20), 'moving from terminal to code must focus code')
  hover(termwin)
  assert(vim.wait(2000,function() return lua([[return vim.api.nvim_get_current_win()==... and vim.fn.mode()=='t']],{termwin}) end,20), 'hovering terminal must enter terminal input without i')
  rpc('nvim_input',"printf '\\nMOUSE_CWD=%s\\n' \"$PWD\"<CR>")
  assert(vim.wait(3000,function() return lua([[return table.concat(vim.api.nvim_buf_get_lines(...,0,-1,false),'\n')]],{termbuf}):find('MOUSE_CWD='..root,1,true) end,20), 'terminal must accept typing in active project root')
  assert(lua([[return vim.fn.maparg('<Esc>','t')]])==esc,'mouse behavior must not change Escape mapping')
  -- Preserve explicit keyboard normal mode until the next mouse movement.
  rpc('nvim_input','<C-\\><C-n>')
  assert(vim.wait(1000,function() return lua([[return vim.fn.mode()]])=='n' end,20))
  hover(source)
  assert(vim.wait(1000,function() return lua([[return vim.api.nvim_get_current_win()]])==source end,20))
  hover(termwin)
  assert(vim.wait(1000,function() return lua([[return vim.fn.mode()]])=='t' end,20))
  print('PASS mouse follows terminal/code, immediate typing, project cwd, unchanged Escape')
end
local ok, err=xpcall(check,debug.traceback)
if child then vim.fn.jobstop(child) end
vim.fn.delete(base,'rf')
if not ok then io.stderr:write(err..'\n');vim.cmd('cquit 1') end
vim.cmd('qa!')
