local M = {}
M.executables = {'clangd', 'basedpyright-langserver', 'ruff', 'rust-analyzer', 'zls',
  'csharp-ls', 'lua-language-server', 'vtsls', 'jdtls', 'gopls', 'bash-language-server',
  'vscode-html-language-server', 'vscode-css-language-server', 'vscode-json-language-server',
  'clang-format', 'stylua', 'shfmt', 'prettier', 'codelldb', 'debugpy-adapter'}

-- Names/commands come from the installed nvim-lspconfig definitions. Missing
-- executables stay disabled; this never asks Mason to install a language stack.
M.server_commands = {
  clangd = 'clangd', lua_ls = 'lua-language-server', basedpyright = 'basedpyright-langserver',
  ruff = 'ruff', zls = 'zls', csharp_ls = 'csharp-ls', gopls = 'gopls', vtsls = 'vtsls',
  bashls = 'bash-language-server', html = 'vscode-html-language-server',
  cssls = 'vscode-css-language-server', jsonls = 'vscode-json-language-server',
  yamlls = 'yaml-language-server', taplo = 'taplo', marksman = 'marksman',
  dockerls = 'docker-langserver', docker_compose_language_service = 'docker-compose-langserver',
  intelephense = 'intelephense', solargraph = 'solargraph', dartls = 'dart',
  kotlin_language_server = 'kotlin-language-server', elixirls = 'elixir-ls',
  svelte = 'svelteserver', denols = 'deno', vue_ls = 'vue-language-server',
  sourcekit = 'sourcekit-lsp', fsautocomplete = 'fsautocomplete', metals = 'metals',
  clojure_lsp = 'clojure-lsp', hls = 'haskell-language-server-wrapper', ocamllsp = 'ocamllsp',
  perlnavigator = 'perlnavigator', fortls = 'fortls', sqlls = 'sql-language-server',
}

function M.tools_for(ft)
  local commands = vim.tbl_extend('force', M.server_commands, {rust_analyzer = 'rust-analyzer', jdtls = 'jdtls'})
  local tools = {}
  for name, command in pairs(commands) do
    if #vim.api.nvim_get_runtime_file('lsp/' .. name .. '.lua', false) > 0 then
      local config = vim.lsp.config[name]
      if config and vim.tbl_contains(config.filetypes or {}, ft) then
        tools[#tools + 1] = {name = name, command = command, path = vim.fn.exepath(command)}
      end
    end
  end
  table.sort(tools, function(a, b) return a.name < b.name end)
  return tools
end

function M.file_operations()
  return {dynamicRegistration = true, didCreate = true, willCreate = true,
    didRename = true, willRename = true, didDelete = true, willDelete = true}
end

function M.capabilities()
  local capabilities = require('blink.cmp').get_lsp_capabilities()
  capabilities.workspace = capabilities.workspace or {}
  capabilities.workspace.fileOperations = M.file_operations()
  return capabilities
end

function M.servers()
  local servers = {}
  local function configure(name, options) servers[name] = options end
  local capabilities = M.capabilities()
  configure('*', {capabilities = capabilities})
  configure('clangd', {
    -- Paste/redo can split UTF-8 characters across updates. Incremental JSON then
    -- becomes invalid and clangd loses sync; send the complete debounced buffer.
    flags = {allow_incremental_sync = false},
    cmd = {'clangd', '--background-index', '--background-index-priority=low', '--completion-style=detailed',
      '--header-insertion=iwyu', '--header-insertion-decorators', '--enable-config', '--malloc-trim', '--pch-storage=memory',
      '--query-driver=/usr/bin/cc,/usr/bin/gcc,/usr/bin/g++,/usr/bin/clang,/usr/bin/clang++'},
    root_markers = {'compile_commands.json', 'Kbuild', 'CMakeLists.txt', 'Makefile', '.clangd', '.git'},
  })
  configure('lua_ls', {settings = {Lua = {
    runtime = {version = 'LuaJIT'}, workspace = {checkThirdParty = false, library = {vim.env.VIMRUNTIME}},
    completion = {callSnippet = 'Replace'}, telemetry = {enable = false}, hint = {enable = true},
  }}})
  configure('basedpyright', {
    before_init = function(_, config)
      config.settings.python = config.settings.python or {}
      config.settings.python.pythonPath = require('custom.ide.project').python_at(config.root_dir or vim.fn.getcwd())
    end,
    settings = {basedpyright = {analysis = {typeCheckingMode = 'standard', diagnosticMode = 'workspace', autoImportCompletions = true}}},
  })
  configure('ruff', {on_attach = function(c) c.server_capabilities.hoverProvider = false end})
  configure('zls', {
    root_markers = {'zls.json', 'build.zig', '.algo-workshop', '.git'},
    settings = {zls = {enable_build_on_save = true, enable_inlay_hints = true}},
  })
  configure('csharp_ls', {settings = {csharp = {analyzersEnabled = true}}})
  configure('sourcekit', {filetypes = {'swift', 'objc', 'objcpp'}})
  configure('gopls', {settings = {gopls = {gofumpt = true, staticcheck = true,
    hints = {assignVariableTypes = true, parameterNames = true, rangeVariableTypes = true}}}})
  local hints = {parameterNames = {enabled = 'literals'}, parameterTypes = {enabled = true},
    variableTypes = {enabled = true}, propertyDeclarationTypes = {enabled = true},
    functionLikeReturnTypes = {enabled = true}, enumMemberValues = {enabled = true}}
  configure('vtsls', {
    root_dir = function(buf, on_dir)
      local root = vim.fs.root(buf, {'package.json', 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock'})
      local deno = vim.fs.root(buf, {'deno.json', 'deno.jsonc', 'deno.lock'})
      if deno and (not root or #deno >= #root) then return end
      on_dir(root or require('custom.ide.project').root(buf))
    end,
    settings = {
    vtsls = {autoUseWorkspaceTsdk = true},
    typescript = {updateImportsOnFileMove = {enabled = 'always'}, inlayHints = hints},
    javascript = {updateImportsOnFileMove = {enabled = 'always'}, inlayHints = hints},
  }})
  -- Deno and Node projects must not attach competing TypeScript servers.
  configure('denols', {root_dir = function(buf, on_dir)
    local root = vim.fs.root(buf, {'deno.json', 'deno.jsonc', 'deno.lock'})
    local node = vim.fs.root(buf, {'package.json', 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock'})
    if root and (not node or #root >= #node) then on_dir(root) end
  end})
  -- Vue 3 uses a Vue server plus a TypeScript plugin in vtsls.
  local vue_exe = vim.fn.exepath('vue-language-server')
  local vue_real = vue_exe ~= '' and vim.uv.fs_realpath(vue_exe) or nil
  local vue_candidates = {vim.fn.stdpath('data') .. '/mason/packages/vue-language-server/node_modules/@vue/language-server'}
  if vue_real then vue_candidates[#vue_candidates + 1] = vim.fs.dirname(vim.fs.dirname(vue_real)) end
  local vue_package
  for _, path in ipairs(vue_candidates) do
    if vim.fn.filereadable(path .. '/package.json') == 1 then
      local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path .. '/package.json'), '\n')) end)
      if ok and type(data) == 'table' and data.name == '@vue/language-server' then vue_package = path; break end
    end
  end
  if vue_package then
    servers.vtsls.filetypes = {'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue'}
    servers.vtsls.settings.vtsls.tsserver = {globalPlugins = {{
      name = '@vue/typescript-plugin', location = vue_package, languages = {'vue'},
      configNamespace = 'typescript', enableForWorkspaceTypeScriptVersions = true,
    }}}
  end
  for name, exe in pairs(M.server_commands) do
    servers[name] = servers[name] or {}
    servers[name].mason = false
    servers[name].enabled = vim.fn.executable(exe) == 1
  end
  servers.vue_ls.enabled = servers.vue_ls.enabled and vue_package ~= nil and servers.vtsls.enabled
  return servers
end

function M.setup()
  for name, opts in pairs(M.servers()) do
    local enabled = opts.enabled ~= false
    opts = vim.deepcopy(opts)
    opts.mason, opts.enabled = nil, nil
    vim.lsp.config(name, opts)
    if name ~= '*' and enabled then vim.lsp.enable(name) end
  end
end

function M.java()
  local function start()
    if vim.fn.executable('jdtls') == 0 then return end
    local root = require('jdtls.setup').find_root({'gradlew', 'mvnw', 'pom.xml', 'build.gradle', 'build.gradle.kts', '.git'})
      or vim.fs.dirname(vim.api.nvim_buf_get_name(0))
    local workspace = vim.fn.stdpath('cache') .. '/jdtls/' .. vim.fn.sha256(root)
    local base = vim.fn.stdpath('data') .. '/mason/packages/'
    local bundles = vim.fn.glob(base .. 'java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar', false, true)
    for _, jar in ipairs(vim.fn.glob(base .. 'java-test/extension/server/*.jar', false, true)) do
      local name = vim.fs.basename(jar)
      if name ~= 'com.microsoft.java.test.runner-jar-with-dependencies.jar' and name ~= 'jacocoagent.jar' then bundles[#bundles + 1] = jar end
    end
    require('jdtls').start_or_attach({
      cmd = {'jdtls', '-data', workspace}, root_dir = root,
      capabilities = M.capabilities(), init_options = {bundles = bundles},
      settings = {java = {signatureHelp = {enabled = true}, inlayHints = {parameterNames = {enabled = 'all'}},
        configuration = {updateBuildConfiguration = 'automatic'}}},
      on_attach = function(_, buf)
        require('dap')
        require('jdtls').setup_dap({hotcodereplace = 'auto'})
        require('jdtls.dap').setup_dap_main_class_configs()
        vim.keymap.set('n', '<leader>ct', require('jdtls').test_nearest_method, {buffer = buf, desc = 'Java: en yakın testi debug et'})
        vim.keymap.set('x', '<leader>cm', function() require('jdtls').extract_method(true) end, {buffer = buf, desc = 'Java: metot çıkar'})
      end,
    })
  end
  vim.api.nvim_create_autocmd('FileType', {group = vim.api.nvim_create_augroup('IDEJava', {clear = true}), pattern = 'java', callback = start})
  if vim.bo.filetype == 'java' then start() end
end

return M
