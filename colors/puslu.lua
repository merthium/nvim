local opt, g = vim.opt, vim.g
local function set_hl(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
end

vim.cmd("highlight clear")
opt.background = "dark"
g.colors_name = "puslu"

-- Color palette
local bg       = "#0d1013"  -- Charcoal with a cool undertone
local bg_light = "#13171b"  -- Quiet cursor line and floating windows
local bg_ui    = "#181c20"
local fg       = "#c5cbd1"
local fg_dim   = "#929ba5"
local fg_dark  = "#737f8b"  -- Comments remain readable
local white    = "#dde2e7"
local black    = bg
local gray1    = "#21272d"
local gray2    = "#29323b"
local gray3    = "#414d59"
local gray4    = "#586572"
local border   = "#414d59"

-- All chromatic accents deliberately stay close to gray.
local red      = "#cd9595"
local green    = "#a9b89b"
local yellow   = "#c4b18b"
local blue     = "#91b4c5"
local magenta  = "#b3a0be"
local cyan     = "#93b6b0"
local accent   = green
local diff_add = "#18231a"
local diff_chg = "#252318"
local diff_del = "#251a1a"

-- Base UI
set_hl("Normal", { bg = bg, fg = fg })
set_hl("NormalNC", { bg = bg, fg = fg })
set_hl("NormalFloat", { bg = bg_light, fg = fg })
set_hl("FloatBorder", { fg = border, bg = bg_light })
set_hl("FloatTitle", { fg = accent, bg = bg_light, bold = true })
-- Keep plugin-specific borders consistent with the floating windows.
for _, group in ipairs({
    "SnacksInputBorder", "SnacksPickerBorder", "WhichKeyBorder",
    "BlinkCmpMenuBorder", "BlinkCmpDocBorder", "BlinkCmpDocSeparator",
    "BlinkCmpSignatureHelpBorder",
}) do
    set_hl(group, { link = "FloatBorder" })
end

-- File menus need readable paths and tree guides on the dark background.
set_hl("SnacksPicker", { fg = fg, bg = bg })
set_hl("SnacksPickerBorder", { fg = border, bg = bg })
set_hl("SnacksPickerFile", { fg = fg })
set_hl("SnacksPickerDirectory", { fg = blue, bold = true })
set_hl("SnacksPickerDir", { fg = fg_dim })
set_hl("SnacksPickerPathHidden", { fg = fg_dim })
set_hl("SnacksPickerPathIgnored", { fg = fg_dark })
set_hl("SnacksPickerTree", { fg = gray3 })
set_hl("SnacksPickerDimmed", { fg = fg_dim })
set_hl("SnacksPickerComment", { fg = fg_dim })
set_hl("SnacksPickerListCursorLine", { fg = white, bg = gray2, bold = true })
set_hl("SnacksPickerMatch", { fg = yellow, bold = true })

-- Syntax: muted hue plus weight/style keeps categories distinct without glare.
set_hl("Comment", { fg = fg_dark, italic = true })
set_hl("Constant", { fg = yellow })
set_hl("String", { fg = green })
set_hl("Character", { fg = green })
set_hl("Number", { fg = yellow })
set_hl("Boolean", { fg = yellow, bold = true })
set_hl("Float", { fg = yellow })

set_hl("Identifier", { fg = fg })
set_hl("Function", { fg = blue, bold = true })

set_hl("Statement", { fg = magenta, bold = true })
set_hl("Conditional", { fg = magenta, bold = true })
set_hl("Repeat", { fg = magenta, bold = true })
set_hl("Label", { fg = magenta, bold = true })
set_hl("Operator", { fg = fg })
set_hl("Keyword", { fg = magenta, bold = true })
set_hl("Exception", { fg = red, bold = true })

set_hl("PreProc", { fg = magenta })
set_hl("Include", { fg = magenta, bold = true })
set_hl("Define", { fg = magenta, bold = true })
set_hl("Macro", { fg = magenta, bold = true })
set_hl("PreCondit", { fg = magenta, bold = true })

set_hl("Type", { fg = cyan, italic = true })
set_hl("StorageClass", { fg = cyan, italic = true })
set_hl("Structure", { fg = cyan, italic = true })
set_hl("Typedef", { fg = cyan, italic = true })

set_hl("Special", { fg = yellow })
set_hl("SpecialChar", { fg = yellow })
set_hl("Tag", { fg = blue, bold = true })
set_hl("Delimiter", { fg = fg_dim })
set_hl("SpecialComment", { fg = fg_dark, italic = true })
set_hl("Debug", { fg = red, bold = true })

set_hl("Underlined", { fg = fg, underline = true })
set_hl("Ignore", { fg = fg_dark })
set_hl("Error", { fg = red, bg = gray1, bold = true })
set_hl("Todo", { fg = yellow, bg = gray1, bold = true })

-- UI elements
-- Muted neutral-sage cursor stays compatible with changing desktop accents.
set_hl("Cursor", { fg = bg, bg = accent, blend = 0 })
set_hl("CursorIM", { fg = bg, bg = accent, blend = 0 })
opt.guicursor = "n-v-c:block-Cursor,i-ci-ve:ver25-Cursor,r-cr:hor20-Cursor,a:blinkon0"
set_hl("CursorLine", { bg = bg_light })
set_hl("CursorLineNr", { fg = accent, bg = bg_light, bold = true })
-- Picker selection must stand out from NormalFloat, including without a cursor.
set_hl("MiniPickMatchCurrent", { fg = white, bg = gray2, bold = true })
set_hl("MiniPickMatchRanges", { fg = yellow, bold = true })
set_hl("LineNr", { fg = gray4 })
set_hl("LineNrAbove", { fg = gray4 })
set_hl("LineNrBelow", { fg = gray4 })
set_hl("CursorColumn", { bg = bg_light })

set_hl("StatusLine", { fg = fg_dim, bg = bg })
set_hl("StatusLineNC", { fg = fg_dim, bg = bg })
set_hl("VertSplit", { fg = border })
set_hl("WinSeparator", { fg = border })
set_hl("Title", { fg = accent, bold = true })
set_hl("Directory", { fg = blue, bold = true })

set_hl("Pmenu", { fg = fg, bg = bg_ui })
set_hl("PmenuSel", { fg = white, bg = gray3, bold = true })
set_hl("PmenuSbar", { bg = bg_ui })
set_hl("PmenuThumb", { bg = gray4 })

set_hl("Search", { fg = black, bg = yellow, bold = true })
set_hl("IncSearch", { fg = black, bg = accent, bold = true })
set_hl("CurSearch", { fg = black, bg = accent, bold = true })
set_hl("Substitute", { fg = black, bg = yellow, bold = true })

set_hl("Visual", { bg = gray2 })
set_hl("VisualNOS", { bg = gray2 })

set_hl("MatchParen", { fg = white, bg = gray1, bold = true })

set_hl("NonText", { fg = gray2 })
set_hl("SpecialKey", { fg = gray2 })
set_hl("Whitespace", { fg = gray2 })
set_hl("EndOfBuffer", { fg = gray2 })

set_hl("ErrorMsg", { fg = red, bg = gray1, bold = true })
set_hl("WarningMsg", { fg = yellow, bg = gray1 })
set_hl("ModeMsg", { fg = white, bold = true })
set_hl("MoreMsg", { fg = white, bold = true })
set_hl("Question", { fg = white, bold = true })
set_hl("WildMenu", { fg = white, bg = gray3, bold = true })

set_hl("Folded", { fg = fg_dim, bg = bg_light })
set_hl("FoldColumn", { fg = gray3 })
set_hl("SignColumn", { bg = bg })
set_hl("ColorColumn", { bg = bg_light })

set_hl("Conceal", { fg = fg_dim })

-- Diff and diagnostics use the same restrained semantic accents.
set_hl("DiffAdd", { fg = green, bg = diff_add })
set_hl("DiffChange", { fg = yellow, bg = diff_chg })
set_hl("DiffDelete", { fg = red, bg = diff_del })
set_hl("DiffText", { fg = white, bg = gray1, bold = true })

set_hl("SpellBad", { fg = red, underline = true })
set_hl("SpellCap", { fg = blue, underline = true })
set_hl("SpellRare", { fg = magenta, underline = true })
set_hl("SpellLocal", { fg = cyan, underline = true })

set_hl("DiagnosticError", { fg = red, bold = true })
set_hl("DiagnosticWarn", { fg = yellow, bold = true })
set_hl("DiagnosticInfo", { fg = blue, bold = true })
set_hl("DiagnosticHint", { fg = cyan })
set_hl("DiagnosticOk", { fg = green, bold = true })

set_hl("DiagnosticUnderlineError", { undercurl = true, sp = red })
set_hl("DiagnosticUnderlineWarn", { undercurl = true, sp = yellow })
set_hl("DiagnosticUnderlineInfo", { underline = true })
set_hl("DiagnosticUnderlineHint", { underline = true })
set_hl("DiagnosticUnderlineOk", { underline = true })

set_hl("DiagnosticVirtualTextError", { fg = red, bg = bg_light })
set_hl("DiagnosticVirtualTextWarn", { fg = yellow, bg = bg_light })
set_hl("DiagnosticVirtualTextInfo", { fg = blue, bg = bg_light })
set_hl("DiagnosticVirtualTextHint", { fg = cyan, bg = bg_light })
set_hl("DiagnosticVirtualTextOk", { fg = green, bg = bg_light })

set_hl("DiagnosticFloatingError", { fg = red })
set_hl("DiagnosticFloatingWarn", { fg = yellow })
set_hl("DiagnosticFloatingInfo", { fg = blue })
set_hl("DiagnosticFloatingHint", { fg = cyan })
set_hl("DiagnosticFloatingOk", { fg = green })

set_hl("DiagnosticSignError", { fg = red })
set_hl("DiagnosticSignWarn", { fg = yellow })
set_hl("DiagnosticSignInfo", { fg = blue })
set_hl("DiagnosticSignHint", { fg = cyan })
set_hl("DiagnosticSignOk", { fg = green })

-- LSP
set_hl("LspReferenceText", { bg = gray2 })
set_hl("LspReferenceRead", { bg = gray2 })
set_hl("LspReferenceWrite", { bg = gray2 })

-- Tabline
set_hl("TabLine", { fg = fg_dim, bg = bg })
set_hl("TabLineFill", { bg = bg })
set_hl("TabLineSel", { fg = accent, bg = bg_ui, bold = true })
set_hl("IDETabHover", { fg = white, bg = gray2, bold = true })

-- Treesitter
set_hl("@comment", { fg = fg_dark, italic = true })
set_hl("@comment.documentation", { fg = fg_dark, italic = true })
set_hl("@constant", { fg = yellow })
set_hl("@constant.builtin", { fg = yellow, bold = true })
set_hl("@constant.macro", { fg = magenta, bold = true })
set_hl("@string", { fg = green })
set_hl("@string.documentation", { fg = green, italic = true })
set_hl("@string.escape", { fg = yellow })
set_hl("@string.special", { fg = yellow })
set_hl("@character", { fg = green })
set_hl("@character.special", { fg = yellow })
set_hl("@number", { fg = yellow })
set_hl("@float", { fg = yellow })
set_hl("@boolean", { fg = yellow, bold = true })

set_hl("@function", { fg = blue, bold = true })
set_hl("@function.builtin", { fg = blue, bold = true })
set_hl("@function.call", { fg = blue, bold = true })
set_hl("@function.macro", { fg = blue, bold = true })
set_hl("@method", { fg = blue, bold = true })
set_hl("@method.call", { fg = blue, bold = true })
set_hl("@constructor", { fg = cyan, bold = true })
set_hl("@parameter", { fg = fg })

set_hl("@keyword", { fg = magenta, bold = true })
set_hl("@keyword.coroutine", { fg = magenta, bold = true })
set_hl("@keyword.function", { fg = magenta, bold = true })
set_hl("@keyword.operator", { fg = magenta, bold = true })
set_hl("@keyword.import", { fg = magenta, bold = true })
set_hl("@keyword.type", { fg = magenta, bold = true })
set_hl("@keyword.modifier", { fg = magenta, bold = true })
set_hl("@keyword.return", { fg = magenta, bold = true })
set_hl("@keyword.debug", { fg = red, bold = true })
set_hl("@keyword.exception", { fg = red, bold = true })
set_hl("@conditional", { fg = magenta, bold = true })
set_hl("@conditional.ternary", { fg = magenta, bold = true })
set_hl("@repeat", { fg = magenta, bold = true })
set_hl("@debug", { fg = red, bold = true })
set_hl("@label", { fg = magenta, bold = true })
set_hl("@include", { fg = magenta, bold = true })
set_hl("@exception", { fg = red, bold = true })

set_hl("@type", { fg = cyan, italic = true })
set_hl("@type.builtin", { fg = cyan, italic = true })
set_hl("@type.definition", { fg = cyan, italic = true })
set_hl("@type.qualifier", { fg = cyan, bold = true })
set_hl("@storageclass", { fg = cyan, italic = true })
set_hl("@attribute", { fg = yellow, italic = true })
set_hl("@field", { fg = cyan })
set_hl("@property", { fg = cyan })

set_hl("@variable", { fg = fg })
set_hl("@variable.builtin", { fg = accent, italic = true })
set_hl("@variable.parameter", { fg = fg })
set_hl("@variable.member", { fg = cyan })

set_hl("@namespace", { fg = cyan })
set_hl("@symbol", { fg = yellow })

set_hl("@text", { fg = fg })
set_hl("@text.strong", { fg = white, bold = true })
set_hl("@text.emphasis", { fg = white, italic = true })
set_hl("@text.underline", { fg = fg, underline = true })
set_hl("@text.strike", { fg = fg_dim, strikethrough = true })
set_hl("@text.title", { fg = accent, bold = true })
set_hl("@text.literal", { fg = green })
set_hl("@text.uri", { fg = blue, underline = true })
set_hl("@text.math", { fg = fg })
set_hl("@text.environment", { fg = white, bold = true })
set_hl("@text.environment.name", { fg = white, bold = true })
set_hl("@text.reference", { fg = fg, underline = true })
set_hl("@text.todo", { fg = yellow, bg = gray1, bold = true })
set_hl("@text.note", { fg = blue, bg = gray1, bold = true })
set_hl("@text.warning", { fg = yellow, bg = gray1, bold = true })
set_hl("@text.danger", { fg = red, bg = gray1, bold = true })
set_hl("@text.diff.add", { fg = green, bg = diff_add })
set_hl("@text.diff.delete", { fg = red, bg = diff_del })

set_hl("@tag", { fg = blue, bold = true })
set_hl("@tag.attribute", { fg = yellow, italic = true })
set_hl("@tag.delimiter", { fg = fg_dim })

-- Semantic tokens (LSP)
set_hl("@lsp.type.class", { fg = cyan, italic = true })
set_hl("@lsp.type.comment", { fg = fg_dark, italic = true })
set_hl("@lsp.type.decorator", { fg = yellow, bold = true })
set_hl("@lsp.type.enum", { fg = cyan, italic = true })
set_hl("@lsp.type.enumMember", { fg = yellow })
set_hl("@lsp.type.event", { fg = blue })
set_hl("@lsp.type.function", { fg = blue, bold = true })
set_hl("@lsp.type.interface", { fg = cyan, italic = true })
set_hl("@lsp.type.keyword", { fg = magenta, bold = true })
set_hl("@lsp.type.macro", { fg = magenta, bold = true })
set_hl("@lsp.type.method", { fg = blue, bold = true })
set_hl("@lsp.type.modifier", { fg = magenta, bold = true })
set_hl("@lsp.type.namespace", { fg = cyan })
set_hl("@lsp.type.number", { fg = yellow })
set_hl("@lsp.type.operator", { fg = fg })
set_hl("@lsp.type.parameter", { fg = fg })
set_hl("@lsp.type.property", { fg = cyan })
set_hl("@lsp.type.regexp", { fg = red })
set_hl("@lsp.type.string", { fg = green })
set_hl("@lsp.type.struct", { fg = cyan, italic = true })
set_hl("@lsp.type.type", { fg = cyan, italic = true })
set_hl("@lsp.type.typeParameter", { fg = cyan, italic = true })
set_hl("@lsp.type.variable", { fg = fg })

set_hl("@lsp.mod.defaultLibrary", { fg = accent, italic = true })
set_hl("@lsp.mod.deprecated", { fg = fg_dark, strikethrough = true })
set_hl("@lsp.mod.documentation", { fg = fg_dark, italic = true })

-- Netrw
set_hl("netrwDir", { fg = blue, bold = true })
set_hl("netrwClassify", { fg = fg_dim })
set_hl("netrwLink", { fg = fg_dim, underline = true })
set_hl("netrwSymLink", { fg = cyan, underline = true })
set_hl("netrwExe", { fg = green, bold = true })
set_hl("netrwComment", { fg = fg_dark, italic = true })
set_hl("netrwList", { fg = fg })
set_hl("netrwHelpCmd", { fg = magenta, bold = true })
set_hl("netrwCmdSep", { fg = fg_dim })
set_hl("netrwVersion", { fg = fg_dim })
