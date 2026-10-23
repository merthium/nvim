local M = {}
local project = require('custom.ide.project')

local methods = {
  {'Yeniden adlandır', 'textDocument/rename'},
  {'Kod eylemi', 'textDocument/codeAction'},
  {'Dosya sembolleri', 'textDocument/documentSymbol'},
  {'Proje sembolleri', 'workspace/symbol'},
}

function M.supports(method, buf)
  return #vim.lsp.get_clients({bufnr = buf or 0, method = method}) > 0
end

local function ready(method)
  if M.supports(method) then return true end
  local ft = vim.bo.filetype ~= '' and vim.bo.filetype or 'bu dosya'
  local reason = #vim.lsp.get_clients({bufnr = 0}) == 0
    and 'Dil sunucusu bağlı değil' or 'Bağlı dil sunucusu bu işlemi desteklemiyor'
  vim.notify(reason .. ' (' .. ft .. '). Araç ve bağlantı durumu: :IDEInfo', vim.log.levels.WARN)
  return false
end

function M.rename()
  if ready('textDocument/rename') then vim.lsp.buf.rename() end
end

function M.code_action()
  if ready('textDocument/codeAction') then vim.lsp.buf.code_action() end
end

function M.symbols()
  if ready('textDocument/documentSymbol') then
    Snacks.picker.lsp_symbols({cwd = project.root()})
  end
end

function M.workspace_symbols()
  if ready('workspace/symbol') then
    Snacks.picker.lsp_workspace_symbols({cwd = project.root(), filter = {cwd = true}})
  end
end

function M.outline()
  local trouble = require('trouble')
  if trouble.is_open('symbols') then
    local view = trouble.close('symbols')
    -- Trouble also reports pending LSP views as open. Close again after the
    -- first render so an in-flight response cannot reopen a dismissed outline.
    if view then view:wait(function() view:close() end) end
  elseif ready('textDocument/documentSymbol') then
    trouble.open({mode = 'symbols', focus = false})
  end
end

function M.files() Snacks.picker.files({cwd = project.root()}) end
function M.grep() Snacks.picker.grep({cwd = project.root()}) end

function M.terminal()
  local root = project.root()
  local terminal = Snacks.terminal.toggle(nil, {cwd = root, win = {position = 'bottom', height = 0.3}})
  -- Terminals have no file path; keep their origin when invoking project actions.
  if terminal and terminal.buf then vim.b[terminal.buf].workflow_root = root end
end

function M.diagnostics()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  if #vim.diagnostic.get(0, {lnum = line}) == 0 then
    vim.notify('Bu satırda hata veya uyarı yok.', vim.log.levels.INFO)
    return
  end
  vim.diagnostic.open_float({scope = 'line', source = true})
end

function M.info()
  local buf, ft = vim.api.nvim_get_current_buf(), vim.bo.filetype
  local lines = {'Proje: ' .. project.root(buf), 'Dosya türü: ' .. (ft ~= '' and ft or 'belirsiz'), '', 'Bağlı dil sunucuları:'}
  local clients = vim.lsp.get_clients({bufnr = buf})
  table.sort(clients, function(a, b) return a.name < b.name end)
  for _, client in ipairs(clients) do
    lines[#lines + 1] = ('  %s — %s'):format(client.name, client.root_dir or 'tek dosya')
  end
  if #clients == 0 then lines[#lines + 1] = '  Yok; sunucu kurulmuş olsa da başlatılması gerekebilir.' end
  vim.list_extend(lines, {'', 'Bu dosyada kullanılabilen işlemler:'})
  for _, item in ipairs(methods) do
    lines[#lines + 1] = ('  %s: %s'):format(item[1], M.supports(item[2], buf) and 'hazır' or 'destekleyen sunucu bağlı değil')
  end
  vim.list_extend(lines, {'', 'Bu dosyanın dil araçları:'})
  local tools = require('custom.ide.languages').tools_for(ft)
  for _, tool in ipairs(tools) do
    lines[#lines + 1] = ('  %s: %s'):format(tool.name, tool.path ~= '' and tool.path or 'kurulu değil (' .. tool.command .. ')')
  end
  if #tools == 0 then lines[#lines + 1] = '  Bu dosya türü için yapılandırılmış sunucu yok.' end
  local ok, conform = pcall(require, 'conform')
  if ok then
    vim.list_extend(lines, {'', 'Biçimlendirme araçları:'})
    local formatters = conform.list_formatters_for_buffer(buf)
    for _, name in ipairs(formatters) do
      local formatter = conform.get_formatter_info(name, buf)
      lines[#lines + 1] = ('  %s: %s'):format(name, formatter.available
        and (formatter.command or 'hazır') or ('hazır değil — ' .. (formatter.available_msg or 'kurulu değil')))
    end
    if #formatters == 0 then lines[#lines + 1] = '  Yok; varsa dil sunucusunun biçimlendirmesi kullanılır.' end
  end
  vim.list_extend(lines, {'', ':Mason — yalnızca ihtiyaç duyduğun dil aracını kur',
    ':checkhealth vim.lsp — bağlantıyı incele; :LspLog — sunucu günlüğü',
    ':ConformInfo — biçimlendirme ayrıntıları',
    'Araç kurduktan sonra Neovim’i yeniden aç. Space ? — günlük tuşlar'})
  Snacks.win({text = table.concat(lines, '\n'), enter = true, width = 0.85, height = 0.75,
    title = ' IDE · Dosya ve araç durumu ', border = 'single', ft = 'markdown',
    bo = {modifiable = false}, wo = {wrap = true}, keys = {q = 'close', ['<Esc>'] = 'close'}})
end

return M
