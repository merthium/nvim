local keymap = vim.keymap.set
local function normalize_path(path)
    if not path or path == "" then
        return nil
    end

    local real = vim.uv.fs_realpath(vim.fn.expand(path))
    return real or vim.fn.fnamemodify(vim.fn.expand(path), ":p"):gsub("/$", "")
end

local function directory_exists(path)
    return path and vim.fn.isdirectory(path) == 1
end

local function file_exists(path)
    return path and vim.fn.filereadable(path) == 1
end

local function kernel_build_root()
    local configured = normalize_path(vim.env.KERNEL_BUILD)
    if directory_exists(configured) then
        return configured
    end

    local release = vim.uv.os_uname().release
    local build = normalize_path("/lib/modules/" .. release .. "/build")
    if directory_exists(build) then
        return build
    end

    return nil
end

local function kernel_source_root()
    local configured = normalize_path(vim.env.KERNEL_SRC)
    if directory_exists(configured) then
        return configured
    end

    local build = kernel_build_root()
    if not build then
        return nil
    end

    local source = normalize_path(build .. "/source")
    if directory_exists(source) then
        return source
    end

    return build
end

local function makefile_looks_like_kbuild(path)
    if not file_exists(path) then
        return false
    end

    if vim.fn.fnamemodify(path, ":t") == "Kbuild" then
        return true
    end

    local ok, content = pcall(vim.fn.readfile, path, "", 200)
    if not ok then
        return false
    end

    local text = table.concat(content, "\n")
    return text:match("obj%-m%s*[:+]?=") ~= nil
        or text:match("obj%-y%s*[:+]?=") ~= nil
        or text:match("KERNELRELEASE") ~= nil
        or text:match("KBUILD_EXTMOD") ~= nil
end

local function kernel_module_root(bufnr)
    bufnr = bufnr or 0
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local dir = filename ~= "" and vim.fn.fnamemodify(filename, ":p:h") or vim.fn.getcwd()
    dir = normalize_path(dir)

    while dir and dir ~= "/" do
        local kbuild = dir .. "/Kbuild"
        local makefile = dir .. "/Makefile"

        if makefile_looks_like_kbuild(kbuild) or makefile_looks_like_kbuild(makefile) then
            return dir
        end

        local parent = normalize_path(vim.fn.fnamemodify(dir, ":h"))
        if not parent or parent == dir then
            break
        end
        dir = parent
    end

    return nil
end

local function path_is_inside(path, root)
    path = normalize_path(path)
    root = normalize_path(root)
    if not path or not root then
        return false
    end

    return path == root or path:sub(1, #root + 1) == root .. "/"
end

local function is_kernel_buffer(bufnr)
    bufnr = bufnr or 0
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if filename == "" then
        return false
    end

    if kernel_module_root(bufnr) then
        return true
    end

    local source = kernel_source_root()
    return source and path_is_inside(filename, source) or false
end

local function kernel_arch()
    local machine = vim.uv.os_uname().machine
    local map = {
        x86_64 = "x86",
        i386 = "x86",
        i486 = "x86",
        i586 = "x86",
        i686 = "x86",
        aarch64 = "arm64",
        armv7l = "arm",
        riscv64 = "riscv",
    }
    return map[machine] or machine
end

local function add_kernel_include_paths()
    local source = kernel_source_root()
    local build = kernel_build_root()
    local arch = kernel_arch()
    local candidates = {
        source and source .. "/include" or nil,
        source and source .. "/include/uapi" or nil,
        source and source .. "/arch/" .. arch .. "/include" or nil,
        source and source .. "/arch/" .. arch .. "/include/uapi" or nil,
        build and build .. "/include" or nil,
        build and build .. "/include/generated" or nil,
        build and build .. "/include/generated/uapi" or nil,
        build and build .. "/arch/" .. arch .. "/include/generated" or nil,
        build and build .. "/arch/" .. arch .. "/include/generated/uapi" or nil,
    }

    for _, path in ipairs(candidates) do
        if directory_exists(path) then
            vim.opt_local.path:append(path)
        end
    end
end

local function set_kernel_diagnostics(bufnr, enabled)
    vim.diagnostic.enable(enabled, { bufnr = bufnr })
    vim.b[bufnr].kernel_diagnostics_muted = not enabled
end

local kernel_group = vim.api.nvim_create_augroup("KernelDevelopment", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    group = kernel_group,
    pattern = { "c", "cpp" },
    callback = function(args)
        if not is_kernel_buffer(args.buf) then
            return
        end

        -- Match the Linux kernel coding style only inside kernel code/modules.
        vim.opt_local.tabstop = 8
        vim.opt_local.shiftwidth = 8
        vim.opt_local.softtabstop = 8
        vim.opt_local.expandtab = false
        vim.opt_local.cindent = true
        vim.opt_local.textwidth = 80
        vim.opt_local.colorcolumn = "81"
        add_kernel_include_paths()

        -- clangd without Kbuild's compile flags produces cascading nonsense
        -- diagnostics (for example after failing to resolve <linux/init.h>).
        -- Keep navigation/completion available, but mute diagnostics until the
        -- module has a compile_commands.json generated from Kbuild.
        local module = kernel_module_root(args.buf)
        if module and not file_exists(module .. "/compile_commands.json") then
            set_kernel_diagnostics(args.buf, false)
            vim.schedule(function()
                vim.notify(
                    "Kernel diagnostics muted: run <leader>kd once to generate the Kbuild compile database",
                    vim.log.levels.INFO
                )
            end)
        else
            set_kernel_diagnostics(args.buf, true)
        end
    end,
})

local function quickfix_from_lines(title, lines, errorformat)
    vim.fn.setqflist({}, " ", {
        title = title,
        lines = lines,
        efm = errorformat or vim.o.errorformat,
    })
end

local function combined_output(obj)
    local text = (obj.stdout or "")
    if obj.stderr and obj.stderr ~= "" then
        if text ~= "" and text:sub(-1) ~= "\n" then
            text = text .. "\n"
        end
        text = text .. obj.stderr
    end
    return vim.split(text, "\n", { trimempty = true })
end

local function run_async(cmd, title, callback)
    vim.notify("$ " .. table.concat(cmd, " "), vim.log.levels.INFO, { title = title })

    vim.system(cmd, { text = true }, function(obj)
        vim.schedule(function()
            local lines = combined_output(obj)
            quickfix_from_lines(title, lines)

            if obj.code == 0 then
                vim.notify(title .. " finished", vim.log.levels.INFO)
            else
                vim.notify(title .. " failed (exit " .. obj.code .. ")", vim.log.levels.ERROR)
                vim.cmd("copen")
            end

            if callback then
                callback(obj, lines)
            end
        end)
    end)
end

local function require_external_module()
    local module = kernel_module_root(0)
    if not module then
        vim.notify("No external kernel module root found (Kbuild/Makefile with obj-m)", vim.log.levels.ERROR)
        return nil, nil
    end

    local build = kernel_build_root()
    if not build then
        vim.notify("Kernel build tree not found. Set $KERNEL_BUILD if needed.", vim.log.levels.ERROR)
        return nil, nil
    end

    return module, build
end

local function kernel_build(extra_warnings)
    local module, build = require_external_module()
    if not module then
        return
    end

    local cmd = { "make", "-C", build, "M=" .. module }
    if extra_warnings then
        table.insert(cmd, "W=1")
    end
    table.insert(cmd, "modules")
    run_async(cmd, extra_warnings and "Kbuild W=1" or "Kbuild")
end

local function kernel_clean()
    local module, build = require_external_module()
    if not module then
        return
    end

    run_async({ "make", "-C", build, "M=" .. module, "clean" }, "Kbuild clean")
end

local function restart_clangd()
    -- Restart clangd after creating a compilation database so it re-detects
    -- the kernel module root and reloads the real Kbuild compile flags.
    if not vim.lsp.is_enabled("clangd") then
        return
    end

    vim.lsp.enable("clangd", false)
    vim.defer_fn(function()
        vim.lsp.enable("clangd")
    end, 150)
end

local function generate_compile_commands()
    local module, build = require_external_module()
    if not module then
        return
    end

    local script = build .. "/scripts/clang-tools/gen_compile_commands.py"
    if not file_exists(script) then
        vim.notify("gen_compile_commands.py was not found in the kernel build tree", vim.log.levels.ERROR)
        return
    end

    -- Kbuild first creates the .cmd files consumed by gen_compile_commands.py.
    run_async({ "make", "-C", build, "M=" .. module, "modules" }, "Kbuild for compile database", function(obj)
        if obj.code ~= 0 then
            return
        end

        local output = module .. "/compile_commands.json"
        run_async({
            "python3",
            script,
            "-d", build,
            "-o", output,
            module,
        }, "Kernel compile database", function(gen_obj)
            if gen_obj.code ~= 0 or not file_exists(output) then
                return
            end

            local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(output), "\n"))
            if ok and type(decoded) == "table" then
                if #decoded == 0 then
                    vim.notify("compile_commands.json was created but contains no entries", vim.log.levels.WARN)
                else
                    vim.notify("compile_commands.json: " .. #decoded .. " entries", vim.log.levels.INFO)

                    -- Re-enable diagnostics for buffers in this module only after
                    -- clangd has a real Kbuild compilation database available.
                    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                        if vim.api.nvim_buf_is_loaded(bufnr) then
                            local name = vim.api.nvim_buf_get_name(bufnr)
                            if name ~= "" and path_is_inside(name, module) then
                                set_kernel_diagnostics(bufnr, true)
                            end
                        end
                    end

                    restart_clangd()
                end
            end
        end)
    end)
end

local function kernel_search(pattern, headers_only)
    if not pattern or pattern == "" then
        return
    end

    local root = kernel_source_root()
    if not root then
        vim.notify("Kernel source/build tree not found. Set $KERNEL_SRC if needed.", vim.log.levels.ERROR)
        return
    end

    local cmd = {
        "rg",
        "--vimgrep",
        "--smart-case",
        "--glob", "!.git/**",
    }

    if headers_only then
        vim.list_extend(cmd, { "--glob", "*.h" })
    else
        vim.list_extend(cmd, {
            "--glob", "*.c",
            "--glob", "*.h",
            "--glob", "*.S",
        })
    end

    table.insert(cmd, pattern)
    table.insert(cmd, root)

    vim.system(cmd, { text = true }, function(obj)
        vim.schedule(function()
            local lines = combined_output(obj)
            if #lines == 0 then
                vim.notify("No kernel matches for: " .. pattern, vim.log.levels.INFO)
                return
            end

            quickfix_from_lines("Kernel search: " .. pattern, lines, "%f:%l:%c:%m")
            vim.cmd("copen")
        end)
    end)
end

vim.api.nvim_create_user_command("Kbuild", function()
    kernel_build(false)
end, { desc = "Build the current external kernel module" })

vim.api.nvim_create_user_command("KbuildW", function()
    kernel_build(true)
end, { desc = "Build the current module with Kbuild W=1" })

vim.api.nvim_create_user_command("Kclean", kernel_clean, {
    desc = "Clean the current external kernel module",
})

vim.api.nvim_create_user_command("KcompileDB", generate_compile_commands, {
    desc = "Generate compile_commands.json for the current kernel module",
})

vim.api.nvim_create_user_command("Kgrep", function(opts)
    local pattern = opts.args ~= "" and opts.args or vim.fn.expand("<cword>")
    kernel_search(pattern, false)
end, { nargs = "?", desc = "Search kernel C/headers/assembly" })

vim.api.nvim_create_user_command("Khgrep", function(opts)
    local pattern = opts.args ~= "" and opts.args or vim.fn.expand("<cword>")
    kernel_search(pattern, true)
end, { nargs = "?", desc = "Search kernel headers" })

vim.api.nvim_create_user_command("Kinfo", function()
    local lines = {
        "Kernel build : " .. (kernel_build_root() or "not found"),
        "Kernel source: " .. (kernel_source_root() or "not found"),
        "Module root  : " .. (kernel_module_root(0) or "not detected"),
        "Compile DB   : " .. ((kernel_module_root(0) and file_exists(kernel_module_root(0) .. "/compile_commands.json")) and "present" or "missing"),
    }
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Kernel environment" })
end, { desc = "Show detected kernel development paths" })

-- Kernel commands use one mnemonic prefix and stay out of normal editing keys.
keymap("n", "<leader>kb", function() kernel_build(false) end, { desc = "Kernel build" })
keymap("n", "<leader>kw", function() kernel_build(true) end, { desc = "Kernel build W=1" })
keymap("n", "<leader>kc", kernel_clean, { desc = "Kernel clean" })
keymap("n", "<leader>kd", generate_compile_commands, { desc = "Kernel compile database" })
keymap("n", "<leader>kg", function() kernel_search(vim.fn.expand("<cword>"), false) end, { desc = "Kernel grep symbol" })
keymap("n", "<leader>kh", function() kernel_search(vim.fn.expand("<cword>"), true) end, { desc = "Kernel grep headers" })
keymap("n", "<leader>ki", "<cmd>Kinfo<CR>", { desc = "Kernel environment info" })
