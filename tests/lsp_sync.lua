-- Run with the real config: nvim --headless -i NONE '+lua dofile(vim.fn.stdpath("config") .. "/tests/lsp_sync.lua")'
local function check()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, 'p')
  local source = root .. '/paste.cpp'
  vim.fn.writefile({'int original;'}, source)
  vim.cmd.edit(vim.fn.fnameescape(source))
  vim.bo.undofile = false
  local buf = vim.api.nvim_get_current_buf()
  local client
  assert(vim.wait(10000, function()
    client = vim.lsp.get_clients({bufnr = buf, name = 'clangd'})[1]
    return client and client.initialized
  end, 50), 'clangd must attach')

  local function symbols()
    local response, err = client:request_sync('textDocument/documentSymbol', {
      textDocument = {uri = vim.uri_from_bufnr(buf)},
    }, 10000, buf)
    assert(response and not response.err, vim.inspect(response or err))
    return vim.tbl_map(function(symbol) return symbol.name end, response.result)
  end
  assert(vim.deep_equal(symbols(), {'original'}), 'initial document must be analyzed')

  -- Terminal paste/redo can split a UTF-8 character between buffer updates.
  -- Both pieces arrive before the debounce flush; the resulting buffer is valid.
  vim.api.nvim_buf_set_text(buf, 0, 0, 0, 0, {'// ' .. string.char(0xc4)})
  vim.api.nvim_buf_set_text(buf, 0, 4, 0, 4, {string.char(0xb1), 'int pasted;', ''})
  assert(vim.deep_equal(symbols(), {'pasted', 'original'}),
    'clangd must receive the complete Unicode paste, not silently discard invalid chunks')

  vim.api.nvim_buf_set_lines(buf, 2, 3, false, {})
  assert(vim.deep_equal(symbols(), {'pasted'}), 'deleting lines after paste must stay synchronized')
  local tokens = client:request_sync('textDocument/semanticTokens/full', {
    textDocument = {uri = vim.uri_from_bufnr(buf)},
  }, 10000, buf)
  assert(tokens and not tokens.err and #tokens.result.data > 0, 'semantic analysis must still work')
  vim.lsp.stop_client(client.id)
  vim.wait(3000, function() return client:is_stopped() end, 20)
  vim.api.nvim_buf_delete(buf, {force = true})
  vim.fn.delete(root, 'rf')
  print('PASS: Unicode paste, subsequent deletion, and semantic tokens stay synchronized')
end
local ok, err = xpcall(check, debug.traceback)
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
