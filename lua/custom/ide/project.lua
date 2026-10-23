local M = {}
local markers = {
  '.nvim-project.json', 'composer.json', 'Gemfile', 'Package.swift', 'pubspec.yaml',
  'deno.json', 'deno.jsonc', 'deno.lock',
  'Project.toml', 'mix.exs', 'build.sbt', 'deps.edn', 'dune-project', 'cabal.project', 'fpm.toml',
  'Cargo.toml', 'go.work', 'go.mod', 'package.json', 'pyproject.toml', 'setup.py',
  'requirements.txt', 'setup.cfg', 'Pipfile', 'pyrightconfig.json',
  'pom.xml', 'build.gradle', 'build.gradle.kts', 'build.zig', 'CMakeLists.txt',
  'compile_commands.json', 'Makefile', 'justfile', '.algo-workshop', 'tsconfig.json', 'jsconfig.json',
  '.luarc.json', '.luarc.jsonc', '.stylua.toml', 'stylua.toml', '.clangd', 'Kbuild', '.vscode',
}

local function normalize(path)
  local value = vim.fs.normalize(vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ':p'))
  return value == '/' and value or value:gsub('/$', '')
end

function M.inside(path, root)
  return path == root or vim.startswith(path, root == '/' and '/' or root .. '/')
end

function M.root(buf)
  buf = buf or 0
  if vim.b[buf].workflow_root then return vim.b[buf].workflow_root end
  local name = vim.api.nvim_buf_get_name(buf)
  local cwd = normalize(vim.fn.getcwd())
  local path = name ~= '' and vim.bo[buf].buftype == '' and normalize(name) or cwd
  local start = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
  if name:match('%.cs$') or name:match('%.csproj$') or name:match('%.slnx?$') then
    local explicit = vim.fs.find('.nvim-project.json', {path = start, upward = true})[1]
    local sln = vim.fs.find(function(n) return n:match('%.slnx?$') ~= nil end, {path = start, upward = true})[1]
    if explicit and (not sln or #vim.fs.dirname(explicit) >= #vim.fs.dirname(sln)) then return vim.fs.dirname(explicit) end
    if sln then return vim.fs.dirname(sln) end
    local csproj = vim.fs.find(function(n) return n:match('%.csproj$') ~= nil end, {path = start, upward = true})[1]
    if csproj then return vim.fs.dirname(csproj) end
  end
  local manifest = vim.fs.find(markers, {path = start, upward = true})[1]
  if manifest then return vim.fs.dirname(manifest) end
  local git = vim.fs.find(function(entry, parent)
    if entry ~= '.git' then return false end
    local marker = parent .. '/.git'
    if vim.fn.filereadable(marker .. '/HEAD') == 1 then return true end
    -- Worktrees use a gitdir file; empty sandbox permission markers are not repositories.
    if vim.fn.filereadable(marker) == 1 then
      local first = vim.fn.readfile(marker, '', 1)[1] or ''
      return first:match('^gitdir: ') ~= nil
    end
    return false
  end, {path = start, upward = true})[1]
  return git and vim.fs.dirname(git) or start
end

function M.python_at(root)
  for _, env in ipairs({'.venv', 'venv'}) do
    local exe = root .. '/' .. env .. '/bin/python'
    if vim.fn.executable(exe) == 1 then return exe end
  end
  if vim.env.VIRTUAL_ENV and vim.fn.executable(vim.env.VIRTUAL_ENV .. '/bin/python') == 1 then
    return vim.env.VIRTUAL_ENV .. '/bin/python'
  end
  return vim.fn.exepath('python3')
end

function M.python(buf) return M.python_at(M.root(buf)) end

function M.saved(root)
  root = root or M.root()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype == '' and vim.bo[buf].modified
        and (name == '' or M.inside(name, root)) then
      vim.notify('Önce proje değişikliklerini kaydet: Space Space veya :wall', vim.log.levels.WARN)
      return false
    end
  end
  return true
end

-- Explicit run/build/test saves only source buffers belonging to this project.
function M.save(root)
  root = root or M.root()
  local pending = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype == '' and vim.bo[buf].modified and (name == '' or M.inside(name, root)) then
      if name == '' or vim.bo[buf].readonly then
        vim.notify(name == '' and 'Önce adsız dosyayı Ctrl s ile kaydet.' or ('Salt okunur dosya kaydedilemedi: ' .. name), vim.log.levels.WARN)
        return false
      end
      pending[#pending + 1] = buf
    end
  end
  for _, buf in ipairs(pending) do
    local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd('silent update') end)
    if not ok or vim.bo[buf].modified then
      vim.notify('Çalıştırmadan önce kayıt başarısız: ' .. tostring(err or vim.api.nvim_buf_get_name(buf)), vim.log.levels.ERROR)
      return false
    end
  end
  return true
end

return M
