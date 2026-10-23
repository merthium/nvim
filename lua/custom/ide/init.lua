local M = {}

function M.status()
  local clients = vim.lsp.get_clients({bufnr = 0})
  local names = {}
  for _, c in ipairs(clients) do names[#names + 1] = c.name end
  table.sort(names)
  if #names == 0 then return '' end
  return table.concat(names, '+')
end

function M.info()
  local lines = {
    '# Geliştirme ortamı', '',
    'Proje: ' .. require('custom.ide.project').root(),
    'Dosya türü: ' .. vim.bo.filetype,
    'Python: ' .. require('custom.ide.project').python(), '', 'Bağlı dil sunucuları:',
  }
  for _, c in ipairs(vim.lsp.get_clients({bufnr = 0})) do
    lines[#lines + 1] = ('- %s — %s'):format(c.name, c.root_dir or 'tek dosya')
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = 'Araçlar (eksikleri :Mason ile kurabilirsin):'
  for _, exe in ipairs(require('custom.ide.languages').executables) do
    local path = vim.fn.exepath(exe)
    lines[#lines + 1] = ('- %s: %s'):format(exe, path ~= '' and path or 'KURULU DEĞİL')
  end
  vim.list_extend(lines, {'', ':checkhealth vim.lsp — ayrıntılı LSP durumu',
    ':ConformInfo — biçimlendiriciler', ':Mason — araç yöneticisi',
    ':OverseerRun — proje görevleri', ':help dap — hata ayıklama',
    'Space ? — günlük tuşlar; Space tuşundan sonra bekle — komut menüsü'})
  vim.cmd.new()
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype, vim.bo[buf].bufhidden, vim.bo[buf].swapfile = 'nofile', 'wipe', false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype, vim.bo[buf].modifiable = 'markdown', false
  vim.keymap.set('n', 'q', '<cmd>close<cr>', {buffer = buf, desc = 'Kapat'})
end

function M.attach(client, buf)
  local function map(mode, key, fn, desc)
    vim.keymap.set(mode, key, fn, {buffer = buf, silent = true, desc = desc})
  end
  local lsp = vim.lsp.buf
  map('n', 'gd', lsp.definition, 'Tanıma git')
  map('n', 'gD', lsp.declaration, 'Bildirime git')
  map('n', 'gr', function() require('mini.extra').pickers.lsp({scope = 'references'}) end, 'Kullanımları bul')
  map('n', 'gi', lsp.implementation, 'Uygulamaya git')
  map('n', 'gy', lsp.type_definition, 'Tür tanımına git')
  map('n', 'K', lsp.hover, 'Belgelendirme')
  map('n', '<leader>rn', lsp.rename, 'Sembolü yeniden adlandır')
  map({'n', 'x'}, '<leader>ca', lsp.code_action, 'Kod düzeltmesi / refactoring')
  map('n', '<leader>ch', function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({bufnr = buf}), {bufnr = buf})
  end, 'Tip ve parametre ipuçları')
  map('n', '<leader>ci', lsp.incoming_calls, 'Bu fonksiyonu çağıranlar')
  map('n', '<leader>co', lsp.outgoing_calls, 'Bu fonksiyonun çağrıları')
  map('n', '<leader>cl', vim.lsp.codelens.run, 'CodeLens işlemi')
  map('n', '<leader>ld', vim.diagnostic.open_float, 'Hata açıklaması')
  map('n', '<leader>lq', function() vim.diagnostic.setloclist({open = true}) end, 'Dosya hataları')
  map('n', '<leader>ls', function() require('mini.extra').pickers.lsp({scope = 'workspace_symbol'}) end, 'Proje sembolleri')
  if client.name == 'clangd' then
    map('n', '<leader>ks', function()
      client:request('textDocument/switchSourceHeader', {uri = vim.uri_from_bufnr(buf)}, function(err, uri)
        if err then vim.notify(err.message, vim.log.levels.ERROR)
        elseif uri and uri ~= '' then vim.cmd.edit(vim.fn.fnameescape(vim.uri_to_fname(uri))) end
      end, buf)
    end, 'Kaynak / başlık dosyasına geç')
  end
  if client:supports_method('textDocument/inlayHint', buf) then vim.lsp.inlay_hint.enable(true, {bufnr = buf}) end
  local group = vim.api.nvim_create_augroup('IDEBuffer' .. buf, {clear = false})
  if client:supports_method('textDocument/documentHighlight', buf) and not vim.b[buf].ide_highlight then
    vim.b[buf].ide_highlight = true
    vim.api.nvim_create_autocmd('CursorHold', {group = group, buffer = buf, callback = lsp.document_highlight})
    vim.api.nvim_create_autocmd({'CursorMoved', 'InsertEnter'}, {group = group, buffer = buf, callback = lsp.clear_references})
  end
  if client:supports_method('textDocument/codeLens', buf) and not vim.b[buf].ide_codelens then
    vim.b[buf].ide_codelens = true
    vim.lsp.codelens.enable(true, {bufnr = buf})
  end
end

function M.setup()
  vim.o.signcolumn = 'auto:1'
  vim.o.updatetime = 250
  vim.diagnostic.config({
    virtual_text = {current_line = true, spacing = 2, source = 'if_many'},
    virtual_lines = false,
    signs = {text = {[1] = 'E', [2] = 'W', [3] = 'I', [4] = 'H'}},
    underline = true, update_in_insert = false, severity_sort = true,
    float = {border = 'single', source = true},
  })
  local group = vim.api.nvim_create_augroup('IDE', {clear = true})
  vim.api.nvim_create_autocmd('LspAttach', {group = group, callback = function(e)
    local c = vim.lsp.get_client_by_id(e.data.client_id)
    if c then M.attach(c, e.buf) end
  end})
  vim.api.nvim_create_autocmd('BufWipeout', {group = group, callback = function(e)
    pcall(vim.api.nvim_del_augroup_by_name, 'IDEBuffer' .. e.buf)
  end})
  vim.api.nvim_create_user_command('IDEInfo', M.info, {desc = 'Proje ve dil araçlarının durumu'})
  local function map(key, fn, desc) vim.keymap.set('n', key, fn, {silent = true, desc = desc}) end
  map('<leader>cf', function() require('mini.pick').builtin.files({}, {source = {cwd = require('custom.ide.project').root()}}) end, 'Projede dosya bul')
  map('<leader>cg', function() require('mini.pick').builtin.grep_live({}, {source = {cwd = require('custom.ide.project').root()}}) end, 'Projede metin ara')
  map('<leader>cs', function() require('mini.extra').pickers.lsp({scope = 'document_symbol'}) end, 'Dosya sembolleri')
  map('<leader>cS', function() require('mini.extra').pickers.lsp({scope = 'workspace_symbol'}) end, 'Proje sembolleri')
  map('<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', 'Projenin hata ve uyarıları')
  map('<leader>xq', '<cmd>Trouble qflist toggle<cr>', 'Derleme hataları')
  map('<leader>xb', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', 'Dosyanın hata ve uyarıları')
  map('<leader>cI', M.info, 'Geliştirme ortamı durumu')
  map('<leader>e', function() require('oil').open() end, 'Dosyalar / taşı / yeniden adlandır')
  map('[d', function() vim.diagnostic.jump({count = -1, float = true}) end, 'Önceki hata / uyarı')
  map(']d', function() vim.diagnostic.jump({count = 1, float = true}) end, 'Sonraki hata / uyarı')
  vim.keymap.set({'n', 'x'}, '<leader>f', function()
    require('conform').format({async = true, lsp_format = 'fallback'})
  end, {desc = 'Kodu biçimlendir'})
  vim.ui.select = function(items, opts, callback) require('custom.algo_ui').select(items, opts, callback) end
end

return M
