-- theme.lua — Palette-driven theme switching
-- Reads from ~/.config/cli-setup/theme, applies via palettes.lua

local M = {}

local theme_file = vim.fn.expand("~/.config/cli-setup/theme")
local palettes = require("config.palettes")

function M.get()
  local f = io.open(theme_file, "r")
  if f then
    local t = f:read("*l")
    f:close()
    if t then
      t = vim.trim(t)
      if palettes[t] then return t end
    end
  end
  return "kanagawa"
end

function M.apply(name)
  name = name or M.get()
  local p = palettes[name]
  if not p then
    p = palettes.kanagawa
    name = "kanagawa"
  end

  -- Set border style globally (used by lsp, completion, etc.)
  vim.g.border_style = p.border_style

  -- Re-configure cyberdream if this theme uses it
  if p.cyberdream_colors then
    local cd_ok, cd = pcall(require, "cyberdream")
    if cd_ok then
      cd.setup({
        transparent = false,
        italic_comments = true,
        hide_fillchars = false,
        terminal_colors = true,
        borderless_pickers = false,
        theme = {
          variant = "default",
          colors = p.cyberdream_colors,
        },
      })
    end
  end

  -- Apply colorscheme
  vim.cmd.colorscheme(p.colorscheme)

  -- Apply terminal ANSI colors (overrides whatever cyberdream/catppuccin set).
  -- Full table if palette defines terminal_colors, otherwise patch the critical ones.
  if p.terminal_colors then
    for i = 0, 15 do
      if p.terminal_colors[i] then
        vim.g["terminal_color_" .. i] = p.terminal_colors[i]
      end
    end
  else
    vim.g.terminal_color_0 = p.colors.bg_alt  -- black
    vim.g.terminal_color_8 = p.colors.muted   -- bright-black (autosuggestions)
  end

  -- Apply highlight overrides
  local hl = vim.api.nvim_set_hl
  for group, opts in pairs(p.highlights) do
    hl(0, group, opts)
  end

  -- Cursor highlights
  for group, opts in pairs(p.cursor_highlights) do
    hl(0, group, opts)
  end

  -- Structural options
  vim.opt.guicursor = p.guicursor
  vim.opt.fillchars = p.fillchars
  vim.opt.statuscolumn = p.statuscolumn
  vim.opt.foldcolumn = p.foldcolumn

  -- Refresh lualine with palette theme
  local ok, lualine = pcall(require, "lualine")
  if ok then
    lualine.setup({ options = { theme = p.lualine_theme } })
  end

  -- Re-apply treesitter-context highlights
  hl(0, "TreesitterContext",           { bg = p.colors.bg_alt })
  hl(0, "TreesitterContextBottom",     { underline = true, sp = p.colors.border })
  hl(0, "TreesitterContextLineNumber", { fg = p.colors.muted, bg = p.colors.bg_alt })
  hl(0, "TreesitterContextSeparator",  { fg = p.colors.border })

  -- Re-apply illuminate word highlights
  hl(0, "IlluminatedWordText",  { bg = p.colors.surface })
  hl(0, "IlluminatedWordRead",  { bg = p.colors.surface })
  hl(0, "IlluminatedWordWrite", { bg = p.colors.surface, underline = true, sp = p.colors.accent })

  -- Re-apply modicator mode colors from palette lualine theme
  local lt = p.lualine_theme
  hl(0, "ModeNormal",   { fg = lt.normal.a.bg,   bold = true })
  hl(0, "ModeInsert",   { fg = lt.insert.a.bg,   bold = true })
  hl(0, "ModeVisual",   { fg = lt.visual.a.bg,   bold = true })
  hl(0, "ModeReplace",  { fg = lt.replace.a.bg,  bold = true })
  hl(0, "ModeCommand",  { fg = lt.command.a.bg,  bold = true })
  hl(0, "ModeTerminal", { fg = (lt.terminal or lt.insert).a.bg, bold = true })

  -- Re-apply rainbow-delimiters colors for new theme
  local c = p.colors
  local rd_colors = {
    c.accent  or "#e8b830",
    c.accent2 or c.red  or "#ff4080",
    c.green   or "#38c860",
    c.yellow  or "#5AC8D8",
    c.purple  or "#957FB8",
    c.fg_dim  or "#727169",
  }
  for i, color in ipairs(rd_colors) do
    hl(0, "RainbowDelimiter" .. i, { fg = color })
  end

  -- Write state file
  local f = io.open(theme_file, "w")
  if f then
    f:write(name .. "\n")
    f:close()
  end
end

function M.toggle()
  local current = M.get()
  local cycle = palettes.cycle
  for i, t in ipairs(cycle) do
    if t == current then
      local next_theme = cycle[(i % #cycle) + 1]
      M.apply(next_theme)
      return
    end
  end
  M.apply(cycle[1])
end

-- User commands
vim.api.nvim_create_user_command("ThemeToggle", function() M.toggle() end, {})
vim.api.nvim_create_user_command("ThemeSet", function(opts)
  local name = opts.args
  if palettes[name] then
    M.apply(name)
  else
    vim.notify("Unknown theme: " .. name .. ". Available: " .. table.concat(palettes.cycle, ", "), vim.log.levels.ERROR)
  end
end, {
  nargs = 1,
  complete = function() return palettes.cycle end,
})

return M
