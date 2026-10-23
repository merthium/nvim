-- Run with the real config: nvim --headless -c 'luafile tests/ide_debug.lua'
local function check()
  local base = vim.fn.tempname() .. ' debug-config'
  local dap, tasks = require('dap'), require('custom.ide.tasks')
  local continued, compiled, rust_selected = 0, 0, 0
  -- Replace only launching boundaries: selection must precede build/launch side effects.
  dap.continue = function() continued = continued + 1 end
  tasks.run = function() compiled = compiled + 1 end
  for _, ft in ipairs({'c', 'rust'}) do
    local root = base .. '/' .. ft
    vim.fn.mkdir(root .. '/.vscode', 'p')
    if ft == 'rust' then
      vim.fn.writefile({'[package]', 'name="debug_test"', 'version="0.1.0"'}, root .. '/Cargo.toml')
    end
    vim.fn.writefile({vim.json.encode({configurations = {{type='codelldb', request='attach', name='Custom attach', pid='${command:pickProcess}'}}})}, root .. '/.vscode/launch.json')
    local file = root .. '/main.' .. (ft == 'rust' and 'rs' or 'c')
    vim.fn.writefile({ft == 'rust' and 'fn main() {}' or 'int main(void) { return 0; }'}, file)
    vim.cmd.edit(vim.fn.fnameescape(file))
    vim.api.nvim_create_user_command('RustLsp', function() rust_selected = rust_selected + 1 end, {nargs='*', force=true})
    require('custom.ide.debug').start()
  end
  assert(continued == 2 and compiled == 0 and rust_selected == 0, 'F5 must offer project launch.json before automatic native or Cargo launch')
  vim.fn.delete(base, 'rf')
  print('PASS F5 honors launch.json for standalone native files and Cargo projects')
end
local ok, err = xpcall(check, debug.traceback)
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
