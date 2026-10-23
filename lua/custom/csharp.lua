local M = {}

local function solution(name) return name:match('%.slnx?$') ~= nil end
local function project(name) return name:match('%.csproj$') ~= nil end

local function files_at(root, matches)
  local files = {}
  for name, kind in vim.fs.dir(root) do
    if kind == 'file' and matches(name) then files[#files + 1] = root .. '/' .. name end
  end
  table.sort(files)
  return files
end

function M.targets(action, source)
  source = source or vim.api.nvim_buf_get_name(0)
  if source == '' then source = vim.fn.getcwd() end
  local project_root = vim.fs.root(source, project)
  local solution_root = vim.fs.root(source, solution)
  if action ~= 'run' and solution_root then return files_at(solution_root, solution) end
  if project_root then return files_at(project_root, project) end
  if not solution_root then return {} end
  local projects = {}
  for name, kind in vim.fs.dir(solution_root, {
    depth = math.huge,
    skip = function(name)
      local base = vim.fs.basename(name)
      return base ~= 'bin' and base ~= 'obj' and base ~= '.git' and base ~= 'node_modules'
    end,
  }) do
    if kind == 'file' and project(name) then projects[#projects + 1] = solution_root .. '/' .. name end
  end
  table.sort(projects)
  return projects
end

function M.run(action)
  if vim.fn.executable('dotnet') ~= 1 then
    vim.notify('.NET SDK bulunamadı.', vim.log.levels.ERROR)
    return
  end
  local targets = M.targets(action)
  if #targets == 0 then
    vim.notify('Önce bir C# projesinden dosya aç (.csproj / .sln / .slnx).', vim.log.levels.WARN)
    return
  end
  local function launch(target)
    if not target then return end
    -- Do not silently build old on-disk code or save unrelated buffers.
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buftype == '' and vim.bo[buf].modified then
        vim.notify('Önce değişiklikleri kaydet: Space Space veya :wall', vim.log.levels.WARN)
        return
      end
    end
    local command = { 'dotnet', action }
    if action == 'run' then command[#command + 1] = '--project' end
    command[#command + 1] = target
    return require('custom.ide.tasks').start({{
      cmd = command, cwd = vim.fs.dirname(target), compiler = 'dotnet',
    }}, {name = 'dotnet ' .. action .. ': ' .. vim.fs.basename(target)})
  end
  if #targets == 1 then launch(targets[1]) else
    vim.ui.select(targets, { prompt = 'dotnet ' .. action .. ' — proje seç:' }, launch)
  end
end

function M.setup()
  local actions = {
    { 'Build', 'b', 'Derle' }, { 'Run', 'r', 'Çalıştır' },
    { 'Test', 't', 'Testleri çalıştır' }, { 'Restore', 's', 'NuGet paketlerini yükle' },
  }
  for _, item in ipairs(actions) do
    local action = item[1]:lower()
    vim.api.nvim_create_user_command('Dotnet' .. item[1], function() M.run(action) end, {})
  end
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('CSharpWorkflow', { clear = true }),
    pattern = { 'cs', 'xml', 'solution' },
    callback = function(event)
      local name = vim.api.nvim_buf_get_name(event.buf)
      if vim.bo[event.buf].filetype ~= 'cs' and not project(name) and not solution(name) then return end
      for _, item in ipairs(actions) do
        vim.keymap.set('n', '<leader>c' .. item[2], '<cmd>Dotnet' .. item[1] .. '<CR>',
          { buffer = event.buf, desc = 'C#: ' .. item[3] })
      end
      if vim.bo[event.buf].filetype == 'cs' then
        vim.bo[event.buf].shiftwidth = 4
        vim.bo[event.buf].tabstop = 4
        vim.bo[event.buf].expandtab = true
      end
    end,
  })
end

return M
