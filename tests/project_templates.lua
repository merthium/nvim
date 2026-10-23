local function check()
  vim.opt.rtp:prepend(vim.fn.stdpath('config'))
  local templates = require('custom.ide.templates')
  local expected = {
    csharp = {'Program.cs', 'Demo-One_2.csproj'}, cpp = {'main.cpp', 'Makefile'},
    c = {'main.c', 'Makefile'}, opengl = {'main.cpp', 'CMakeLists.txt', 'Makefile'}, rust = {'src/main.rs', 'Cargo.toml'},
    python = {'main.py', 'pyproject.toml'}, go = {'main.go', 'go.mod'},
    asm = {'main.asm', 'Makefile'}, java = {'src/main/java/Main.java', 'pom.xml'},
    javascript = {'src/main.js', 'package.json'}, typescript = {'src/main.ts', 'tsconfig.json'},
    web = {'index.html', 'style.css', 'main.js'}, react = {'src/main.tsx', 'package.json', 'vite.config.ts'},
    vue = {'src/main.ts', 'src/App.vue', 'package.json', 'vite.config.ts'},
    ruby = {'main.rb', 'Gemfile'}, php = {'main.php', 'composer.json'},
    swift = {'Sources/App/main.swift', 'Package.swift'}, kotlin = {'src/main/kotlin/Main.kt', 'build.gradle.kts'},
    dart = {'bin/main.dart', 'pubspec.yaml'}, lua = {'main.lua', '.luarc.json'},
    bash = {'main.sh', 'Makefile'}, r = {'main.R', 'Demo-One_2.Rproj'},
    julia = {'src/main.jl', 'Project.toml'}, perl = {'main.pl', 'Makefile'},
    haskell = {'app/Main.hs', 'app-demoone2.cabal', 'cabal.project'},
    elixir = {'lib/app.ex', 'mix.exs'}, scala = {'src/main/scala/Main.scala', 'build.sbt', 'project/build.properties'},
    clojure = {'src/app/core.clj', 'deps.edn'}, fsharp = {'Program.fs', 'Demo-One_2.fsproj'},
    fortran = {'main.f90', 'CMakeLists.txt'}, ocaml = {'bin/main.ml', 'bin/dune', 'dune-project'},
    zig = {'src/main.zig', 'build.zig'}, sql = {'main.sql', 'Makefile'},
  }
  local seen, specs = {}, {}
  local old_system, old_executable = vim.system, vim.fn.executable
  vim.system = function() error('render must not execute tools') end
  vim.fn.executable = function() return 0 end
  for _, item in ipairs(templates.list()) do
    assert(expected[item.id] and not seen[item.id], 'unexpected or duplicate template: ' .. item.id)
    seen[item.id] = true
    local spec, err = templates.render(item.id, 'Demo-One_2')
    assert(spec, err)
    specs[item.id] = spec
    assert(spec.main == item.main and spec.files[spec.main], item.id .. ': main source must exist')
    assert(type(spec.label) == 'string' and #spec.tools > 0, item.id .. ': missing metadata')
    for _, file in ipairs(expected[item.id]) do
      assert(type(spec.files[file]) == 'string' and #spec.files[file] > 0, item.id .. ': missing ' .. file)
    end
    for file, content in pairs(spec.files) do
      assert(file:sub(1, 1) ~= '/' and not file:find('..', 1, true), 'unsafe generated path: ' .. file)
      assert(content:sub(-1) == '\n', item.id .. ': missing final newline in ' .. file)
      if file:match('%.json$') then assert(vim.json.decode(content), 'invalid JSON in ' .. file) end
    end
    assert(#spec.tasks.run > 0, item.id .. ': no run action')
    for action, steps in pairs(spec.tasks) do
      assert(vim.tbl_contains({'run', 'build', 'test', 'setup'}, action), 'unknown action')
      for _, argv in ipairs(steps) do
        assert(type(argv) == 'table' and #argv > 0, 'actions must be argv sequences')
        for _, arg in ipairs(argv) do assert(type(arg) == 'string' and #arg > 0, 'invalid argv') end
        if action == 'run' then
          assert(not (argv[1] == 'npm' and argv[2] == 'install'), 'run must not install dependencies')
        end
      end
    end
  end
  vim.system, vim.fn.executable = old_system, old_executable
  for id in pairs(expected) do assert(seen[id], 'missing template: ' .. id) end
  local missing, reason = templates.render('unknown', 'Demo')
  assert(not missing and type(reason) == 'string', 'unknown template must report error')
  local menu = templates.list()
  menu[1].tools[1], menu[1].label = 'broken', 'broken'
  assert(templates.list()[1].tools[1] ~= 'broken', 'menu must not expose mutable registry state')
  specs.javascript.tasks.run[1][1] = 'broken'
  assert(templates.render('javascript', 'Fresh').tasks.run[1][1] == 'node', 'render must return fresh actions')
  for _, name in ipairs({'A', 'type', 'class', 'Demo-', 'Demo_'}) do
    for id in pairs(expected) do assert(templates.render(id, name), id .. ': valid project name rejected') end
  end

  local base = vim.fn.tempname() .. ' template projects [test]'
  vim.fn.mkdir(base, 'p')
  local function save(id)
    local root, spec = base .. '/' .. id, templates.render(id, 'Demo-One_2')
    for file, content in pairs(spec.files) do
      local path = root .. '/' .. file
      vim.fn.mkdir(vim.fs.dirname(path), 'p')
      local fd = assert(io.open(path, 'wb'))
      fd:write(content); fd:close()
    end
    return root, spec
  end
  local run_ids = {'python', 'javascript', 'lua', 'bash', 'perl', 'sql', 'java'}
  for _, id in ipairs(run_ids) do
    local root, spec = save(id)
    local available = true
    for _, tool in ipairs(spec.tools) do if vim.fn.executable(tool) ~= 1 then available = false end end
    if available then
      local output = ''
      for _, argv in ipairs(spec.tasks.run) do
        -- Use a PTY, like the IDE runner, instead of vim.system's socket stdio.
        local chunks = {}
        local job = vim.fn.jobstart(argv, {cwd = root, pty = true,
          on_stdout = function(_, data) vim.list_extend(chunks, data) end})
        local code = vim.fn.jobwait({job}, 30000)[1]
        local text = table.concat(chunks, '\n')
        assert(code == 0, id .. ': ' .. text)
        output = output .. text
      end
      assert(output:find('Hello, world!', 1, true), id .. ': starter must print its greeting')
      print('PASS: template run ' .. id)
    end
  end
  local python_root = save('python')
  if vim.fn.executable('python3') == 1 then
    local result = vim.system({'python3', '-m', 'unittest', 'discover', '-s', 'tests'}, {cwd = python_root, text = true}):wait(30000)
    assert(result.code == 0, result.stderr)
  end
  vim.fn.delete(base, 'rf')
  print('PASS: 32 offline templates, manifests, safe names/paths, isolated renders, runnable starters')
end

local ok, err = xpcall(check, debug.traceback)
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
