local M = {}
local tabs = {}
local api = vim.api
local hover, hitboxes = nil, {}

local function source(buf)
  return buf and api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == ''
    and vim.fn.isdirectory(api.nvim_buf_get_name(buf)) == 0
end

local function document(buf)
  return source(buf) and (api.nvim_buf_get_name(buf) ~= '' or vim.bo[buf].modified)
end

local function documents()
  local files = {}
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if document(buf) and vim.bo[buf].buflisted then files[#files + 1] = buf end
  end
  return files
end

local function state()
  local tab = api.nvim_get_current_tabpage()
  tabs[tab] = tabs[tab] or {}
  return tabs[tab]
end

local function remember()
  local s, buf = state(), api.nvim_get_current_buf()
  if source(buf) then
    s.buf, s.win = buf, api.nvim_get_current_win()
    if api.nvim_buf_get_name(buf) ~= '' then s.root = require('custom.ide.project').root(buf) end
  end
end

function M.focus_source()
  local s = state()
  local wins = api.nvim_tabpage_list_wins(0)
  if s.win and vim.tbl_contains(wins, s.win) and source(api.nvim_win_get_buf(s.win)) then
    api.nvim_set_current_win(s.win)
    return true
  end
  for _, win in ipairs(wins) do
    if vim.bo[api.nvim_win_get_buf(win)].buftype == '' and api.nvim_win_get_config(win).relative == '' then
      api.nvim_set_current_win(win)
      return true
    end
  end
  return false
end

function M.select(buf, _, button)
  if not source(buf) then return end
  if button == 'm' then return Snacks.bufdelete(buf) end
  if not M.focus_source() then vim.cmd('rightbelow vnew') end
  api.nvim_set_current_buf(buf)
  remember()
end

function M.explorer(automatic)
  local s = state()
  local open = Snacks.picker.get({source = 'explorer'})
  for _, picker in ipairs(open) do
    if picker:on_current_tab() then
      if not automatic then picker:close() end
      return
    end
  end
  Snacks.explorer({cwd = s.root or vim.fn.getcwd(), enter = not automatic})
end

function M.action(id)
  if id == 1 then return M.explorer(false) end
  if id == 6 then return vim.cmd.KolayTuslar() end
  if id == 7 then return require('custom.ide.tasks').stop() end
  if not M.focus_source() then return end
  local buf = api.nvim_get_current_buf()
  if id == 2 then
    if api.nvim_buf_get_name(buf) ~= '' then return vim.cmd.update() end
    vim.ui.input({prompt = 'Dosyayı kaydet: ', default = (state().root or vim.fn.getcwd()) .. '/', completion = 'file'}, function(path)
      if not path or path == '' or not api.nvim_buf_is_valid(buf) then return end
      local ok, err = pcall(api.nvim_buf_call, buf, function() vim.cmd('write ' .. vim.fn.fnameescape(path)) end)
      if not ok then vim.notify(err, vim.log.levels.ERROR) end
    end)
  elseif (id == 3 or id == 4) and api.nvim_buf_get_name(buf) == '' then
    vim.notify('Önce dosyaya bir ad verip kaydet.', vim.log.levels.WARN)
  elseif id == 3 then
    require('custom.ide.tasks').run('run')
  elseif id == 4 then
    require('custom.ide.debug').start()
  elseif id == 5 then
    require('trouble').toggle('diagnostics')
  end
end

local function escape(text) return text:gsub('%%', '%%%%') end

function M.tabline()
  hitboxes = {}
  local files, selected = documents(), 1
  if #files < 2 then return '' end
  local current = state().buf
  for i, buf in ipairs(files) do if buf == current then selected = i end end
  local budget = math.max(12, vim.o.columns - 2)
  local entries, names = {}, {}
  for _, buf in ipairs(files) do
    local name = vim.fs.basename(api.nvim_buf_get_name(buf))
    names[name] = (names[name] or 0) + 1
  end
  local function label(buf)
    local path = api.nvim_buf_get_name(buf)
    local name = vim.fs.basename(path)
    if names[name] > 1 then name = path == '' and (name .. ' ' .. buf) or (vim.fs.basename(vim.fs.dirname(path)) .. '/' .. name) end
    local limit = math.max(6, math.min(32, budget - 5))
    if vim.fn.strdisplaywidth(name) > limit then
      while vim.fn.strdisplaywidth(name) > limit - 1 do name = vim.fn.strcharpart(name, 0, vim.fn.strchars(name) - 1) end
      name = name .. '…'
    end
    return ' ' .. name .. (vim.bo[buf].modified and ' +' or '') .. ' '
  end
  local left, right, length = selected, selected, files[selected] and vim.fn.strdisplaywidth(label(files[selected])) or 0
  while files[left - 1] and length + vim.fn.strdisplaywidth(label(files[left - 1])) <= budget do
    left = left - 1
    length = length + vim.fn.strdisplaywidth(label(files[left]))
  end
  while files[right + 1] and length + vim.fn.strdisplaywidth(label(files[right + 1])) <= budget do
    right = right + 1
    length = length + vim.fn.strdisplaywidth(label(files[right]))
  end
  local column = 0
  for i = left, right do
    local buf = files[i]
    if buf then
      local name = label(buf)
      local group = hover == 'buffer:' .. buf and 'IDETabHover' or (buf == current and 'TabLineSel' or 'TabLine')
      entries[#entries + 1] = ('%%#%s#%%%d@v:lua.NeovimIDE.select@%s%%T'):format(
        group, buf, escape(name))
      local width = vim.fn.strdisplaywidth(name)
      hitboxes[#hitboxes + 1] = {first = column, last = column + width, target = 'buffer:' .. buf}
      column = column + width
    end
  end
  return table.concat(entries) .. '%#TabLineFill#%='
end

function M.mouse_move()
  require('custom.mouse').follow_terminal()
  local mouse, target = vim.fn.getmousepos(), nil
  if vim.o.showtabline > 0 and mouse.screenrow == 1 then
    local column = mouse.screencol - 1
    for _, box in ipairs(hitboxes) do
      if column >= box.first and column < box.last then target = box.target; break end
    end
  end
  if target ~= hover then
    hover = target
    vim.cmd.redrawtabline()
  end
end

function M.has_document()
  return document(state().buf or api.nvim_get_current_buf()) or false
end

function M.project_name()
  return vim.fs.basename(state().root or vim.fn.getcwd())
end

function M.analysis_status()
  local buf = state().buf
  if not source(buf) then return '' end
  local clients = vim.lsp.get_clients({bufnr = buf})
  if #clients == 0 then return '' end
  for _, client in ipairs(clients) do
    if not client.initialized then return 'Analiz: başlıyor' end
  end
  return 'Analiz: hazır'
end

function M.setup()
  _G.NeovimIDE = M
  vim.o.showtabline = 0
  vim.o.tabline = '%!v:lua.NeovimIDE.tabline()'
  vim.o.mousemoveevent = true
  vim.keymap.set({'n', 'i', 'x', 's', 't', 'c'}, '<MouseMove>', M.mouse_move, {desc = 'Sekme vurgusu'})
  local group = api.nvim_create_augroup('LocalIDELayout', {clear = true})
  -- Splits copy window options, but not the saved options of a blank editor.
  local inherited_options
  api.nvim_create_autocmd({'WinNewPre', 'WinLeave'}, {group = group, callback = function()
    inherited_options = vim.w.ide_empty_options
  end})
  api.nvim_create_autocmd('WinNew', {group = group, callback = function()
    if inherited_options and api.nvim_win_get_config(0).relative == '' then
      vim.w.ide_empty_options = inherited_options
    end
    inherited_options = nil
  end})
  api.nvim_create_autocmd({'FocusLost', 'VimResized'}, {group = group, callback = function()
    hover = nil
    vim.cmd.redrawtabline()
  end})
  local function enter()
    remember()
    vim.o.showtabline = #documents() > 1 and 2 or 0
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
      local buf = api.nvim_win_get_buf(win)
      if source(buf) and api.nvim_win_get_config(win).relative == '' then
        local saved = vim.w[win].ide_empty_options
        if not document(buf) and not saved then
          local options = {}
          for _, name in ipairs({'number', 'relativenumber', 'cursorline', 'signcolumn'}) do options[name] = vim.wo[win][name] end
          vim.w[win].ide_empty_options = options
          vim.wo[win].number, vim.wo[win].relativenumber, vim.wo[win].cursorline = false, false, false
          vim.wo[win].signcolumn = 'no'
        elseif document(buf) and saved then
          for name, value in pairs(saved) do vim.wo[win][name] = value end
          vim.w[win].ide_empty_options = nil
        end
      end
    end
    vim.cmd.redrawtabline()
  end
  api.nvim_create_autocmd({'BufEnter', 'WinEnter', 'UIEnter', 'BufFilePost', 'BufWritePost', 'BufModifiedSet'}, {group = group, callback = enter})
  api.nvim_create_autocmd('TabClosed', {group = group, callback = function()
    for tab in pairs(tabs) do if not api.nvim_tabpage_is_valid(tab) then tabs[tab] = nil end end
  end})
  api.nvim_create_autocmd({'BufAdd', 'BufDelete'}, {group = group, callback = function() vim.schedule(enter) end})
  enter()
end

return M
