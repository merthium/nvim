local M = {}

local registry = require('custom.ide.templates')
local config = require('custom.ide.project_config')

local function missing_tools(item)
  local missing = {}
  for _, tool in ipairs(item.tools) do
    if vim.fn.executable(tool) ~= 1 then missing[#missing + 1] = tool end
  end
  return missing
end

local function write(root, name, content)
  local path = root .. '/' .. name
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local fd = assert(vim.uv.fs_open(path, 'wx', 420))
  local written, err = vim.uv.fs_write(fd, content, 0)
  vim.uv.fs_close(fd)
  assert(written == #content, err or ('Dosya yazılamadı: ' .. path))
end

local function readme(spec, name)
  local lines = {'# ' .. name, '', spec.label .. ' başlangıç projesi.', '',
    'Gerekli araçlar: ' .. table.concat(spec.tools, ', '), '', spec.notes or '', '',
    'Neovim: F6 / Space rr çalıştırır; Space rb derler; Space rt testleri çalıştırır.',
    'Space ri tanımlı proje bağımlılıklarını kurar. SDK/derleyiciyi ayrıca kurmalısın.',
    'Çalıştırma öncesinde bu projedeki adlandırılmış dosyalar kaydedilir.', '', '## Komutlar', ''}
  for _, action in ipairs({'setup', 'run', 'build', 'test'}) do
    if spec.tasks[action] then
      vim.list_extend(lines, {'### ' .. action, '', '```sh'})
      for _, argv in ipairs(spec.tasks[action]) do
        lines[#lines + 1] = table.concat(vim.tbl_map(vim.fn.shellescape, argv), ' ')
      end
      vim.list_extend(lines, {'```', ''})
    end
  end
  vim.list_extend(lines, {
    'Komutlar proje kökünde çalışır. Neovim F6 görevleri `.nvim-project.json` içindedir.',
    'Her komut bir argüman dizisidir; adımlar sırayla, yalnız önceki adım başarılıysa çalışır.',
    'Özel görevler ekleyebilir veya `.vscode/tasks.json` görevlerini Space ra ile seçebilirsin.',
    'Test görevi bulunmayan şablonlarda test altyapısını seçip bir test görevi ekle.', '',
    'Space e: dosyalar · Space /: proje araması · F7: terminal · Space bs: oturumu kaydet', '',
  })
  return table.concat(lines, '\n')
end

-- Claim a fresh directory; installed SDKs never gate offline creation.
function M.create(id, parent, name, callback)
  local function fail(message) callback(nil, message) end
  local spec, render_error = registry.render(id, name)
  if not spec then return fail(render_error) end
  if id == 'python' and not name:match('[A-Za-z0-9]$') then
    return fail('Python proje adı harf veya rakamla bitmeli.')
  end
  if type(parent) ~= 'string' or vim.trim(parent) == '' then return fail('Konum boş olamaz.') end
  if parent == '~' then parent = vim.env.HOME
  elseif parent:sub(1, 2) == '~/' then parent = vim.env.HOME .. parent:sub(2) end
  parent = vim.fn.fnamemodify(parent, ':p'):gsub('/$', '')
  local root = parent .. '/' .. name
  if vim.uv.fs_lstat(root) then return fail('Bu yol zaten var; başka bir proje adı seç: ' .. root) end
  local ok, err = pcall(vim.fn.mkdir, parent == '' and '/' or parent, 'p')
  if not ok then return fail(tostring(err)) end
  local made, message = vim.uv.fs_mkdir(root, 493)
  if not made then return fail('Klasör oluşturulamadı: ' .. tostring(message)) end
  local saved, write_error = pcall(function()
    for file, content in pairs(spec.files) do write(root, file, content) end
    write(root, '.nvim-project.json', vim.json.encode({version = 1, template = id, name = name,
      main = spec.main, tools = spec.tools, tasks = spec.tasks}) .. '\n')
    write(root, '.vscode/tasks.json', vim.json.encode(config.vscode_tasks(spec.tasks)) .. '\n')
    write(root, '.gitignore', table.concat({
      'build/', 'bin/Debug/', 'bin/Release/', 'obj/', 'target/', 'dist/', 'node_modules/',
      '.venv/', 'venv/', '__pycache__/', '*.pyc', '.gradle/', '.dart_tool/', '.build/',
      '_build/', 'deps/', 'dist-newstyle/', '.cpcache/', '.zig-cache/', 'zig-out/', '',
    }, '\n'))
    write(root, 'README.md', readme(spec, name))
  end)
  if not saved then return fail('Proje tamamlanamadı (' .. root .. '): ' .. tostring(write_error)) end
  callback(root)
end

local function clean_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].modified then
      vim.notify('Önce değişiklikleri kaydet: Space Space veya :wall', vim.log.levels.WARN)
      return false
    end
  end
  return true
end

function M.open()
  if not clean_buffers() then return end
  local origin_buf, origin_win, origin_cwd = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win(), vim.fn.getcwd()
  vim.ui.select(registry.list(), {prompt = 'Yeni proje · dil veya framework ara:', format_item = function(item)
    local missing = missing_tools(item)
    return item.label .. (#missing > 0 and ('  (araç eksik: ' .. table.concat(missing, ', ') .. ')') or '')
  end}, function(item)
    if not item then return end
    vim.ui.input({prompt = 'Proje adı: '}, function(name)
      if not name or vim.trim(name) == '' then return end
      name = vim.trim(name)
      vim.ui.input({prompt = 'Üst klasör: ', default = vim.g.project_home or '~/Projeler', completion = 'dir'}, function(parent)
        if not parent or vim.trim(parent) == '' then return end
        M.create(item.id, parent, name, function(root, err)
          if not root then vim.notify(err, vim.log.levels.ERROR, {title = 'Yeni proje'}); return end
          -- A slow tool must not steal focus from work started while it ran.
          if vim.api.nvim_get_current_buf() ~= origin_buf or vim.api.nvim_get_current_win() ~= origin_win
              or vim.fn.getcwd() ~= origin_cwd or not clean_buffers() then
            vim.notify('Proje oluşturuldu: ' .. root .. '\nAna dosya: ' .. item.main)
            return
          end
          local opened, open_error = pcall(function()
            vim.cmd.cd(vim.fn.fnameescape(root))
            vim.cmd.edit(vim.fn.fnameescape(root .. '/' .. item.main))
          end)
          if not opened then
            vim.notify('Proje oluşturuldu: ' .. root .. '\nDosya açılamadı: ' .. tostring(open_error), vim.log.levels.WARN)
            return
          end
          -- A long/multiline :echo causes a blocking hit-enter prompt when
          -- Noice is disabled. The opened source already identifies the project.
          vim.notify('Proje hazır')
        end)
      end)
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command('ProjeYeni', M.open, {desc = 'Dil seçerek yeni proje oluştur'})
  vim.keymap.set('n', '<leader>cn', M.open, {desc = 'Yeni proje oluştur'})
  vim.keymap.set('n', '<C-n>', M.open, {desc = 'Yeni proje oluştur'})
end

return M
