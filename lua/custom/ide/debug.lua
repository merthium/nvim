local M = {}

function M.setup()
  local dap = require('dap')
  local project = require('custom.ide.project')
  dap.providers.configs['dap.launch.json'] = function(buf)
    local root = project.root(buf)
    local ok, configs = pcall(require('dap.ext.vscode').getconfigs, root .. '/.vscode/launch.json')
    if ok then
      local function expand(value)
        if type(value) == 'string' then
          return (value:gsub('%${workspaceFolder}', function() return root end)
            :gsub('%${workspaceFolderBasename}', function() return vim.fs.basename(root) end))
        elseif type(value) == 'table' then
          for key, item in pairs(value) do value[key] = expand(item) end
        end
        return value
      end
      return expand(configs)
    end
    vim.notify('launch.json okunamadı: ' .. tostring(configs), vim.log.levels.WARN)
    return {}
  end
  dap.adapters.codelldb = {type = 'server', port = '${port}', executable = {command = 'codelldb', args = {'--port', '${port}'}}}
  local native = {
    name = 'Derlenmiş programı seç', type = 'codelldb', request = 'launch',
    program = function() return vim.fn.input('Program: ', project.root() .. '/', 'file') end,
    cwd = project.root, stopOnEntry = false,
  }
  for _, ft in ipairs({'c', 'cpp', 'rust', 'zig'}) do dap.configurations[ft] = {vim.deepcopy(native)} end
  local python = vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/bin/python'
  if vim.fn.executable(python) == 1 then
    require('dap-python').setup(python)
    require('dap-python').resolve_python = project.python
    for _, config in ipairs(dap.configurations.python) do config.cwd = project.root end
  end
  dap.adapters['pwa-node'] = {type = 'server', host = '127.0.0.1', port = '${port}', executable = {
    command = 'js-debug-adapter', args = {'${port}', '127.0.0.1'},
  }}
  for _, ft in ipairs({'javascript', 'javascriptreact', 'typescript', 'typescriptreact'}) do
    dap.configurations[ft] = {{name = 'Node: dosyayı çalıştır', type = 'pwa-node', request = 'launch',
      program = '${file}', cwd = project.root, sourceMaps = true, console = 'integratedTerminal',
      skipFiles = {'<node_internals>/**'}}}
  end
  dap.adapters.go = {type = 'server', port = '${port}', executable = {command = 'dlv', args = {'dap', '-l', '127.0.0.1:${port}'}}}
  dap.configurations.go = {{type = 'go', name = 'Go: paketi debug et', request = 'launch', program = '${fileDirname}', cwd = project.root}}
  dap.adapters.coreclr = {type = 'executable', command = 'netcoredbg', args = {'--interpreter=vscode'}}
  dap.configurations.cs = {{type = 'coreclr', name = '.NET: derlenmiş DLL seç', request = 'launch',
    program = function() return vim.fn.input('Debug DLL: ', project.root() .. '/bin/Debug/', 'file') end,
    cwd = project.root, stopAtEntry = false}}
  for name, sign in pairs({DapBreakpoint = 'B', DapBreakpointCondition = '?', DapStopped = '>'}) do
    vim.fn.sign_define(name, {text = sign, texthl = name == 'DapStopped' and 'DiagnosticWarn' or 'DiagnosticError'})
  end
  dap.listeners.after.event_initialized.ide = function() require('dap-view').open() end
end

function M.start()
  local project = require('custom.ide.project')
  if not project.save() then return end
  local dap = require('dap')
  if dap.session() then return dap.continue() end
  local ft = vim.bo.filetype
  local root = project.root()
  if #dap.providers.configs['dap.launch.json'](vim.api.nvim_get_current_buf()) > 0 then
    return dap.continue()
  end
  -- Generated native projects share the build/app contract, including their
  -- Make wrapper. Explicit launch.json still takes precedence above.
  local manifest = require('custom.ide.project_config').load(root)
  if (ft == 'c' or ft == 'cpp') and manifest
      and vim.tbl_contains({'c', 'cpp', 'opengl'}, manifest.template) then
    local buf = vim.api.nvim_get_current_buf()
    return require('custom.ide.tasks').run('build', {buf = buf, on_complete = function(success)
      if not success then return end
      local binary = root .. '/build/app'
      if vim.fn.executable(binary) ~= 1 then
        vim.notify('Debug programı bulunamadı: ' .. binary .. '. Özel hedef için .vscode/launch.json kullan.', vim.log.levels.WARN)
        return
      end
      dap.run({name = vim.fs.basename(root), type = 'codelldb', request = 'launch',
        program = binary, cwd = root, stopOnEntry = false})
    end})
  end
  if ft == 'rust' and vim.fn.filereadable(root .. '/Cargo.toml') == 1 then return vim.cmd.RustLsp('debuggables') end
  if (ft == 'c' or ft == 'cpp') and vim.fn.filereadable(root .. '/Makefile') == 0
      and vim.fn.filereadable(root .. '/CMakeLists.txt') == 0 then
    local tasks = require('custom.ide.tasks')
    local buf, binary = vim.api.nvim_get_current_buf(), tasks.native_binary()
    return tasks.run('build', {on_complete = function(success)
      if success then dap.run({name = vim.fs.basename(vim.api.nvim_buf_get_name(buf)), type = 'codelldb',
        request = 'launch', program = binary, cwd = root, stopOnEntry = false}) end
    end})
  end
  dap.continue()
end

function M.keys()
  local function map(key, fn, desc) vim.keymap.set('n', key, fn, {desc = desc}) end
  map('<F5>', M.start, 'Debug başlat / devam et')
  map('<F9>', function() require('dap').toggle_breakpoint() end, 'Breakpoint koy / kaldır')
  map('<F10>', function() require('dap').step_over() end, 'Debug: sonraki satır')
  map('<F11>', function() require('dap').step_into() end, 'Debug: fonksiyona gir')
  map('<S-F11>', function() require('dap').step_out() end, 'Debug: fonksiyondan çık')
  map('<leader>rd', M.start, 'Debug başlat / devam et')
  map('<leader>rp', function() require('dap').toggle_breakpoint() end, 'Breakpoint koy / kaldır')
  map('<leader>ro', function() require('dap').step_over() end, 'Debug: sonraki satır')
  map('<leader>rj', function() require('dap').step_into() end, 'Debug: fonksiyona gir')
  map('<leader>ru', function() require('dap').step_out() end, 'Debug: fonksiyondan çık')
  map('<leader>rv', function() require('dap'); require('dap-view').toggle() end, 'Değişkenler / çağrı yığını')
  map('<leader>rq', function() require('dap').terminate() end, 'Debug oturumunu bitir')
  map('<leader>re', function() require('dap.ui.widgets').hover() end, 'İmleç altındaki değeri incele')
end

return M
