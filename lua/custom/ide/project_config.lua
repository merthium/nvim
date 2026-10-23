local M = {}
local filename = '.nvim-project.json'

function M.load(root)
  local path = root .. '/' .. filename
  if not vim.uv.fs_lstat(path) then return nil end
  local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), '\n')) end)
  local function invalid(detail) return nil, filename .. ': ' .. detail end
  if not ok or type(data) ~= 'table' then return invalid('Geçerli bir JSON nesnesi gerekli.') end
  if data.version ~= 1 or type(data.tasks) ~= 'table' then return invalid('version: 1 ve tasks nesnesi gerekli.') end
  for action, steps in pairs(data.tasks) do
    if type(action) ~= 'string' or type(steps) ~= 'table' or not vim.islist(steps) or #steps == 0 then
      return invalid('Her görev en az bir komut dizisi içermeli.')
    end
    for _, argv in ipairs(steps) do
      if type(argv) ~= 'table' or not vim.islist(argv) or #argv == 0 then
        return invalid(action .. ': komut ve argümanları bir dizi olmalı.')
      end
      for i, arg in ipairs(argv) do
        if type(arg) ~= 'string' or arg:find('\0', 1, true) or (i == 1 and arg == '') then
          return invalid(action .. ': komut argümanları metin olmalı; komut boş olamaz.')
        end
      end
    end
  end
  if data.tools ~= nil then
    if type(data.tools) ~= 'table' or not vim.islist(data.tools) then return invalid('tools bir dizi olmalı.') end
    for _, tool in ipairs(data.tools) do
      if type(tool) ~= 'string' or tool == '' or tool:find('\0', 1, true) then return invalid('Geçersiz tools girdisi.') end
    end
  end
  return data
end

function M.plan(root, action)
  local data, err = M.load(root)
  if err then return nil, err end
  if not data then return nil end
  if not data.tasks[action] then
    return nil, ('Bu proje için "%s" görevi tanımlı değil. %s dosyasına ekleyebilirsin.'):format(action, filename)
  end
  local compiler = ({c='gcc', cpp='gcc', opengl='gcc', asm='gcc', rust='cargo', go='go', java='javac',
    csharp='dotnet', fsharp='dotnet', zig='zig_build'})[data.template]
  local result = {tools = action ~= 'setup' and data.tools or nil}
  for _, argv in ipairs(data.tasks[action]) do
    local cmd = vim.deepcopy(argv)
    if cmd[1] == 'python3' and action ~= 'setup' then
      local python = require('custom.ide.project').python_at(root)
      if python ~= '' then cmd[1] = python end
    end
    result[#result + 1] = {cmd = cmd, cwd = root, compiler = compiler}
  end
  return result
end

-- Standard process tasks are also discoverable through Overseer / Space ra.
function M.vscode_tasks(tasks)
  local result = {version = '2.0.0', tasks = {}}
  for _, action in ipairs({'setup', 'build', 'run', 'test'}) do
    local steps = tasks[action]
    if steps then
      local label, depends = 'Neovim: ' .. action, {}
      for i, argv in ipairs(steps) do
        local step_label = #steps == 1 and label or (label .. ': ' .. i)
        local task = {label = step_label, type = 'process', command = argv[1],
          args = vim.list_slice(argv, 2), options = {cwd = '${workspaceFolder}'}, problemMatcher = {}}
        if #steps == 1 and (action == 'build' or action == 'test') then task.group = action end
        result.tasks[#result.tasks + 1] = task
        depends[#depends + 1] = step_label
      end
      if #steps > 1 then
        result.tasks[#result.tasks + 1] = {label = label, dependsOn = depends, dependsOrder = 'sequence',
          group = (action == 'build' or action == 'test') and action or nil, problemMatcher = {}}
      end
    end
  end
  return result
end

return M
