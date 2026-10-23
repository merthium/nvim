local function check()
  vim.opt.rtp:prepend(vim.fn.stdpath('config'))
  vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/blink.cmp')
  local servers = require('custom.ide.languages').servers()
  local base = vim.fn.tempname() .. ' language roots'
  local function file(path)
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    vim.fn.writefile({'{}'}, path)
  end
  local function roots(path)
    vim.cmd.edit(vim.fn.fnameescape(path))
    local node, deno
    servers.vtsls.root_dir(0, function(value) node = value end)
    servers.denols.root_dir(0, function(value) deno = value end)
    return node, deno
  end
  file(base .. '/deno.json')
  file(base .. '/node/package.json')
  local node, deno = roots(base .. '/node/main.ts')
  assert(node == base .. '/node' and not deno, 'nested Node must exclude ancestor Deno')
  file(base .. '/node/deno/deno.json')
  node, deno = roots(base .. '/node/deno/main.ts')
  assert(not node and deno == base .. '/node/deno', 'nested Deno must exclude ancestor Node')
  file(base .. '/configonly/tsconfig.json')
  node, deno = roots(base .. '/configonly/main.ts')
  assert(not node and deno == base, 'generic tsconfig root must not imply Node inside a Deno project')
  file(base .. '/package.json')
  node, deno = roots(base .. '/main.ts')
  assert(not node and deno == base, 'explicit Deno config wins at same directory')
  assert(not vim.tbl_contains(servers.sourcekit.filetypes, 'cpp'), 'Swift server must not compete with clangd')
  vim.cmd('enew!')
  vim.fn.delete(base, 'rf')
  print('PASS: mutually exclusive nested Node/Deno roots and Swift/C++ language scope')
end
local ok, err = xpcall(check, debug.traceback)
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
