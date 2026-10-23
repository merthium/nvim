local M = {}
local state = vim.fn.stdpath('state') .. '/project-workflow'
local active_root
local restoring = false
local recent = {}

local function normalize(path)
  local normalized = vim.fs.normalize(vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ':p'))
  if normalized ~= '/' then normalized = normalized:gsub('/$', '') end
  return normalized
end

local function inside(path, root)
  return path == root or vim.startswith(path, root == '/' and '/' or root .. '/')
end

local function modified()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      return true
    end
  end
  return false
end

function M.root()
  return require('custom.ide.project').root()
end

function M.paths(root)
  local directory = state .. '/' .. vim.fn.sha256(normalize(root))
  return { directory = directory, session = directory .. '/session.vim', note = directory .. '/next.md' }
end

local function warn(message)
  vim.notify(message, vim.log.levels.WARN, { title = 'Projeye devam' })
end

local function remember(root)
  local path = state .. '/last.json'
  vim.fn.writefile({ vim.json.encode({ root = root }) }, path .. '.tmp')
  assert(vim.uv.fs_rename(path .. '.tmp', path))
end

function M.save(quiet, root)
  if modified() then
    if not quiet then
      warn('Önce değişiklikleri kaydet. Geçerli dosya: Space Space; tüm dosyalar: :wall')
    end
    return false
  end
  root = root or M.root()
  local files = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' and name ~= '' and inside(name, root) then
      files = true
      break
    end
  end
  if not files then
    if not quiet then warn('Önce projeden bir dosya aç.') end
    return false
  end
  local paths = M.paths(root)
  vim.fn.mkdir(paths.directory, 'p', 448)
  local options, cwd = vim.o.sessionoptions, vim.fn.getcwd()
  local ok, err = pcall(function()
    vim.o.sessionoptions = 'buffers,curdir,folds,tabpages,winsize'
    vim.cmd.cd(vim.fn.fnameescape(root))
    vim.cmd('mksession! ' .. vim.fn.fnameescape(paths.session .. '.tmp'))
    assert(vim.uv.fs_rename(paths.session .. '.tmp', paths.session))
    vim.v.this_session = paths.session
    remember(root)
  end)
  vim.o.sessionoptions = options
  vim.cmd.cd(vim.fn.fnameescape(cwd))
  if not ok then
    if not quiet then warn('Oturum kaydedilemedi: ' .. tostring(err)) end
    return false
  end
  active_root = root
  if not quiet then vim.notify('Oturum kaydedildi. Devam etmek için Space b r.') end
  return true
end

function M.resume()
  if modified() then
    warn('Kaydedilmemiş değişiklikler var. Önce kaydet; açık çalışman korunuyor.')
    return false
  end
  local root = M.root()
  local paths = M.paths(root)
  -- Only an empty start may fall back to the last project. An explicit file
  -- from a different project must never unexpectedly open another session.
  if vim.fn.filereadable(paths.session) == 0 and vim.api.nvim_buf_get_name(0) == '' then
    local ok, last = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(state .. '/last.json'), '\n'))
    end)
    if ok and type(last) == 'table' and type(last.root) == 'string' then
      root, paths = last.root, M.paths(last.root)
    end
  end
  if vim.fn.isdirectory(root) == 0 or vim.fn.filereadable(paths.session) == 0 then
    warn('Bu proje için oturum yok. Dosyalarını açıp Space b s ile kaydet.')
    return false
  end
  restoring = true
  local ok, err = pcall(vim.cmd, 'source ' .. vim.fn.fnameescape(paths.session))
  restoring = false
  if not ok then
    warn('Oturum açılamadı: ' .. tostring(err))
    return false
  end
  active_root = root
  remember(root)
  vim.notify('Projeye döndün. Sıradaki küçük adım: Space a.')
  return true
end

function M.note()
  local root = M.root()
  local paths = M.paths(root)
  vim.fn.mkdir(paths.directory, 'p', 448)
  vim.cmd.edit(vim.fn.fnameescape(paths.note))
  vim.b.workflow_root = root
  vim.bo.filetype = 'markdown'
  vim.opt_local.wrap = true
  vim.opt_local.linebreak = true
  if vim.fn.filereadable(paths.note) == 0 and vim.api.nvim_buf_line_count(0) == 1
      and vim.api.nvim_get_current_line() == '' then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      '# Sıradaki küçük adım', '', '- [ ] ', '', 'Kaldığım yer: ',
    })
    vim.api.nvim_win_set_cursor(0, { 3, 6 })
  end
end

function M.recent_files(root)
  root = root or M.root()
  local result, seen = {}, {}
  local function add(file)
    if file == '' then return end
    file = normalize(file)
    if not seen[file] and inside(file, root) and not inside(file, state)
        and vim.fn.filereadable(file) == 1 then
      seen[file] = true
      result[#result + 1] = file
    end
  end
  for _, file in ipairs(recent) do add(file) end
  for _, file in ipairs(vim.v.oldfiles) do add(file) end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted then add(vim.api.nvim_buf_get_name(buf)) end
  end
  return result
end

function M.open_recent()
  local root = M.root()
  local files = M.recent_files(root)
  if #files == 0 then
    vim.notify('Bu projede henüz son dosya yok. Space e ile bir dosya aç.')
    return
  end
  vim.ui.select(files, {
    prompt = 'Projenin son dosyaları:',
    format_item = function(file) return file:sub(#root + 2) end,
  }, function(file)
    if file then vim.cmd.edit(vim.fn.fnameescape(file)) end
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup('ProjectWorkflow', { clear = true })
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function(event)
      local file = vim.api.nvim_buf_get_name(event.buf)
      if file == '' or vim.bo[event.buf].buftype ~= '' or inside(file, state) then return end
      for i = #recent, 1, -1 do
        if recent[i] == file then table.remove(recent, i) end
      end
      table.insert(recent, 1, file)
      if #recent > 100 then table.remove(recent) end
    end,
  })
  vim.api.nvim_create_autocmd('BufReadPost', {
    group = group,
    callback = function(event)
      if restoring or vim.bo[event.buf].buftype ~= '' then return end
      local pos = vim.api.nvim_buf_get_mark(event.buf, '"')
      if pos[1] > 0 and pos[1] <= vim.api.nvim_buf_line_count(event.buf) then
        pcall(vim.api.nvim_win_set_cursor, 0, pos)
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      if active_root and not restoring and M.root() == active_root then
        M.save(true, active_root)
      end
    end,
  })
  local commands = {
    ProjeKaydet = M.save, ProjeDevam = M.resume,
    SonDosyalar = M.open_recent, SonrakiAdim = M.note,
  }
  for name, fn in pairs(commands) do
    vim.api.nvim_create_user_command(name, function() fn() end, {})
  end
  vim.keymap.set('n', '<leader>bs', function() M.save() end, { desc = 'Proje oturumunu kaydet' })
  vim.keymap.set('n', '<leader>br', M.resume, { desc = 'Projeye kaldığın yerden devam et' })
  vim.keymap.set('n', '<leader>bo', M.open_recent, { desc = 'Projenin son dosyaları' })
  vim.keymap.set('n', '<leader>a', M.note, { desc = 'Sıradaki küçük adım' })
end

return M
