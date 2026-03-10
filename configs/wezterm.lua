-- wezterm.lua — WezTerm configuration for nvim-wezterm-setup
-- Copy to your Windows home: C:\Users\<YourName>\.wezterm.lua
-- Or run: cp configs/wezterm.lua /mnt/c/Users/<YourName>/.wezterm.lua

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ── Theme detection ──────────────────────────────────────────
-- Reads ~/.config/nvim-wezterm-setup/theme (written by theme.sh and nvim ThemeSet)
-- Falls back to kanagawa if not found.
local function read_theme()
  -- Try WSL path first (substitute your WSL username if different from Windows username)
  -- The installer writes your WSL username to ~/.config/nvim-wezterm-setup/wsl-username
  local function read_file(p)
    local f = io.open(p, 'r')
    if f then
      local content = f:read('*l')
      f:close()
      return content and content:match('^%s*(.-)%s*$') or nil
    end
    return nil
  end

  -- Try to detect WSL username from a config file
  local wsl_user_file = wezterm.home_dir .. '/.config/nvim-wezterm-setup/wsl-username'
  local wsl_user = read_file(wsl_user_file)

  local paths = {}
  if wsl_user then
    table.insert(paths, '\\\\wsl.localhost\\Ubuntu\\home\\' .. wsl_user .. '\\.config\\nvim-wezterm-setup\\theme')
  end
  table.insert(paths, wezterm.home_dir .. '/.config/nvim-wezterm-setup/theme')

  for _, p in ipairs(paths) do
    local t = read_file(p)
    if t then return t end
  end
  return 'kanagawa'
end

local theme = read_theme()

-- ══════════════════════════════════════════════════════════════
-- Theme table — all per-theme config in one place
-- ══════════════════════════════════════════════════════════════

local themes = {

  -- ── KANAGAWA ──────────────────────────────────────────
  -- Hokusai's Great Wave. Ink on parchment. The transience of all things.
  -- crystalBlue border — the wave, poised and powerful.
  kanagawa = {
    color_scheme = 'Kanagawa Terminal',
    opacity = 0.96,
    background = nil,
    cursor_style = 'BlinkingBar',
    cursor_blink_rate = 800,
    cursor_thickness = '1px',
    animation_fps = 1,
    padding = { left = 16, right = 16, top = 16, bottom = 16 },
    window_frame = {
      border_left_width = '1px', border_right_width = '1px',
      border_top_height = '1px', border_bottom_height = '1px',
      border_left_color = '#7E9CD8', border_right_color = '#7E9CD8',
      border_top_color = '#7E9CD8', border_bottom_color = '#7E9CD8',
    },
    visual_bell = nil,
    inactive_pane_hsb = { hue = 1.0, saturation = 0.8, brightness = 0.75 },
    bold_brightens_ansi_colors = 'No',
    cmd_palette_bg = '#1F1F28',
    cmd_palette_fg = '#7E9CD8',
    tab_bar_bg = '#16161D',
    active_tab = { bg_color = '#1F1F28', fg_color = '#7E9CD8', intensity = 'Bold' },
    inactive_tab = { bg_color = '#16161D', fg_color = '#54546D' },
    inactive_tab_hover = { bg_color = '#1F1F28', fg_color = '#C8C093' },
    new_tab = { bg_color = '#16161D', fg_color = '#54546D' },
    new_tab_hover = { bg_color = '#1F1F28', fg_color = '#7E9CD8' },
    left_status = function(pane)
      return {
        { Background = { Color = '#2A2A37' } },
        { Foreground = { Color = '#7E9CD8' } },
        { Text = '  ' .. (pane:get_domain_name() or 'WSL') .. ' ' },
        { Background = { Color = '#16161D' } },
        { Foreground = { Color = '#2A2A37' } },
        { Text = wezterm.nerdfonts.pl_left_hard_divider },
        'ResetAttributes',
      }
    end,
    right_status = function(time)
      return {
        { Foreground = { Color = '#2A2A37' } },
        { Background = { Color = '#16161D' } },
        { Text = wezterm.nerdfonts.pl_right_hard_divider },
        { Background = { Color = '#2A2A37' } },
        { Foreground = { Color = '#7E9CD8' } },
        { Text = ' ≋ KANAGAWA ' },
        { Background = { Color = '#363646' } },
        { Foreground = { Color = '#C8C093' } },
        { Text = ' ' .. time .. ' ' },
      }
    end,
    active_tab_fmt = function(index, title)
      return {
        { Foreground = { Color = '#54546D' } }, { Text = ' ' .. index .. ' ' },
        { Foreground = { Color = '#7E9CD8' } }, { Attribute = { Intensity = 'Bold' } },
        { Text = title .. ' ' },
        'ResetAttributes',
      }
    end,
    inactive_tab_fmt = function(index, title)
      return {
        { Foreground = { Color = '#363646' } }, { Text = ' ' .. index .. ' ' },
        { Foreground = { Color = '#54546D' } }, { Text = title .. ' ' },
      }
    end,
  },

  -- ── CATPPUCCIN MACCHIATO ───────────────────────────────
  -- Soft pastels on deep navy. Clean and focused.
  -- Blue accent — clear, calm, precise.
  catppuccin = {
    color_scheme = 'Catppuccin Macchiato',
    opacity = 0.97,
    background = nil,
    cursor_style = 'BlinkingBar',
    cursor_blink_rate = 600,
    cursor_thickness = '1px',
    animation_fps = 1,
    padding = { left = 16, right = 16, top = 16, bottom = 16 },
    window_frame = {
      border_left_width = '1px', border_right_width = '1px',
      border_top_height = '1px', border_bottom_height = '1px',
      border_left_color = '#8aadf4', border_right_color = '#8aadf4',
      border_top_color = '#8aadf4', border_bottom_color = '#8aadf4',
    },
    visual_bell = nil,
    inactive_pane_hsb = { hue = 1.0, saturation = 0.7, brightness = 0.75 },
    bold_brightens_ansi_colors = 'BrightAndBold',
    cmd_palette_bg = '#24273a',
    cmd_palette_fg = '#8aadf4',
    tab_bar_bg = '#1e2030',
    active_tab = { bg_color = '#24273a', fg_color = '#8aadf4', intensity = 'Bold' },
    inactive_tab = { bg_color = '#1e2030', fg_color = '#494d64' },
    inactive_tab_hover = { bg_color = '#24273a', fg_color = '#b8c0e0' },
    new_tab = { bg_color = '#1e2030', fg_color = '#494d64' },
    new_tab_hover = { bg_color = '#24273a', fg_color = '#8aadf4' },
    left_status = function(pane)
      return {
        { Background = { Color = '#363a4f' } },
        { Foreground = { Color = '#8aadf4' } },
        { Text = '  ' .. (pane:get_domain_name() or 'WSL') .. ' ' },
        { Background = { Color = '#1e2030' } },
        { Foreground = { Color = '#363a4f' } },
        { Text = wezterm.nerdfonts.pl_left_hard_divider },
        'ResetAttributes',
      }
    end,
    right_status = function(time)
      return {
        { Foreground = { Color = '#363a4f' } },
        { Background = { Color = '#1e2030' } },
        { Text = wezterm.nerdfonts.pl_right_hard_divider },
        { Background = { Color = '#363a4f' } },
        { Foreground = { Color = '#8aadf4' } },
        { Text = ' macchiato ' },
        { Background = { Color = '#494d64' } },
        { Foreground = { Color = '#b8c0e0' } },
        { Text = ' ' .. time .. ' ' },
      }
    end,
    active_tab_fmt = function(index, title)
      return {
        { Foreground = { Color = '#494d64' } }, { Text = ' ' .. index .. ' ' },
        { Foreground = { Color = '#8aadf4' } }, { Attribute = { Intensity = 'Bold' } },
        { Text = title .. ' ' },
        'ResetAttributes',
      }
    end,
    inactive_tab_fmt = function(index, title)
      return {
        { Foreground = { Color = '#363a4f' } }, { Text = ' ' .. index .. ' ' },
        { Foreground = { Color = '#494d64' } }, { Text = title .. ' ' },
      }
    end,
  },
}

local t = themes[theme] or themes.kanagawa

-- ── Color schemes (custom definitions) ───────────────────────
config.color_schemes = {

  -- Kanagawa: ink, parchment, distant waves — authentic Hokusai palette
  ['Kanagawa Terminal'] = {
    foreground = '#DCD7BA',    -- fujiWhite (parchment)
    background = '#1F1F28',    -- sumiInk1 (deep ink)
    cursor_bg = '#7E9CD8',     -- crystalBlue (the wave)
    cursor_fg = '#1F1F28',
    cursor_border = '#7E9CD8',
    selection_fg = '#DCD7BA',
    selection_bg = '#2D4F67',  -- waveBlue2 (deep ocean)
    split = '#7E9CD8',
    ansi = {
      '#16161D', '#C34043', '#76946A', '#C0A36E',
      '#7E9CD8', '#957FB8', '#6A9589', '#C8C093',
    },
    brights = {
      '#727169', '#E82424', '#98BB6C', '#E6C384',
      '#7FB4CA', '#938AA9', '#7AA89F', '#DCD7BA',
    },
    tab_bar = {
      background = '#16161D',
      active_tab   = { bg_color = '#1F1F28', fg_color = '#7E9CD8', intensity = 'Bold' },
      inactive_tab = { bg_color = '#16161D', fg_color = '#54546D' },
      inactive_tab_hover = { bg_color = '#1F1F28', fg_color = '#C8C093' },
      new_tab      = { bg_color = '#16161D', fg_color = '#54546D' },
      new_tab_hover = { bg_color = '#1F1F28', fg_color = '#7E9CD8' },
    },
  },
}

-- Catppuccin Macchiato uses WezTerm's built-in scheme (no custom definition needed)

-- ── Map theme to color scheme name ───────────────────────────
local scheme_map = {
  kanagawa   = 'Kanagawa Terminal',
  catppuccin = 'Catppuccin Macchiato',
}

-- ── Colors ───────────────────────────────────────────────────
config.color_scheme = scheme_map[theme] or 'Kanagawa Terminal'
config.window_background_opacity = t.opacity

if t.background then
  config.background = t.background
end

-- ── Custom tab formatting ────────────────────────────────────
wezterm.on('format-tab-title', function(tab, _tabs, _panes, _cfg, _hover, max_width)
  local title = tab.active_pane.title
  -- Strip "username@hostname:" prefix from shell titles
  title = title:gsub('^[^:]+:', '')
  if #title > max_width - 6 then title = title:sub(1, max_width - 8) .. '…' end
  local index = tab.tab_index + 1
  if tab.is_active then
    return t.active_tab_fmt(index, title)
  else
    return t.inactive_tab_fmt(index, title)
  end
end)

-- ── Status bars ──────────────────────────────────────────────
wezterm.on('update-right-status', function(window, pane)
  local time = wezterm.strftime('%H:%M')
  local left = t.left_status(pane)
  if #left > 0 then
    window:set_left_status(wezterm.format(left))
  else
    window:set_left_status('')
  end
  window:set_right_status(wezterm.format(t.right_status(time)))
end)

-- ── Font ─────────────────────────────────────────────────────
-- Detect font by checking known Windows font file paths.
local function jetbrains_nf_installed()
  local appdata = os.getenv('LOCALAPPDATA') or ''
  local windir  = os.getenv('WINDIR') or 'C:\\Windows'
  for _, p in ipairs({
    appdata .. '\\Microsoft\\Windows\\Fonts\\JetBrainsMonoNerdFont-Regular.ttf',
    windir  .. '\\Fonts\\JetBrainsMonoNerdFont-Regular.ttf',
  }) do
    local f = io.open(p, 'r')
    if f then f:close(); return true end
  end
  return false
end

local font_ok = jetbrains_nf_installed()

if font_ok then
  config.font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Medium' })
else
  config.font = wezterm.font_with_fallback({ 'Consolas', 'Courier New' })
  -- Show a toast on startup telling the user to install the font
  wezterm.on('gui-startup', function(cmd)
    local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
    window:toast_notification(
      'Font not installed',
      'JetBrainsMono Nerd Font is missing - using Consolas fallback.\n\n'
        .. 'To fix: open PowerShell in the nvim-wezterm-setup folder and run:\n'
        .. '    cd ~\\nvim-wezterm-setup; .\\install.ps1',
      nil,
      15000
    )
  end)
end
config.font_size = 11.0
config.line_height = 1.15

-- ── Window ───────────────────────────────────────────────────
config.window_padding = t.padding
config.window_decorations = 'RESIZE'

if t.window_frame then
  config.window_frame = t.window_frame
end

-- ── Cursor ───────────────────────────────────────────────────
config.default_cursor_style = t.cursor_style
config.cursor_blink_rate = t.cursor_blink_rate
config.cursor_blink_ease_in = 'EaseInOut'
config.cursor_blink_ease_out = 'EaseInOut'
config.animation_fps = t.animation_fps
config.cursor_thickness = t.cursor_thickness

-- ── Visual bell ──────────────────────────────────────────────
config.audible_bell = 'Disabled'
if t.visual_bell then
  config.visual_bell = t.visual_bell
end

-- ── Inactive pane dimming ────────────────────────────────────
if t.inactive_pane_hsb then
  config.inactive_pane_hsb = t.inactive_pane_hsb
end
config.bold_brightens_ansi_colors = t.bold_brightens_ansi_colors or 'BrightAndBold'

-- ── Tab bar ──────────────────────────────────────────────────
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.tab_max_width = 32

-- ── Default shell ────────────────────────────────────────────
-- Opens WSL Ubuntu by default. Change 'Ubuntu' to your distro name if different.
config.default_domain = 'local'
config.default_prog = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' }

-- ── Launch menu ──────────────────────────────────────────────
config.launch_menu = {
  { label = 'WSL: Ubuntu', args = { 'wsl.exe', '-d', 'Ubuntu' } },
  { label = 'PowerShell',  args = { 'pwsh.exe' } },
  { label = 'CMD',         args = { 'cmd.exe' } },
}

-- ── Keybindings ──────────────────────────────────────────────
config.keys = {
  -- Copy / Paste
  {
    key = 'c', mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local sel = window:get_selection_text_for_pane(pane)
      if sel and sel ~= '' then
        window:perform_action(wezterm.action.CopyTo('ClipboardAndPrimarySelection'), pane)
        window:perform_action(wezterm.action.ClearSelection, pane)
      else
        window:perform_action(wezterm.action.SendKey { key = 'c', mods = 'CTRL' }, pane)
      end
    end),
  },
  { key = 'v', mods = 'CTRL', action = wezterm.action.PasteFrom('Clipboard') },

  -- New tab
  {
    key = 't', mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnCommandInNewTab {
      domain = { DomainName = 'local' },
      args = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' },
    },
  },
  {
    key = 'p', mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnCommandInNewTab {
      domain = { DomainName = 'local' },
      args = { 'pwsh.exe' },
    },
  },

  -- Tabs: Ctrl+1-7 direct jump
  { key = '1', mods = 'CTRL', action = wezterm.action.ActivateTab(0) },
  { key = '2', mods = 'CTRL', action = wezterm.action.ActivateTab(1) },
  { key = '3', mods = 'CTRL', action = wezterm.action.ActivateTab(2) },
  { key = '4', mods = 'CTRL', action = wezterm.action.ActivateTab(3) },
  { key = '5', mods = 'CTRL', action = wezterm.action.ActivateTab(4) },
  { key = '6', mods = 'CTRL', action = wezterm.action.ActivateTab(5) },
  { key = '7', mods = 'CTRL', action = wezterm.action.ActivateTab(6) },
  { key = 'Tab', mods = 'CTRL', action = wezterm.action.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateTabRelative(-1) },

  -- Yazi file manager in a new tab at current directory
  {
    key = 'y', mods = 'CTRL|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local cwd_uri = pane:get_current_working_dir()
      local dir = '~'
      if cwd_uri then
        local p = cwd_uri.file_path
        if p then dir = p:gsub('/$', '') end
      end
      window:perform_action(wezterm.action.SpawnCommandInNewTab {
        domain = { DomainName = 'local' },
        args = { 'wsl.exe', '-d', 'Ubuntu', '--cd', dir, '--', 'yazi' },
      }, pane)
    end),
  },

  -- Panes: Ctrl+Shift+H/J/K/L to navigate
  { key = 'd', mods = 'CTRL|SHIFT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'e', mods = 'CTRL|SHIFT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'w', mods = 'CTRL|SHIFT', action = wezterm.action.CloseCurrentPane { confirm = true } },
  { key = 'h', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection('Left') },
  { key = 'j', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection('Down') },
  { key = 'k', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection('Up') },
  { key = 'l', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection('Right') },
}

-- ── Command palette ──────────────────────────────────────────
config.command_palette_bg_color = t.cmd_palette_bg
config.command_palette_fg_color = t.cmd_palette_fg

return config
