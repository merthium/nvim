local M = {}
local project = require('custom.ide.project')

function M.native_binary(buf)
  local file = vim.api.nvim_buf_get_name(buf or 0)
  local dir = vim.fn.stdpath('cache') .. '/ide-build/' .. vim.fn.sha256(file)
  return dir .. '/program'
end

function M.plan(action, buf)
  buf = buf or 0
  local root, file, ft = project.root(buf), vim.api.nvim_buf_get_name(buf), vim.bo[buf].filetype
  local configured, config_error = require('custom.ide.project_config').plan(root, action)
  if configured or config_error then return configured, config_error end
  local function has(name) return vim.fn.filereadable(root .. '/' .. name) == 1 end
  local function step(cmd, compiler) return {cmd = cmd, cwd = root, compiler = compiler} end
  if has('package.json') then
    local ok, package = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(root .. '/package.json'), '\n')) end)
    if not ok or type(package) ~= 'table' then return nil, 'package.json okunamadı.' end
    local manager = has('pnpm-lock.yaml') and 'pnpm' or has('yarn.lock') and 'yarn'
      or (has('bun.lock') or has('bun.lockb')) and 'bun' or 'npm'
    if action == 'setup' then return {step({manager, 'install'})} end
    local scripts = type(package.scripts) == 'table' and package.scripts or {}
    local script = action == 'run' and (scripts.start and 'start' or scripts.dev and 'dev') or action
    if script and scripts[script] then return {step({manager, 'run', script})} end
    return nil, 'package.json içinde ' .. action .. ' betiği yok. Space ra ile bir proje görevi seç.'
  end
  if action == 'setup' then return nil, 'Bu proje için kurulum görevi tanımlı değil. Space ra ile görev seç.' end
  if has('Cargo.toml') then return {step({'cargo', action}, 'cargo')} end
  if has('go.mod') or has('go.work') then
    return {step({'go', action, action == 'run' and '.' or './...'}, 'go')}
  end
  if has('CMakeLists.txt') and (action == 'build' or action == 'test') then
    return {step({'python3', vim.fn.stdpath('config') .. '/scripts/native_build.py', '--root', root, action}, 'gcc')}
  end
  if has('build.zig') then
    return {step(action == 'build' and {'zig', 'build'} or {'zig', 'build', action}, 'zig_build')}
  end
  if has('Makefile') and action == 'build' then return {step({'make'}, 'gcc')} end
  if has('Makefile') and action == 'run' then
    for _, line in ipairs(vim.fn.readfile(root .. '/Makefile')) do
      if line:match('^run%s*:') and not line:match('^run%s*:=') then
        return {step({'make', 'run'})}
      end
    end
  end
  if ft == 'nasm' or (ft == 'asm' and file:match('%.asm$')) then
    if action ~= 'build' and action ~= 'run' then return nil end
    if has('Makefile') or has('CMakeLists.txt') then return nil end
    local binary = M.native_binary(buf)
    local object = binary .. '.o'
    local result = {
      step({'nasm', '-f', 'elf64', '-g', '-F', 'dwarf', file, '-o', object}, 'gcc'),
      step({'ld', object, '-o', binary}, 'gcc'),
    }
    if action == 'run' then result[#result + 1] = step({binary}) end
    return result
  end
  if ft == 'python' then
    if action == 'run' then return {step({project.python(buf), file})} end
    if action == 'test' then return {step({project.python(buf), '-m', 'pytest'})} end
    if action == 'build' then return {step({project.python(buf), '-m', 'py_compile', file})} end
  end
  if ft == 'cs' then
    local targets = require('custom.csharp').targets(action, file)
    if #targets == 1 then
      local cmd = {'dotnet', action}
      if action == 'run' then cmd[#cmd + 1] = '--project' end
      cmd[#cmd + 1] = targets[1]
      return {step(cmd, 'dotnet')}
    end
  end
  if ft == 'c' or ft == 'cpp' or ft == 'rust' then
    if action ~= 'build' and action ~= 'run' then return nil end
    -- Projects with their own build system should use their configured tasks.
    if has('Makefile') or has('CMakeLists.txt') then return nil end
    local binary = M.native_binary(buf)
    local cmd = ft == 'rust' and {'rustc', '-g', file, '-o', binary}
      or {ft == 'cpp' and 'g++' or 'gcc', ft == 'cpp' and '-std=c++20' or '-std=c17', '-g', '-O0', '-Wall', '-Wextra', file, '-o', binary}
    if ft ~= 'rust' and vim.fn.executable('ccache') == 1 then table.insert(cmd, 1, 'ccache') end
    local result = {step(cmd, ft == 'rust' and 'cargo' or 'gcc')}
    if action == 'run' then result[#result + 1] = step({binary}) end
    return result
  end
  if ft == 'zig' and action == 'run' then return {step({'zig', 'run', file}, 'zig')} end
  if ft == 'zig' and action == 'test' then return {step({'zig', 'test', file}, 'zig_test')} end
  if ft == 'java' and action == 'run' and not (has('pom.xml') or has('build.gradle') or has('build.gradle.kts')) then
    return {step({'java', file}, 'javac')}
  end
  if action == 'run' and (ft == 'javascript' or ft == 'sh' or ft == 'bash' or ft == 'lua') then
    if ft == 'javascript' and has('package.json') then return nil end
    local exe = ({javascript = 'node', sh = 'sh', bash = 'bash', lua = 'luajit'})[ft]
    if ft == 'sh' and vim.b[buf].is_bash then exe = 'bash' end
    if ft == 'sh' and vim.b[buf].is_kornshell then exe = 'ksh' end
    return {step({exe, file})}
  end
end

function M.available(plan)
  local missing, seen = {}, {}
  local function check(exe, cwd, may_be_output)
    local path = exe:find('/', 1, true) and not vim.startswith(exe, '/') and (cwd .. '/' .. exe) or exe
    if vim.fn.executable(path) ~= 1 and not (may_be_output and exe:find('/', 1, true)) and not seen[exe] then
      missing[#missing + 1], seen[exe] = exe, true
    end
  end
  for _, exe in ipairs(plan.tools or {}) do check(exe, plan[1].cwd, false) end
  for i, spec in ipairs(plan) do check(spec.cmd[1], spec.cwd, i > 1) end
  if #missing > 0 then return false, 'Gerekli araç bulunamadı: ' .. table.concat(missing, ', ') .. '. Proje dosyaları hazır; aracı kurduktan sonra tekrar dene.' end
  return true
end

local source_buf, source_win, output_win, output_buf

local function is_source(buf)
  return buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == ''
    and vim.api.nvim_buf_get_name(buf) ~= ''
end

local function remember_source(buf)
  buf = buf and buf ~= 0 and buf or vim.api.nvim_get_current_buf()
  if is_source(buf) then source_buf = buf end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == source_buf then source_win = win; break end
  end
  return is_source(source_buf) and source_buf or nil
end

local function focus_source(tab)
  if source_win and vim.api.nvim_win_is_valid(source_win)
      and vim.api.nvim_win_get_buf(source_win) == source_buf
      and (not tab or vim.api.nvim_win_get_tabpage(source_win) == tab) then
    vim.api.nvim_set_current_win(source_win)
  end
end

local function output_windows(tab)
  local wins = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if output_buf and vim.api.nvim_win_get_buf(win) == output_buf
        and (not tab or vim.api.nvim_win_get_tabpage(win) == tab) then
      wins[#wins + 1] = win
    end
  end
  return wins
end

local function close_output_window(win)
  if #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win)) > 1
      or #vim.api.nvim_list_tabpages() > 1 then
    -- An output-only tab can be closed when another tab remains. Keeping it
    -- would leave a second visible output after moving the panel elsewhere.
    vim.api.nvim_win_close(win, true)
  elseif is_source(source_buf) then
    vim.api.nvim_win_set_buf(win, source_buf)
    source_win = win
  end
end

local function hide_output()
  focus_source()
  for _, win in ipairs(output_windows()) do close_output_window(win) end
  output_win = nil
end

local function show_output()
  if not output_buf or not vim.api.nvim_buf_is_valid(output_buf) then return end
  local tab = vim.api.nvim_get_current_tabpage()
  output_win = output_windows(tab)[1]
  -- Only windows showing this runner's buffer belong to its output panel.
  for _, win in ipairs(output_windows()) do
    if win ~= output_win then close_output_window(win) end
  end
  if not output_win then
    focus_source(tab)
    vim.cmd('botright ' .. math.max(6, math.floor(vim.o.lines * 0.35)) .. 'split')
    output_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(output_win, output_buf)
  end
  -- Keep the user's manual resize while rerunning in an existing panel.
  for key, value in pairs({number = false, relativenumber = false, signcolumn = 'no',
      foldcolumn = '0', winfixheight = true, wrap = false}) do
    vim.wo[output_win][key] = value
  end
  focus_source(tab)
end

function M.toggle_output()
  remember_source()
  if #output_windows(vim.api.nvim_get_current_tabpage()) > 0 then hide_output() else show_output() end
end

function M.stop()
  if M.last_task and M.last_task:is_running() then return M.last_task:stop() end
  return false
end

-- The task explicitly invokes POSIX sh, so quoting must not depend on &shell.
local function quote(arg) return "'" .. tostring(arg):gsub("'", "'\\''") .. "'" end

local function errorformat(plan, buf)
  local formats, seen = {}, {}
  for _, spec in ipairs(plan) do
    if spec.compiler and not seen[spec.compiler] then
      seen[spec.compiler] = true
      vim.api.nvim_buf_call(buf or 0, function()
        local old_efm, old_makeprg, old_compiler = vim.bo.errorformat, vim.bo.makeprg, vim.b.current_compiler
        vim.b.current_compiler = nil
        if pcall(vim.cmd.compiler, spec.compiler) then formats[#formats + 1] = vim.bo.errorformat end
        vim.bo.errorformat, vim.bo.makeprg, vim.b.current_compiler = old_efm, old_makeprg, old_compiler
      end)
    end
  end
  return #formats > 0 and table.concat(formats, ',') or nil
end

function M.start(plan, opts)
  opts = opts or {}
  if #plan == 0 then if opts.on_complete then opts.on_complete(true) end; return end
  local buf = remember_source(opts.buf)
  local chain = {}
  for i, spec in ipairs(plan) do
    if spec.cwd then chain[#chain + 1] = 'cd -- ' .. quote(spec.cwd) end
    local argv = vim.tbl_map(quote, spec.cmd)
    chain[#chain + 1] = (i == #plan and 'exec ' or '') .. table.concat(argv, ' ')
  end
  local components = {'on_exit_set_status'}
  local efm = errorformat(plan, buf)
  if efm then
    components[#components + 1] = {'on_output_quickfix', errorformat = efm,
      open = false, open_on_match = false, open_on_exit = opts.open == false and 'never' or 'failure', items_only = true,
      set_diagnostics = true}
    components[#components + 1] = 'on_result_diagnostics'
  end
  local previous, previous_buf, previous_wins = M.last_task, output_buf, output_windows()
  M.stop()
  local task = require('overseer').new_task({
    name = opts.name or plan[1].name or ('Görev: ' .. (buf and vim.fs.basename(vim.api.nvim_buf_get_name(buf)) or plan[1].cmd[1])),
    cmd = {'sh', '-c', table.concat(chain, ' && ')}, cwd = plan[1].cwd,
    components = components, strategy = {'jobstart', use_terminal = true},
  })
  M.last_task = task
  task:subscribe('on_complete', function(_, status)
    if opts.on_complete then vim.schedule(function() opts.on_complete(status == 'SUCCESS') end) end
    return true
  end)
  local started = task:start()
  output_buf = task:get_bufnr()
  if output_buf then
    for _, win in ipairs(previous_wins) do
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_set_buf(win, output_buf) end
    end
  end
  if previous and not previous:is_disposed() then previous:dispose(true) end
  if previous_buf and vim.api.nvim_buf_is_valid(previous_buf) then
    vim.api.nvim_buf_delete(previous_buf, {force = true})
  end
  if not started then
    if opts.on_complete then opts.on_complete(false) end
    return task
  end
  if output_buf then
    vim.api.nvim_buf_set_name(output_buf, 'ide://output')
    vim.bo[output_buf].bufhidden = 'hide'
    vim.b[output_buf].workflow_root = plan[1].cwd
    vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', {buffer = output_buf, desc = 'Çıktıda normal moda dön'})
    vim.keymap.set('n', 'q', hide_output, {buffer = output_buf, desc = 'Çıktıyı gizle'})
  end
  if opts.open ~= false then show_output() end
  focus_source()
  return task
end

function M.run(action, opts)
  local buf = remember_source(opts and opts.buf)
  if not buf then return end
  if not project.save(project.root(buf)) then return end
  local plan, err = M.plan(action, buf)
  if err then vim.notify(err, vim.log.levels.WARN); return end
  if not plan then
    return require('overseer').run_task({cwd = project.root(buf)})
  end
  local available, message = M.available(plan)
  if not available then vim.notify(message, vim.log.levels.WARN); return end
  vim.fn.mkdir(vim.fs.dirname(M.native_binary(buf)), 'p')
  local label = ({run = 'Çalıştır', build = 'Derle', test = 'Test', setup = 'Bağımlılıkları kur'})[action] or action
  return M.start(plan, vim.tbl_extend('force', {
    buf = buf, name = label .. ': ' .. vim.fs.basename(vim.api.nvim_buf_get_name(buf)),
  }, opts or {}))
end

function M.check_build()
  local buf = remember_source()
  if not buf then return end
  local root = project.root(buf)
  if vim.fn.filereadable(root .. '/CMakeLists.txt') == 0 then
    vim.notify('Derleme önizlemesi CMake projeleri içindir.', vim.log.levels.WARN)
    return
  end
  if not project.save(root) then return end
  return M.start({{cmd = {'python3', vim.fn.stdpath('config') .. '/scripts/native_build.py',
    '--root', root, 'check'}, cwd = root}}, {buf = buf, name = 'Derleme önizlemesi'})
end

function M.setup()
  local function map(key, fn, desc) vim.keymap.set('n', key, fn, {desc = desc}) end
  map('<leader>rr', function() M.run('run') end, 'Çalıştır')
  map('<leader>rB', M.check_build, 'Nelerin derleneceğini göster')
  map('<leader>rb', function() M.run('build') end, 'Projeyi derle')
  map('<leader>rt', function() M.run('test') end, 'Proje testleri')
  map('<leader>ri', function() M.run('setup') end, 'Proje bağımlılıklarını kur')
  map('<leader>ra', function()
    if project.saved() then require('overseer').run_task({cwd = project.root()}) end
  end, 'Proje görevini seç')
  map('<leader>rl', M.toggle_output, 'Çıktıyı göster / gizle')
  map('<leader>rx', M.stop, 'Programı durdur')
  map('<F6>', function() M.run('run') end, 'Çalıştır')
  map('<S-F6>', M.stop, 'Programı durdur')
  vim.api.nvim_create_user_command('IDEBuildCheck', M.check_build, {desc = 'CMake derleme önizlemesi'})
  vim.api.nvim_create_user_command('IDERun', function() M.run('run') end, {desc = 'Dosyayı/projeyi çalıştır'})
  vim.api.nvim_create_user_command('IDEBuild', function() M.run('build') end, {desc = 'Projeyi derle'})
  vim.api.nvim_create_user_command('IDETest', function() M.run('test') end, {desc = 'Proje testleri'})
  vim.api.nvim_create_user_command('IDESetup', function() M.run('setup') end, {desc = 'Proje bağımlılıklarını kur'})
end

return M
