-- ui.lua — Dashboard, statusline (lualine), select/input UI (dressing)

-- Macro recording component
local function macro_recording()
  local reg = vim.fn.reg_recording()
  if reg ~= "" then return "● REC @" .. reg end
  return ""
end

-- LSP server name component
local function lsp_name()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then return "" end
  return "  " .. clients[1].name
end

return {
  -- Dashboard on start
  {
    "nvimdev/dashboard-nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      local p = require("config.palettes")[require("config.theme").get()]

      return {
        theme = "doom",
        config = {
          header = p.dashboard_header,
          center = {
            { action = "Telescope find_files", desc = " Find file", icon = " ", icon_hl = p.dashboard_icon_hl, key = "f" },
            { action = "Telescope oldfiles", desc = " Recent files", icon = " ", icon_hl = p.dashboard_icon_hl, key = "r" },
            { action = "Telescope live_grep", desc = " Grep text", icon = " ", icon_hl = p.dashboard_icon_hl, key = "g" },
            { action = "Yazi",  desc = " File manager", icon = " ", icon_hl = p.dashboard_icon_hl, key = "e" },
            { action = "lua require('custom.project-wizard').create()", desc = " New project", icon = " ", icon_hl = p.dashboard_icon_hl, key = "p" },
            { action = "qa", desc = " Quit", icon = " ", icon_hl = p.dashboard_icon_hl, key = "q" },
          },
          footer = function()
            local stats = require("lazy").stats()
            local label = require("config.palettes")[require("config.theme").get()].dashboard_footer_label
            local win_h = vim.o.lines - 1
            local buf_lines = vim.api.nvim_buf_line_count(0)
            -- Push footer to ~2 lines above screen bottom
            local pad = math.max(1, win_h - buf_lines - 3)
            local result = {}
            for _ = 1, pad do table.insert(result, "") end
            table.insert(result, " " .. stats.count .. " plugins  " .. string.format("%.0f", stats.startuptime) .. "ms  " .. label)
            return result
          end,
        },
      }
    end,
    config = function(_, opts)
      require("dashboard").setup(opts)
      local p = require("config.palettes")[require("config.theme").get()]
      if p.dashboard_gradient then
        vim.api.nvim_create_autocmd("FileType", {
          pattern = "dashboard",
          callback = function()
            local buf = vim.api.nvim_get_current_buf()
            local win = vim.api.nvim_get_current_win()
            vim.wo[win].wrap = true
            local grad = p.dashboard_gradient
            local ns = vim.api.nvim_create_namespace("dashboard_gradient")
            vim.schedule(function()
              local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
              local has_bg = grad.bg_hl and p.dashboard_bg_art

              -- First pass: find art lines
              local art_lines = {}
              for i, line in ipairs(lines) do
                if line:match("⠀") or line:match("⣀") or line:match("⣿") or line:match("⢴") or line:match("⡠")
                  or line:match("██") or line:match("░█") or line:match("╔═") or line:match("╚═")
                  or line:match("|__") or line:match("____") or line:match("|  |")
                  or line:match("___.") or line:match("\\/") or line:match("≋") then
                  table.insert(art_lines, i)
                end
              end

              if has_bg then
                -- ═══ BACKGROUND ART MODE ═══
                -- Standard header renders normally. We fill empty/whitespace lines
                -- with dim braille art overlays (wallpaper behind dashboard content).

                -- Build lookup set for art/logo lines (to preserve ⠀ structure)
                local art_set = {}
                for _, ln in ipairs(art_lines) do art_set[ln] = true end

                -- 1. Apply standard gradient to header art lines (same as non-bg)
                local n_colors = #grad.colors
                for j, line_num in ipairs(art_lines) do
                  local idx = math.min(math.ceil(j * n_colors / #art_lines), n_colors)
                  vim.api.nvim_buf_add_highlight(buf, ns, grad.colors[idx], line_num - 1, 0, -1)
                end

                -- 2. Apply moon/subtitle/tagline highlights (same as non-bg)
                if grad.moon_hl then
                  for i, line in ipairs(lines) do
                    if line:match("☾") then
                      vim.api.nvim_buf_add_highlight(buf, ns, grad.moon_hl, i - 1, 0, -1)
                    end
                  end
                end
                if grad.subtitle_hl then
                  for i, line in ipairs(lines) do
                    local s, e = line:find("E·D·G·E·R·U·N·N·E·R·S")
                    if s then
                      vim.api.nvim_buf_add_highlight(buf, ns, grad.subtitle_hl, i - 1, s - 1, e)
                    end
                  end
                end
                if grad.tagline_hl then
                  for i, line in ipairs(lines) do
                    if line:match("burn out") or line:match("fade away")
                      or (grad.tagline_pattern and line:match(grad.tagline_pattern)) then
                      vim.api.nvim_buf_add_highlight(buf, ns, grad.tagline_hl, i - 1, 0, -1)
                    end
                  end
                end

                -- 3. Fill lines with dim background art overlays
                local bg_art = p.dashboard_bg_art
                local art_h = #bg_art
                local win_h = vim.o.lines - 1  -- screen height minus cmdline
                local win_w = vim.o.columns  -- match dashboard's center_align
                local art_char_w = vim.fn.strwidth(bg_art[1])

                -- Centered art display for a given art index (offset 2 right)
                -- Art is 400 chars with baked-in fading edges; crop to window width
                local function get_art_display(idx)
                  local al = bg_art[idx]
                  local skip = math.max(0, math.floor((art_char_w - win_w) / 2) - 1)
                  return vim.fn.strcharpart(al, skip, win_w)
                end

                -- Anchor art to screen bottom
                for i, line in ipairs(lines) do
                  local art_idx = i - (win_h - art_h)
                  if art_idx < 1 or art_idx > art_h then goto next_line end
                  local display = get_art_display(art_idx)

                  if line:match("^%s*$") then
                    -- Empty/whitespace line: full art overlay
                    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
                      virt_text = { { display, grad.bg_hl } },
                      virt_text_pos = "overlay",
                    })
                  else
                    -- Content line: overlay art on blank/marker chars
                    -- 'o' marker only on logo lines (lines with braille chars)
                    local has_braille = line:match("[\xE2]") ~= nil
                    local col = 0
                    local byte = 1
                    local line_len = #line
                    while byte <= line_len do
                      local b = line:byte(byte)
                      local is_blank = b == 0x20 or (has_braille and b == 0x6f)
                      if is_blank then
                        local run_start_byte = byte - 1  -- 0-indexed
                        local run_start_col = col
                        while byte <= line_len do
                          b = line:byte(byte)
                          if b == 0x20 or (has_braille and b == 0x6f) then
                            byte = byte + 1
                            col = col + 1
                          else
                            break
                          end
                        end
                        local run_len = col - run_start_col
                        if run_len > 0 then
                          local art_portion = vim.fn.strcharpart(display, run_start_col, run_len)
                          vim.api.nvim_buf_set_extmark(buf, ns, i - 1, run_start_byte, {
                            virt_text = { { art_portion, grad.bg_hl } },
                            virt_text_pos = "overlay",
                          })
                        end
                      else
                        local clen = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
                        local char_w = vim.fn.strwidth(line:sub(byte, byte + clen - 1))
                        byte = byte + clen
                        col = col + char_w
                      end
                    end
                    -- Trailing: fill right side after content with art
                    local content_w = vim.fn.strwidth(line)
                    if content_w < win_w then
                      -- Collect dashboard's eol extmarks (key labels) and remove them
                      local marks = vim.api.nvim_buf_get_extmarks(
                        buf, -1, {i-1, 0}, {i-1, -1}, {details = true}
                      )
                      -- Extract non-whitespace key chars with their highlights
                      local key_chars = {}  -- { {text, hl}, ... }
                      local key_total_w = 0
                      for _, mark in ipairs(marks) do
                        local d = mark[4]
                        if d.virt_text_pos == "eol" and d.ns_id ~= ns then
                          for _, seg in ipairs(d.virt_text) do
                            local trimmed = seg[1]:match("^%s*(.-)%s*$")
                            if trimmed and trimmed ~= "" then
                              table.insert(key_chars, { trimmed, seg[2] })
                              key_total_w = key_total_w + vim.fn.strwidth(trimmed)
                            end
                          end
                          pcall(vim.api.nvim_buf_del_extmark, buf, d.ns_id, mark[1])
                        end
                      end

                      -- Build eol as continuous art with key chars embedded
                      local eol_len = win_w - content_w
                      if eol_len > 0 then
                        local combined = {}
                        if #key_chars > 0 then
                          -- Place key right after content (where dashboard originally shows it)
                          for _, kc in ipairs(key_chars) do
                            table.insert(combined, kc)
                          end
                          local after_key = content_w + key_total_w
                          if after_key < win_w then
                            local art_after = vim.fn.strcharpart(display, after_key, win_w - after_key)
                            table.insert(combined, { art_after, grad.bg_hl })
                          end
                        else
                          -- No key label — just fill with art
                          local art_trail = vim.fn.strcharpart(display, content_w, eol_len)
                          table.insert(combined, { art_trail, grad.bg_hl })
                        end
                        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, #line, {
                          virt_text = combined,
                          virt_text_pos = "inline",
                        })
                      end
                    end
                  end
                  ::next_line::
                end

                -- Extend art below last buffer line to fill screen
                if #lines < win_h then
                  local extras = {}
                  for row = #lines + 1, win_h do
                    local art_idx = row - (win_h - art_h)
                    if art_idx >= 1 and art_idx <= art_h then
                      table.insert(extras, { { get_art_display(art_idx), grad.bg_hl } })
                    else
                      table.insert(extras, { { "", "" } })
                    end
                  end
                  if #extras > 0 then
                    vim.api.nvim_buf_set_extmark(buf, ns, #lines - 1, 0, {
                      virt_lines = extras,
                    })
                  end
                end
              else
                -- ═══ STANDARD MODE ═══
                if grad.smooth then
                  -- Smooth per-line gradient: interpolate between anchor colors
                  local function hex_to_rgb(hex)
                    hex = hex:gsub("#", "")
                    return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
                  end
                  local anchors = {}
                  for _, hl_name in ipairs(grad.colors) do
                    local hl = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
                    if hl.fg then
                      table.insert(anchors, string.format("#%06X", hl.fg))
                    end
                  end
                  local n, na = #art_lines, #anchors
                  for j, line_num in ipairs(art_lines) do
                    local t = (j - 1) / math.max(n - 1, 1)
                    if grad.ease then t = t ^ grad.ease end
                    local seg = t * (na - 1)
                    local si = math.min(math.floor(seg), na - 2)
                    local st = seg - si
                    local r1, g1, b1 = hex_to_rgb(anchors[si + 1])
                    local r2, g2, b2 = hex_to_rgb(anchors[si + 2])
                    local hex = string.format("#%02X%02X%02X",
                      math.floor(r1 + (r2 - r1) * st + 0.5),
                      math.floor(g1 + (g2 - g1) * st + 0.5),
                      math.floor(b1 + (b2 - b1) * st + 0.5))
                    local hl_name = "DashGrad_" .. j
                    vim.api.nvim_set_hl(0, hl_name, { fg = hex })
                    vim.api.nvim_buf_add_highlight(buf, ns, hl_name, line_num - 1, 0, -1)
                  end
                else
                  local n_colors = #grad.colors
                  for j, line_num in ipairs(art_lines) do
                    local idx = math.min(math.ceil(j * n_colors / #art_lines), n_colors)
                    vim.api.nvim_buf_add_highlight(buf, ns, grad.colors[idx], line_num - 1, 0, -1)
                  end
                end
              end

              -- System readout lines (▸ MAGI, ▸ CASPER, etc.)
              for i, line in ipairs(lines) do
                if line:match("▸ ") and not line:match("██") then
                  local readout_hl = grad.colors[#grad.colors] or grad.colors[1]
                  vim.api.nvim_buf_add_highlight(buf, ns, readout_hl, i - 1, 0, -1)
                end
              end
              -- Skyline highlight (box-drawing buildings — Night City)
              if grad.skyline_hl then
                for i, line in ipairs(lines) do
                  if line:match("┌──") or line:match("│░") or line:match("└┴") then
                    vim.api.nvim_buf_add_highlight(buf, ns, grad.skyline_hl, i - 1, 0, -1)
                  end
                end
              end
              -- Moon / subtitle / tagline for non-bg themes
              if not has_bg then
                if grad.moon_hl then
                  for i, line in ipairs(lines) do
                    if line:match("☾") then
                      vim.api.nvim_buf_add_highlight(buf, ns, grad.moon_hl, i - 1, 0, -1)
                    end
                  end
                end
                if grad.subtitle_hl then
                  for i, line in ipairs(lines) do
                    local s, e = line:find("E·D·G·E·R·U·N·N·E·R·S")
                    if s then
                      vim.api.nvim_buf_add_highlight(buf, ns, grad.subtitle_hl, i - 1, s - 1, e)
                    elseif line:match("· U · N") then
                      vim.api.nvim_buf_add_highlight(buf, ns, grad.subtitle_hl, i - 1, 0, -1)
                    end
                  end
                end
                if grad.tagline_hl then
                  for i, line in ipairs(lines) do
                    if line:match("◢") or line:match("✦") or line:match("> wake") or line:match("✧") or line:match("GOD'S") or line:match("ALL'S") or line:match("burn out") or line:match("fade away")
                      or (grad.tagline_pattern and line:match(grad.tagline_pattern)) then
                      vim.api.nvim_buf_add_highlight(buf, ns, grad.tagline_hl, i - 1, 0, -1)
                    end
                  end
                end
              end
            end)
          end,
        })
      end
    end,
  },
  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
    opts = function()
      local p = require("config.palettes")[require("config.theme").get()]
      local mode_map = p.lualine_mode_map

      return {
        options = {
          theme = p.lualine_theme,
          component_separators = p.lualine_component_sep,
          section_separators = p.lualine_section_sep,
          globalstatus = true,
        },
        sections = {
          lualine_a = {
            mode_map and {
              "mode",
              fmt = function(m) return mode_map[m] or m end,
            } or "mode",
          },
          lualine_b = { "branch", "diff" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = {
            { macro_recording, color = p.lualine_macro_color },
            "diagnostics",
            { lsp_name, color = p.lualine_lsp_color },
          },
          lualine_y = { "filetype" },
          lualine_z = { "location" },
        },
      }
    end,
  },
  -- Better select/input UI
  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {
      input = { enabled = true },
      select = { enabled = true, backend = { "telescope", "builtin" } },
    },
  },
}
