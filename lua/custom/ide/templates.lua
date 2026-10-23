-- Rendering is deliberately offline: no subprocesses, filesystem writes or tool detection.
local M = {}
local entries, by_id = {}, {}

local function copy(value)
  if type(value) ~= 'table' then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end

local function add(id, label, main, tools, render, notes)
  local item = {id = id, label = label, main = main, tools = tools, notes = notes}
  entries[#entries + 1] = item
  by_id[id] = {item = item, render = render}
end

local function actions(run, build, test, setup)
  return {run = run, build = build, test = test, setup = setup}
end

local function json(value) return vim.json.encode(value) .. '\n' end
local function snake(name) return name:lower():gsub('-', '_') end
local function slug(name) return name:lower():gsub('_', '-'):gsub('%-+', '-'):gsub('%-$', '') end

local function dotnet(name, fsharp)
  local source = fsharp and 'Program.fs' or 'Program.cs'
  local project = name .. (fsharp and '.fsproj' or '.csproj')
  return {
    [source] = fsharp and 'printfn "Hello, world!"\n' or 'Console.WriteLine("Hello, world!");\n',
    [project] = '<Project Sdk="Microsoft.NET.Sdk">\n  <PropertyGroup>\n'
      .. '    <OutputType>Exe</OutputType>\n    <TargetFramework>net10.0</TargetFramework>\n'
      .. (fsharp and '' or '    <ImplicitUsings>enable</ImplicitUsings>\n    <Nullable>enable</Nullable>\n')
      .. '  </PropertyGroup>\n' .. (fsharp and '  <ItemGroup>\n    <Compile Include="Program.fs" />\n  </ItemGroup>\n' or '')
      .. '</Project>\n',
  }, actions({{'dotnet', 'run', '--no-restore'}}, {{'dotnet', 'build', '--no-restore'}}, nil,
    {{'dotnet', 'restore', '--ignore-failed-sources'}})
end

add('csharp', 'C# · .NET konsol', 'Program.cs', {'dotnet'}, function(name) return dotnet(name, false) end,
  '.NET 10 SDK gerekir. İlk çalıştırmadan önce kurulum eylemiyle dotnet restore çalıştır.')

local function native(name, cpp)
  local source = cpp and 'main.cpp' or 'main.c'
  return {
    [source] = cpp and '#include <iostream>\n\nint main() {\n    std::cout << "Hello, world!\\n";\n    return 0;\n}\n'
      or '#include <stdio.h>\n\nint main(void) {\n    puts("Hello, world!");\n    return 0;\n}\n',
    ['CMakeLists.txt'] = 'cmake_minimum_required(VERSION 3.16)\nproject(' .. snake(name) .. ' LANGUAGES '
      .. (cpp and 'CXX' or 'C') .. ')\nset(CMAKE_EXPORT_COMPILE_COMMANDS ON)\n'
      .. 'add_executable(app ' .. source .. ')\ntarget_compile_features(app PRIVATE '
      .. (cpp and 'cxx_std_20' or 'c_std_17') .. ')\ntarget_compile_options(app PRIVATE -Wall -Wextra)\n',
    ['.dev/build.py'] = table.concat(vim.fn.readfile(vim.fn.stdpath('config') .. '/scripts/native_build.py'), '\n') .. '\n',
    ['Makefile'] = table.concat({
      '.PHONY: all run check clean', 'all:', '\tpython3 .dev/build.py build', '',
      'run:', '\tpython3 .dev/build.py run', '', 'check:', '\tpython3 .dev/build.py check', '',
      'clean:', '\tcmake --build build --target clean', '',
    }, '\n'),
  }, actions({{'python3', '.dev/build.py', 'run'}}, {{'python3', '.dev/build.py', 'build'}})
end
add('cpp', 'C++ (CPP) · CMake', 'main.cpp', {'python3', 'cmake', 'c++'}, function(name) return native(name, true) end)
add('c', 'C · CMake', 'main.c', {'python3', 'cmake', 'cc'}, function(name) return native(name, false) end)
add('opengl', 'C++ · OpenGL / GLFW', 'main.cpp', {'python3', 'cmake', 'c++'}, function(name)
  local files, tasks = native(name, true)
  files['CMakeLists.txt'] = files['CMakeLists.txt']
    .. 'find_package(OpenGL REQUIRED)\nfind_package(glfw3 3.3 REQUIRED)\n'
    .. 'target_link_libraries(app PRIVATE glfw OpenGL::GL)\n'
  files['main.cpp'] = table.concat({
    '#include <GLFW/glfw3.h>', '#include <iostream>', '', 'int main() {',
    '    if (!glfwInit()) { std::cerr << "GLFW initialization failed\\n"; return 1; }',
    '    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);',
    '    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);',
    '    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);',
    '    GLFWwindow* window = glfwCreateWindow(800, 600, "OpenGL", nullptr, nullptr);',
    '    if (!window) { glfwTerminate(); return 1; }',
    '    glfwMakeContextCurrent(window);', '    glfwSwapInterval(1);',
    '    while (!glfwWindowShouldClose(window)) {',
    '        if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)',
    '            glfwSetWindowShouldClose(window, GLFW_TRUE);',
    '        int width, height;', '        glfwGetFramebufferSize(window, &width, &height);',
    '        glViewport(0, 0, width, height);', '        glClearColor(0.12f, 0.16f, 0.22f, 1.0f);',
    '        glClear(GL_COLOR_BUFFER_BIT);', '        glfwSwapBuffers(window);', '        glfwPollEvents();',
    '    }', '    glfwDestroyWindow(window);', '    glfwTerminate();', '    return 0;', '}', '',
  }, '\n')
  return files, tasks
end, 'GLFW ve OpenGL geliştirme paketleri gerekir. Modern OpenGL fonksiyonları için ayrıca GLAD gibi bir yükleyici ekle.')

add('rust', 'Rust · Cargo', 'src/main.rs', {'cargo'}, function(name)
  return {
    ['Cargo.toml'] = '[package]\nname = "app_' .. snake(name) .. '"\nversion = "0.1.0"\nedition = "2021"\n\n[dependencies]\n',
    ['src/main.rs'] = 'fn main() {\n    println!("Hello, world!");\n}\n',
  }, actions({{'cargo', 'run', '--offline'}}, {{'cargo', 'build', '--offline'}}, {{'cargo', 'test', '--offline'}}, {{'cargo', 'fetch'}})
end)

add('python', 'Python · pyproject', 'main.py', {'python3'}, function(name)
  return {
    ['main.py'] = 'def main():\n    print("Hello, world!")\n\n\nif __name__ == "__main__":\n    main()\n',
    ['pyproject.toml'] = '[project]\nname = "' .. slug(name) .. '"\nversion = "0.1.0"\nrequires-python = ">=3.10"\ndependencies = []\n',
    ['tests/test_main.py'] = 'import contextlib\nimport io\nimport unittest\n\nfrom main import main\n\n\nclass MainTest(unittest.TestCase):\n    def test_greeting(self):\n        output = io.StringIO()\n        with contextlib.redirect_stdout(output):\n            main()\n        self.assertEqual(output.getvalue(), "Hello, world!\\n")\n',
  }, actions({{'python3', 'main.py'}}, {{'python3', '-m', 'py_compile', 'main.py'}},
    {{'python3', '-m', 'unittest', 'discover', '-s', 'tests'}}, {{'python3', '-m', 'venv', '.venv'}})
end)

add('go', 'Go · modül', 'main.go', {'go'}, function(name)
  return {
    ['go.mod'] = 'module example.com/' .. slug(name) .. '\n\ngo 1.22\n',
    ['main.go'] = 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("Hello, world!")\n}\n',
  }, actions({{'go', 'run', '.'}}, {{'go', 'build', '-o', 'build/app', '.'}}, {{'go', 'test', './...'}}, {{'go', 'mod', 'download'}})
end)

add('asm', 'Assembly · NASM x86-64 Linux', 'main.asm', {'make', 'nasm', 'ld'}, function()
  return {
    ['main.asm'] = table.concat({
      '; NASM, x86-64 Linux', 'global _start', '', 'section .rodata',
      '    message db "Hello, world!", 10', '    length equ $ - message', '',
      'section .text', '_start:', '    mov eax, 1          ; write', '    mov edi, 1          ; stdout',
      '    lea rsi, [rel message]', '    mov edx, length', '    syscall', '',
      '    mov eax, 60         ; exit', '    xor edi, edi', '    syscall', '',
    }, '\n'),
    ['Makefile'] = table.concat({
      'NASM ?= nasm', 'LD ?= ld', '', '.PHONY: all run clean', 'all: build/app', '',
      'build/main.o: main.asm Makefile', '\tmkdir -p build', '\t$(NASM) -f elf64 -g -F dwarf $< -o $@', '',
      'build/app: build/main.o', '\t$(LD) $< -o $@', '', 'run: build/app', '\t./build/app', '',
      'clean:', '\trm -rf build', '',
    }, '\n'),
  }, actions({{'make', 'run'}}, {{'make'}})
end, 'Bu şablon NASM ve GNU ld ile x86-64 Linux içindir.')

add('java', 'Java · JDK / Maven', 'src/main/java/Main.java', {'java', 'javac'}, function(name)
  local compile = {'javac', '-d', 'build/classes', '-sourcepath', 'src/main/java', 'src/main/java/Main.java'}
  return {
    ['src/main/java/Main.java'] = 'public class Main {\n    public static void main(String[] args) {\n        System.out.println("Hello, world!");\n    }\n}\n',
    ['pom.xml'] = '<?xml version="1.0" encoding="UTF-8"?>\n'
      .. '<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"\n'
      .. '         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">\n'
      .. '  <modelVersion>4.0.0</modelVersion>\n  <groupId>local</groupId>\n  <artifactId>' .. slug(name) .. '</artifactId>\n'
      .. '  <version>0.1.0</version>\n  <properties>\n    <maven.compiler.release>17</maven.compiler.release>\n'
      .. '    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>\n  </properties>\n'
      .. '  <build>\n    <plugins>\n      <plugin>\n        <groupId>org.apache.maven.plugins</groupId>\n'
      .. '        <artifactId>maven-compiler-plugin</artifactId>\n        <version>3.13.0</version>\n'
      .. '      </plugin>\n    </plugins>\n  </build>\n</project>\n',
  }, actions({compile, {'java', '-cp', 'build/classes', 'Main'}}, {copy(compile)})
end, 'JDK 17+ gerekir. IDE eylemleri JDK ile doğrudan derler; pom.xml Maven ile de kullanılabilir.')

add('javascript', 'JavaScript · Node.js', 'src/main.js', {'node'}, function(name)
  return {
    ['src/main.js'] = 'console.log("Hello, world!");\n',
    ['package.json'] = json({name = name:lower(), version = '0.1.0', private = true, type = 'module',
      scripts = {start = 'node src/main.js', build = 'node --check src/main.js', test = 'node --test'},
      engines = {node = '>=20'}}),
    ['test/main.test.js'] = 'import test from "node:test";\nimport assert from "node:assert/strict";\nimport { execFileSync } from "node:child_process";\n\ntest("prints a greeting", () => {\n  assert.equal(execFileSync(process.execPath, ["src/main.js"], { encoding: "utf8" }), "Hello, world!\\n");\n});\n',
  }, actions({{'node', 'src/main.js'}}, {{'node', '--check', 'src/main.js'}}, {{'node', '--test'}})
end)

add('typescript', 'TypeScript · Node.js', 'src/main.ts', {'node', 'npm'}, function(name)
  return {
    ['src/main.ts'] = 'const greeting: string = "Hello, world!";\nconsole.log(greeting);\n',
    ['package.json'] = json({name = name:lower(), version = '0.1.0', private = true, type = 'module',
      scripts = {build = 'tsc', start = 'node dist/main.js', check = 'tsc --noEmit'},
      devDependencies = {typescript = '~6.0.3'}, engines = {node = '>=20'}}),
    ['tsconfig.json'] = json({compilerOptions = {target = 'ES2022', module = 'NodeNext', moduleResolution = 'NodeNext',
      rootDir = 'src', outDir = 'dist', strict = true, sourceMap = true, noEmitOnError = true}, include = {'src'}}),
  }, actions({{'npm', 'run', 'build'}, {'node', 'dist/main.js'}}, {{'npm', 'run', 'build'}}, nil, {{'npm', 'install'}})
end, 'İlk çalıştırmadan önce kurulum eylemiyle npm install çalıştır. Node.js 20+ gerekir.')

local style = ':root { font-family: system-ui, sans-serif; color-scheme: light dark; }\nbody { margin: 0; min-height: 100vh; display: grid; place-items: center; }\nmain { max-width: 48rem; padding: 2rem; }\nbutton { font: inherit; padding: 0.5rem 1rem; cursor: pointer; }\n'
local function html(name, source)
  return '<!doctype html>\n<html lang="en">\n<head>\n  <meta charset="UTF-8">\n'
    .. '  <meta name="viewport" content="width=device-width, initial-scale=1">\n  <title>' .. name .. '</title>\n'
    .. '</head>\n<body>\n  <div id="app"></div>\n  <script type="module" src="' .. source .. '"></script>\n</body>\n</html>\n'
end
add('web', 'Web · HTML / CSS / JavaScript', 'index.html', {'python3', 'node'}, function(name)
  return {
    ['index.html'] = '<!doctype html>\n<html lang="en">\n<head>\n  <meta charset="UTF-8">\n'
      .. '  <meta name="viewport" content="width=device-width, initial-scale=1">\n  <title>' .. name .. '</title>\n'
      .. '  <link rel="stylesheet" href="style.css">\n</head>\n<body>\n  <main>\n    <h1>Hello, world!</h1>\n'
      .. '    <p id="message">Your website is ready.</p>\n    <button id="hello" type="button">Say hello</button>\n'
      .. '  </main>\n  <script src="main.js" defer></script>\n</body>\n</html>\n',
    ['main.js'] = 'document.querySelector("#hello").addEventListener("click", () => {\n  document.querySelector("#message").textContent = "Hello, world!";\n});\n',
    ['style.css'] = style,
    ['package.json'] = json({name = name:lower(), version = '0.1.0', private = true,
      scripts = {start = 'python3 -m http.server 8000 --bind 127.0.0.1', build = 'node --check main.js'}}),
  }, actions({{'python3', '-m', 'http.server', '8000', '--bind', '127.0.0.1'}}, {{'node', '--check', 'main.js'}})
end, 'Çalıştırınca tarayıcıda http://127.0.0.1:8000 adresini aç. Sunucuyu Ctrl-C ile durdur; paket kurulumu gerekmez.')

local function frontend(name, vue)
  local files = {
    ['index.html'] = html(name, vue and '/src/main.ts' or '/src/main.tsx'),
    ['src/style.css'] = style,
    ['tsconfig.json'] = json({compilerOptions = {target = 'ES2022', module = 'ESNext', moduleResolution = 'Bundler',
      strict = true, noEmit = true, skipLibCheck = true, jsx = 'react-jsx',
      lib = {'ES2022', 'DOM', 'DOM.Iterable'}, types = {'vite/client'}}, include = {'src'}}),
    ['vite.config.ts'] = 'import { defineConfig } from "vite";\nimport ' .. (vue and 'vue' or 'react')
      .. ' from "@vitejs/plugin-' .. (vue and 'vue' or 'react') .. '";\n\nexport default defineConfig({ plugins: ['
      .. (vue and 'vue' or 'react') .. '()] });\n',
  }
  local dev = {typescript = '~6.0.3', vite = '^8.3.4'}
  if vue then
    dev['@vitejs/plugin-vue'], dev['vue-tsc'] = '^6.0.10', '^3.3.13'
    files['src/main.ts'] = 'import { createApp } from "vue";\nimport App from "./App.vue";\nimport "./style.css";\n\ncreateApp(App).mount("#app");\n'
    files['src/App.vue'] = '<script setup lang="ts">\nimport { ref } from "vue";\nconst count = ref(0);\n</script>\n\n<template>\n  <main>\n    <h1>Hello, world!</h1>\n    <button type="button" @click="count++">Count: {{ count }}</button>\n  </main>\n</template>\n'
  else
    dev['@vitejs/plugin-react'], dev['@types/react'], dev['@types/react-dom'] = '^6.1.2', '^19.3.0', '^19.3.0'
    files['src/main.tsx'] = 'import { StrictMode, useState } from "react";\nimport { createRoot } from "react-dom/client";\nimport "./style.css";\n\nfunction App() {\n  const [count, setCount] = useState(0);\n  return <main><h1>Hello, world!</h1><button type="button" onClick={() => setCount(count + 1)}>Count: {count}</button></main>;\n}\n\ncreateRoot(document.getElementById("app")!).render(<StrictMode><App /></StrictMode>);\n'
  end
  files['package.json'] = json({name = name:lower(), version = '0.1.0', private = true, type = 'module',
    scripts = {dev = 'vite --host 127.0.0.1', build = (vue and 'vue-tsc --noEmit' or 'tsc --noEmit') .. ' && vite build',
      preview = 'vite preview --host 127.0.0.1'},
    dependencies = vue and {vue = '^3.5.44'} or {react = '^19.3.1', ['react-dom'] = '^19.3.1'},
    devDependencies = dev, engines = {node = '^20.19.0 || >=22.12.0'}})
  return files, actions({{'npm', 'run', 'dev'}}, {{'npm', 'run', 'build'}}, nil, {{'npm', 'install'}})
end
local frontend_notes = 'Node.js 20.19+ veya 22.12+ gerekir. Önce kurulum eylemiyle npm install çalıştır; çalıştırınca terminaldeki yerel adresi tarayıcıda aç. Ctrl-C sunucuyu durdurur.'
add('react', 'React · TypeScript / Vite', 'src/main.tsx', {'node', 'npm'}, function(name) return frontend(name, false) end, frontend_notes)
add('vue', 'Vue · TypeScript / Vite', 'src/main.ts', {'node', 'npm'}, function(name) return frontend(name, true) end, frontend_notes)

add('ruby', 'Ruby · Bundler', 'main.rb', {'ruby'}, function()
  return {['main.rb'] = 'puts "Hello, world!"\n', ['Gemfile'] = 'source "https://rubygems.org"\n\n# Add gems here when needed.\n'},
    actions({{'ruby', 'main.rb'}}, {{'ruby', '-c', 'main.rb'}}, nil, {{'bundle', 'install'}})
end, 'Başlangıç programı yalnızca Ruby ister; Gemfile içine paket eklediğinde Bundler ile kurulum yap.')

add('php', 'PHP · Composer', 'main.php', {'php'}, function(name)
  return {
    ['main.php'] = '<?php\ndeclare(strict_types=1);\n\necho "Hello, world!\\n";\n',
    ['composer.json'] = json({name = 'local/' .. slug(name), description = 'Console application', type = 'project',
      require = {php = '>=8.1'}, scripts = {start = 'php main.php', check = 'php -l main.php'}}),
  }, actions({{'php', 'main.php'}}, {{'php', '-l', 'main.php'}}, nil, {{'composer', 'install'}})
end, 'Başlangıç programı yalnızca PHP 8.1+ ister; paket eklediğinde Composer ile kurulum yap.')

add('swift', 'Swift · Swift Package Manager', 'Sources/App/main.swift', {'swift'}, function(name)
  return {
    ['Sources/App/main.swift'] = 'print("Hello, world!")\n',
    ['Package.swift'] = '// swift-tools-version: 5.9\nimport PackageDescription\n\nlet package = Package(\n'
      .. '    name: "' .. name .. '",\n    products: [.executable(name: "app", targets: ["App"])],\n'
      .. '    targets: [.executableTarget(name: "App")]\n)\n',
  }, actions({{'swift', 'run', '--skip-update', 'app'}}, {{'swift', 'build', '--skip-update'}}, nil, {{'swift', 'package', 'resolve'}})
end, 'Swift 5.9+ konsol projesi; macOS uygulama paketi içermez.')

add('kotlin', 'Kotlin · JVM / Gradle', 'src/main/kotlin/Main.kt', {'gradle', 'java'}, function(name)
  return {
    ['src/main/kotlin/Main.kt'] = 'fun main() {\n    println("Hello, world!")\n}\n',
    ['settings.gradle.kts'] = 'rootProject.name = "' .. name .. '"\n',
    ['build.gradle.kts'] = 'plugins {\n    kotlin("jvm") version "2.4.20"\n    application\n}\n\n'
      .. 'repositories { mavenCentral() }\n\nkotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }\n'
      .. 'java { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }\n'
      .. 'application { mainClass.set("MainKt") }\n',
  }, actions({{'gradle', '--offline', 'run'}}, {{'gradle', '--offline', 'build'}}, nil, {{'gradle', 'build'}})
end, 'JDK 17+ ve kurulu Gradle gerekir (Kotlin 2.4.20: Gradle 7.6.3–9.7). Önce kurulum eylemi derleyici ve standart kütüphaneyi indirir. Gradle sürümün kullandığın JDK ile uyumlu olmalı; wrapper dahil değildir.')

add('dart', 'Dart · konsol / pub', 'bin/main.dart', {'dart'}, function(name)
  return {
    ['bin/main.dart'] = 'void main() {\n  print("Hello, world!");\n}\n',
    ['pubspec.yaml'] = 'name: app_' .. snake(name) .. '\ndescription: A console application.\nversion: 0.1.0\npublish_to: none\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n',
    ['analysis_options.yaml'] = 'analyzer:\n  language:\n    strict-casts: true\n    strict-inference: true\n',
  }, actions({{'dart', 'bin/main.dart'}}, {{'dart', 'analyze'}}, nil, {{'dart', 'pub', 'get'}})
end, 'Dart 3 SDK gerekir. Bu bir konsol projesidir; Flutter veya mobil uygulama dosyaları içermez.')

local function script_make(run, check)
  return '.PHONY: run check\nrun:\n\t' .. run .. '\n\ncheck:\n\t' .. check .. '\n'
end
add('lua', 'Lua · Lua 5.4', 'main.lua', {'lua', 'luac'}, function()
  return {['main.lua'] = 'print("Hello, world!")\n',
    ['.luarc.json'] = json({['runtime.version'] = 'Lua 5.4', ['workspace.checkThirdParty'] = false}),
    ['Makefile'] = script_make('lua main.lua', 'luac -p main.lua'),
  }, actions({{'lua', 'main.lua'}}, {{'luac', '-p', 'main.lua'}})
end)

add('bash', 'Bash · kabuk betiği', 'main.sh', {'bash'}, function()
  return {['main.sh'] = '#!/usr/bin/env bash\nset -euo pipefail\n\nprintf "%s\\n" "Hello, world!"\n',
    ['Makefile'] = script_make('bash main.sh', 'bash -n main.sh'),
  }, actions({{'bash', 'main.sh'}}, {{'bash', '-n', 'main.sh'}})
end)

add('r', 'R · RStudio projesi', 'main.R', {'Rscript'}, function(name)
  return {['main.R'] = 'cat("Hello, world!\\n")\n',
    [name .. '.Rproj'] = 'Version: 1.0\n\nRestoreWorkspace: No\nSaveWorkspace: No\nAlwaysSaveHistory: No\n\nEnableCodeIndexing: Yes\nUseSpacesForTab: Yes\nNumSpacesForTab: 2\nEncoding: UTF-8\n',
  }, actions({{'Rscript', 'main.R'}}, {{'Rscript', '-e', 'parse(file = "main.R")'}})
end)

add('julia', 'Julia · proje ortamı', 'src/main.jl', {'julia'}, function()
  return {['src/main.jl'] = 'println("Hello, world!")\n', ['Project.toml'] = '[deps]\n\n[compat]\njulia = "1.6"\n'},
    actions({{'julia', '--project=.', 'src/main.jl'}},
      {{'julia', '--project=.', '-e', 'Meta.parseall(read("src/main.jl", String))'}}, nil,
      {{'julia', '--project=.', '-e', 'using Pkg; Pkg.instantiate()'}})
end)

add('perl', 'Perl · betik', 'main.pl', {'perl'}, function()
  return {['main.pl'] = 'use strict;\nuse warnings;\n\nprint "Hello, world!\\n";\n',
    ['Makefile'] = script_make('perl main.pl', 'perl -c main.pl'),
    ['cpanfile'] = '# Add CPAN requirements here when needed.\n',
  }, actions({{'perl', 'main.pl'}}, {{'perl', '-c', 'main.pl'}})
end)

add('haskell', 'Haskell · Cabal', 'app/Main.hs', {'cabal', 'ghc'}, function(name)
  local package_name = 'app-' .. name:lower():gsub('[^a-z0-9]', '')
  return {
    ['app/Main.hs'] = 'module Main where\n\nmain :: IO ()\nmain = putStrLn "Hello, world!"\n',
    ['cabal.project'] = 'packages: .\n',
    [package_name .. '.cabal'] = 'cabal-version: 3.0\nname: ' .. package_name .. '\nversion: 0.1.0.0\nbuild-type: Simple\n\n'
      .. 'executable app\n  main-is: Main.hs\n  hs-source-dirs: app\n  build-depends: base >=4.12 && <5\n  default-language: Haskell2010\n  ghc-options: -Wall\n',
  }, actions({{'cabal', 'run', '--offline', 'app'}}, {{'cabal', 'build', '--offline'}}, nil, {{'cabal', 'build'}})
end)

add('elixir', 'Elixir · Mix', 'lib/app.ex', {'mix'}, function(name)
  return {
    ['mix.exs'] = 'defmodule App.MixProject do\n  use Mix.Project\n\n  def project do\n    [app: :app_' .. snake(name)
      .. ', version: "0.1.0", elixir: "~> 1.14", escript: [main_module: App], deps: []]\n  end\n\n'
      .. '  def application, do: [extra_applications: [:logger]]\nend\n',
    ['lib/app.ex'] = 'defmodule App do\n  def main(_args), do: IO.puts("Hello, world!")\nend\n',
    ['test/test_helper.exs'] = 'ExUnit.start()\n',
    ['test/app_test.exs'] = 'defmodule AppTest do\n  use ExUnit.Case\n  import ExUnit.CaptureIO\n\n  test "prints a greeting" do\n    assert capture_io(fn -> App.main([]) end) == "Hello, world!\\n"\n  end\nend\n',
  }, actions({{'mix', 'run', '-e', 'App.main([])'}}, {{'mix', 'compile'}}, {{'mix', 'test'}}, {{'mix', 'deps.get'}})
end)

add('scala', 'Scala · sbt', 'src/main/scala/Main.scala', {'sbt', 'java'}, function(name)
  return {
    ['src/main/scala/Main.scala'] = 'object Main {\n  def main(args: Array[String]): Unit = {\n    println("Hello, world!")\n  }\n}\n',
    ['build.sbt'] = 'ThisBuild / scalaVersion := "3.3.6"\nThisBuild / version := "0.1.0"\n\nname := "' .. name .. '"\n',
    ['project/build.properties'] = 'sbt.version=1.10.7\n',
  }, actions({{'sbt', '-Dsbt.offline=true', 'run'}}, {{'sbt', '-Dsbt.offline=true', 'compile'}}, nil, {{'sbt', 'compile'}})
end, 'JDK ve sbt gerekir. Önce kurulum eylemi sbt/Scala derleyicisini indirip önbelleğe alır.')

add('clojure', 'Clojure · deps.edn', 'src/app/core.clj', {'clojure'}, function()
  return {
    ['deps.edn'] = '{:paths ["src"]\n :aliases {:run {:main-opts ["-m" "app.core"]}}}\n',
    ['src/app/core.clj'] = '(ns app.core)\n\n(defn -main [& _args]\n  (println "Hello, world!"))\n',
  }, actions({{'clojure', '-M:run'}}, {{'clojure', '-M', '-e', '(require (quote app.core))'}}, nil, {{'clojure', '-P', '-M:run'}})
end, 'Clojure CLI (tools.deps) gerekir. İlk kullanımda kurulum eylemi CLI sürümünün Clojure bağımlılıklarını hazırlar.')

add('fsharp', 'F# · .NET konsol', 'Program.fs', {'dotnet'}, function(name) return dotnet(name, true) end,
  '.NET 10 SDK gerekir. İlk çalıştırmadan önce kurulum eylemiyle dotnet restore çalıştır.')

add('fortran', 'Fortran · CMake', 'main.f90', {'cmake', 'gfortran'}, function(name)
  local build = {{'cmake', '-S', '.', '-B', 'build'}, {'cmake', '--build', 'build'}}
  return {
    ['main.f90'] = 'program main\n  implicit none\n  print "(A)", "Hello, world!"\nend program main\n',
    ['CMakeLists.txt'] = 'cmake_minimum_required(VERSION 3.16)\nproject(' .. snake(name)
      .. ' LANGUAGES Fortran)\nadd_executable(app main.f90)\n',
  }, actions({copy(build[1]), copy(build[2]), {'./build/app'}}, build)
end)

add('ocaml', 'OCaml · Dune', 'bin/main.ml', {'dune', 'ocamlc'}, function(name)
  return {['dune-project'] = '(lang dune 3.0)\n(name app_' .. snake(name) .. ')\n',
    ['bin/dune'] = '(executable\n (name main))\n', ['bin/main.ml'] = 'let () = print_endline "Hello, world!"\n',
  }, actions({{'dune', 'exec', './bin/main.exe'}}, {{'dune', 'build'}})
end, 'OCaml ve Dune 3+ kurulu olmalı; bu şablon harici OCaml paketi kullanmaz.')

add('zig', 'Zig · 0.15 build', 'src/main.zig', {'zig'}, function()
  return {
    ['src/main.zig'] = 'const std = @import("std");\n\npub fn main() !void {\n    try std.fs.File.stdout().writeAll("Hello, world!\\n");\n}\n',
    ['build.zig'] = 'const std = @import("std");\n\npub fn build(b: *std.Build) void {\n'
      .. '    const exe = b.addExecutable(.{\n        .name = "app",\n        .root_module = b.createModule(.{\n'
      .. '            .root_source_file = b.path("src/main.zig"),\n            .target = b.standardTargetOptions(.{}),\n'
      .. '            .optimize = b.standardOptimizeOption(.{}),\n        }),\n    });\n    b.installArtifact(exe);\n'
      .. '    const run = b.addRunArtifact(exe);\n    if (b.args) |args| run.addArgs(args);\n'
      .. '    b.step("run", "Run the application").dependOn(&run.step);\n}\n',
  }, actions({{'zig', 'build', 'run'}}, {{'zig', 'build'}}, {{'zig', 'test', 'src/main.zig'}})
end, 'Zig 0.15.x için hazırlanmıştır; Zig sürümleri arasında standart kütüphane API değişebilir.')

add('sql', 'SQL · SQLite', 'main.sql', {'sqlite3'}, function()
  return {
    ['main.sql'] = '-- Run in a temporary in-memory database by default.\nBEGIN;\nCREATE TABLE IF NOT EXISTS greetings (\n  id INTEGER PRIMARY KEY,\n  message TEXT NOT NULL\n);\nINSERT OR REPLACE INTO greetings (id, message) VALUES (1, \'Hello, world!\');\nSELECT message FROM greetings ORDER BY id;\nCOMMIT;\n',
    ['Makefile'] = script_make('sqlite3 :memory: ".read main.sql"', 'sqlite3 :memory: ".read main.sql"'),
  }, actions({{'sqlite3', '-bail', ':memory:', '.read main.sql'}}, {{'sqlite3', '-bail', ':memory:', '.read main.sql'}})
end, 'Çalıştır ve derle eylemleri geçici bir bellek veritabanı kullanır. Veriyi saklamak için: sqlite3 app.db ".read main.sql"')

function M.list() return copy(entries) end

function M.render(id, name)
  local entry = by_id[id]
  if not entry then return nil, 'Bilinmeyen proje dili: ' .. tostring(id) end
  if type(name) ~= 'string' or not name:match('^[A-Za-z][A-Za-z0-9_-]*$') then
    return nil, 'Geçersiz proje adı.'
  end
  local spec = copy(entry.item)
  spec.files, spec.tasks = entry.render(name)
  return spec
end

return M
