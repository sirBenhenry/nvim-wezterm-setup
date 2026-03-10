-- timeheatmap.lua — Interactive heatmap viewer for time tracking data
-- :TimeStats      → project-scoped view (git root of current file)
-- :TimeStatsAll   → global view (all projects)

local M = {}

local DATA_FILE = vim.fn.expand("~/.local/share/cli-setup/timelog.jsonl")

-- ─── Data loading ───────────────────────────────────────────────────────────

local function load_entries()
  local entries = {}
  local f = io.open(DATA_FILE, "r")
  if not f then return entries end
  for line in f:lines() do
    local ok, entry = pcall(vim.fn.json_decode, line)
    if ok and type(entry) == "table" and entry.project and entry.date then
      table.insert(entries, entry)
    end
  end
  f:close()
  return entries
end

-- Add live current session if the tracker is running
local function with_live(entries)
  local ok, tracker = pcall(require, "custom.timetracker")
  if not ok then return entries end
  local cur = tracker.current()
  if cur.project and cur.elapsed > 0 then
    table.insert(entries, {
      project = cur.project,
      date    = os.date("%Y-%m-%d"),
      start   = os.time() - cur.elapsed,
      ["end"] = os.time(),
      keys    = cur.keys,
      saves   = cur.saves,
      files   = cur.files,
      _live   = true,
    })
  end
  return entries
end

-- ─── Aggregation ────────────────────────────────────────────────────────────

-- Returns { [date] = { secs, keys, saves, commits, pushes, files, sessions } }
local function aggregate(entries, project_filter)
  local by_date = {}
  for _, e in ipairs(entries) do
    if not project_filter or e.project == project_filter then
      local date = e.date
      if not by_date[date] then
        by_date[date] = { secs = 0, keys = 0, saves = 0, commits = 0, pushes = 0, files = 0, sessions = 0 }
      end
      local d = by_date[date]
      local dur = (e["end"] or os.time()) - (e.start or 0)
      d.secs     = d.secs     + math.max(0, dur)
      d.keys     = d.keys     + (e.keys    or 0)
      d.saves    = d.saves    + (e.saves   or 0)
      d.commits  = d.commits  + (e.commits or 0)
      d.pushes   = d.pushes   + (e.pushes  or 0)
      d.files    = d.files    + (e.files   or 0)
      d.sessions = d.sessions + 1
    end
  end
  return by_date
end

-- Totals across all dates
local function totals(by_date)
  local t = { secs = 0, keys = 0, saves = 0, commits = 0, pushes = 0, files = 0, sessions = 0, active_days = 0 }
  for _, d in pairs(by_date) do
    t.secs     = t.secs     + d.secs
    t.keys     = t.keys     + d.keys
    t.saves    = t.saves    + d.saves
    t.commits  = t.commits  + d.commits
    t.pushes   = t.pushes   + d.pushes
    t.files    = t.files    + d.files
    t.sessions = t.sessions + d.sessions
    t.active_days = t.active_days + 1
  end
  return t
end

-- ─── Formatting helpers ──────────────────────────────────────────────────────

local function fmt_dur(secs)
  secs = math.floor(secs)
  if secs < 60 then return secs .. "s" end
  local m = math.floor(secs / 60)
  if m < 60 then return m .. "m" end
  local h = math.floor(m / 60)
  local rem = m % 60
  if rem == 0 then return h .. "h" end
  return h .. "h " .. rem .. "m"
end

local function fmt_num(n)
  -- add thousands separator
  local s = tostring(math.floor(n))
  return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function pad(s, w)
  s = tostring(s)
  local len = vim.fn.strdisplaywidth(s)
  if len >= w then return s end
  return s .. string.rep(" ", w - len)
end

local function center(s, w)
  local len = vim.fn.strdisplaywidth(s)
  if len >= w then return s end
  local left = math.floor((w - len) / 2)
  return string.rep(" ", left) .. s
end

-- ─── Heatmap geometry ───────────────────────────────────────────────────────

local CELL  = "■"   -- filled square
local EMPTY = "·"   -- empty day (past, no data)
local FUTURE= " "   -- future date
local WEEKS = 26    -- how many weeks to display (6 months)

-- Returns ordered list of ISO date strings for the heatmap grid
-- Grid: 7 rows (Mon→Sun), WEEKS columns
-- Anchor: last Sunday or today's week-end
local function build_date_grid()
  -- Find the most recent Sunday
  local today = os.time()
  local today_wday = tonumber(os.date("%w", today))  -- 0=Sun
  -- days since last Sunday
  local days_since_sun = today_wday
  local last_sun = today - days_since_sun * 86400

  -- Grid starts WEEKS-1 weeks before last_sun
  local grid_start = last_sun - (WEEKS - 1) * 7 * 86400

  local grid = {}  -- grid[col][row] = date_string, 1-indexed, col=week, row=day(1=Sun)
  for w = 1, WEEKS do
    grid[w] = {}
    for d = 0, 6 do
      local t = grid_start + ((w - 1) * 7 + d) * 86400
      if t <= today then
        grid[w][d + 1] = os.date("%Y-%m-%d", t)
      else
        grid[w][d + 1] = nil  -- future
      end
    end
  end
  return grid, grid_start
end

-- Intensity level 0–4 based on seconds
local function intensity(secs)
  if secs <= 0     then return 0 end
  if secs < 1800   then return 1 end  -- < 30m
  if secs < 7200   then return 2 end  -- < 2h
  if secs < 14400  then return 3 end  -- < 4h
  return 4
end

-- Month labels for the top of the heatmap
local MONTH_ABBR = { "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec" }

local function month_labels(grid, grid_start)
  local labels = {}  -- { col, label }
  local last_month = nil
  for w = 1, WEEKS do
    local date = grid[w][1]  -- Sunday of this week
    if date then
      local m = tonumber(date:sub(6, 7))
      if m ~= last_month then
        table.insert(labels, { col = w, label = MONTH_ABBR[m] })
        last_month = m
      end
    end
  end
  return labels
end

-- ─── Highlight groups ────────────────────────────────────────────────────────

local function setup_hl()
  local palette = {}
  local tok, theme = pcall(require, "config.theme")
  if tok then
    local pok, p = pcall(require, "config.palettes")
    if pok then
      local name = theme.get and theme.get() or "mocha"
      palette = p[name] or {}
    end
  end

  local c = palette.colors or {}
  local bg    = c.bg      or "#1a1a2e"
  local bg_alt= c.bg_alt  or "#252540"
  local acc   = c.accent  or "#00d4ff"
  local fg    = c.fg      or "#e0e0ff"
  local muted = c.muted   or "#555577"

  -- Per-theme gradient from palettes.lua, fallback to green
  local heat = palette.heat_colors or { "#164430", "#216e39", "#30a14e", "#39d353" }

  vim.api.nvim_set_hl(0, "TimeHeatL0",     { fg = muted,    bg = bg })
  vim.api.nvim_set_hl(0, "TimeHeatL1",     { fg = heat[1],  bg = bg })
  vim.api.nvim_set_hl(0, "TimeHeatL2",     { fg = heat[2],  bg = bg })
  vim.api.nvim_set_hl(0, "TimeHeatL3",     { fg = heat[3],  bg = bg })
  vim.api.nvim_set_hl(0, "TimeHeatL4",     { fg = heat[4],  bg = bg })
  vim.api.nvim_set_hl(0, "TimeHeatCursor", { fg = "#ffffff", bold = true })
  vim.api.nvim_set_hl(0, "TimeHeatTitle",  { fg = acc,      bg = bg,  bold = true })
  vim.api.nvim_set_hl(0, "TimeHeatStat",   { fg = fg,       bg = bg })
  vim.api.nvim_set_hl(0, "TimeHeatLabel",  { fg = muted,    bg = bg })
  vim.api.nvim_set_hl(0, "TimeHeatSep",    { fg = bg_alt,   bg = bg })
  vim.api.nvim_set_hl(0, "TimeHeatBg",      { bg = bg })
  vim.api.nvim_set_hl(0, "TimeHeatLive",    { fg = c.accent2 or "#ff9944", bg = bg, bold = true })
  -- Cursor made invisible: fg = bg so the character shows through, bg = bg so the block disappears
  vim.api.nvim_set_hl(0, "TimeHeatNoCursor", { fg = bg, bg = bg })
end

local HL_LEVEL = { "TimeHeatL0", "TimeHeatL1", "TimeHeatL2", "TimeHeatL3", "TimeHeatL4" }

-- ─── Window layout constants ─────────────────────────────────────────────────

local WIN_W    = 64
local STATS_H  = 7   -- lines for top stats block
local SEP_H    = 1   -- separator line
local MLABEL_H = 1   -- month label row
local HEAT_H   = 7   -- heatmap rows (Sun–Sat)
local SEP2_H   = 1
local DAY_H    = 5   -- bottom day detail block
local WIN_H    = STATS_H + SEP_H + MLABEL_H + HEAT_H + SEP2_H + DAY_H

-- Row offsets (0-indexed)
local R_STATS  = 0
local R_SEP1   = STATS_H
local R_MLABEL = R_SEP1   + SEP_H
local R_HEAT   = R_MLABEL + MLABEL_H
local R_SEP2   = R_HEAT   + HEAT_H
local R_DAY    = R_SEP2   + SEP2_H

-- ─── Buffer building ────────────────────────────────────────────────────────

local function build_lines(by_date, grid, title)
  local tot = totals(by_date)
  local today_str = os.date("%Y-%m-%d")
  local today_data = by_date[today_str] or {}

  local SEP = string.rep("─", WIN_W)
  local lines = {}
  local hls   = {}  -- { line, col_start, col_end, hl_group }

  local function hl(line_idx, cs, ce, group)
    table.insert(hls, { line_idx, cs, ce, group })
  end

  local function push(s)
    -- Pad/truncate to WIN_W
    local w = vim.fn.strdisplaywidth(s)
    if w < WIN_W then s = s .. string.rep(" ", WIN_W - w) end
    table.insert(lines, s)
    return #lines - 1  -- 0-indexed line number
  end

  -- ── Stats block ──────────────────────────────────────────────────────────
  local li

  li = push(" " .. title)
  hl(li, 1, 1 + vim.fn.strdisplaywidth(title), "TimeHeatTitle")

  -- row 1: total time + today
  local s1 = string.format(" Total %-12s  Today  %s",
    fmt_dur(tot.secs), fmt_dur(today_data.secs or 0))
  li = push(s1)
  hl(li, 0, WIN_W, "TimeHeatStat")

  -- row 2: keys
  local s2 = string.format(" Keys  %-12s  Today  %s",
    fmt_num(tot.keys), fmt_num(today_data.keys or 0))
  li = push(s2)
  hl(li, 0, WIN_W, "TimeHeatStat")

  -- row 3: commits + pushes
  local s3 = string.format(" Commits %-10s  Pushes  %s",
    fmt_num(tot.commits), fmt_num(tot.pushes))
  li = push(s3)
  hl(li, 0, WIN_W, "TimeHeatStat")

  -- row 4: saves + active days
  local s4b = string.format(" Saves %-12s  Active days  %d",
    fmt_num(tot.saves), tot.active_days)
  li = push(s4b)
  hl(li, 0, WIN_W, "TimeHeatStat")

  -- row 5: avg per active day
  local avg_secs = tot.active_days > 0 and (tot.secs / tot.active_days) or 0
  local s5 = string.format(" Avg/day  %-10s  Sessions  %d",
    fmt_dur(avg_secs), tot.sessions)
  li = push(s5)
  hl(li, 0, WIN_W, "TimeHeatStat")

  -- row 6: files opened
  local s6 = string.format(" Files opened  %s", fmt_num(tot.files))
  li = push(s6)
  hl(li, 0, WIN_W, "TimeHeatStat")

  -- ── Separator ────────────────────────────────────────────────────────────
  li = push(SEP)
  hl(li, 0, WIN_W, "TimeHeatSep")

  -- ── Month labels ─────────────────────────────────────────────────────────
  local month_line = string.rep(" ", WIN_W)
  local mlabels = month_labels(grid, nil)
  -- Each cell is 1 char + spacing: left margin 4 chars, then 1 char per week column with no spacing
  -- Actually we render the heatmap with a 4-char left margin (day labels) then 1 char per week
  -- So month col = 4 + (w-1) * 1 ... wait, we need to figure out spacing first

  -- Heatmap: 4-char left margin ("Sun ") then WEEKS columns, 1 char each
  -- Actually let me do: left pad = 5 (day label + space), then each week = 2 chars (cell + space)
  -- 5 + 26*2 = 57 chars, fits in WIN_W=64

  local HEAT_LEFT = 5  -- "Sun  " width
  local CELL_W    = 2  -- each cell + trailing space

  -- Build month label line
  local ml_bytes = {}
  for i = 1, WIN_W do ml_bytes[i] = " " end
  for _, lbl in ipairs(mlabels) do
    local x = HEAT_LEFT + (lbl.col - 1) * CELL_W
    for ci = 1, #lbl.label do
      if x + ci - 1 <= WIN_W then
        ml_bytes[x + ci] = lbl.label:sub(ci, ci)
      end
    end
  end
  li = push(table.concat(ml_bytes))
  hl(li, 0, WIN_W, "TimeHeatLabel")

  -- ── Heatmap rows ─────────────────────────────────────────────────────────
  -- grid[col][row]: row 1=Sun, 2=Mon, ..., 7=Sat
  local DAY_LABELS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
  -- We'll store heatmap line indices and cell positions for later cursor highlight
  -- heat_cells[row][col] = { line_idx, byte_col }
  local heat_cells = {}

  for row = 1, 7 do
    heat_cells[row] = {}
    local parts = {}
    table.insert(parts, DAY_LABELS[row] .. "  ")  -- 5 chars

    local line_chars = DAY_LABELS[row] .. "  "
    local cell_positions = {}  -- col → byte start in line (1-indexed)

    for col = 1, WEEKS do
      local date = grid[col][row]
      local cell_start = #line_chars + 1

      if date == nil then
        line_chars = line_chars .. FUTURE .. " "
      elseif not by_date[date] then
        line_chars = line_chars .. EMPTY .. " "
      else
        line_chars = line_chars .. CELL .. " "
      end
      cell_positions[col] = cell_start
    end

    li = push(line_chars)
    -- Apply per-cell highlights
    for col = 1, WEEKS do
      local date = grid[col][row]
      if date and by_date[date] then
        local lvl = intensity(by_date[date].secs)
        -- byte positions (0-indexed for nvim_buf_add_highlight)
        -- CELL is UTF-8 "■" = 3 bytes; EMPTY "·" = 2 bytes
        local cs = cell_positions[col] - 1
        local ce = cs + 3  -- ■ is 3 bytes
        hl(li, cs, ce, HL_LEVEL[lvl + 1])
      elseif date then
        local cs = cell_positions[col] - 1
        local ce = cs + #EMPTY
        hl(li, cs, ce, "TimeHeatLabel")
      end
    end
    heat_cells[row][0] = { li = li, positions = cell_positions }
  end

  -- ── Separator 2 ──────────────────────────────────────────────────────────
  li = push(SEP)
  hl(li, 0, WIN_W, "TimeHeatSep")

  -- ── Day detail block (placeholder — filled by cursor update) ─────────────
  for _ = 1, DAY_H do push("") end

  return lines, hls, heat_cells
end

-- ─── Cursor + day detail update ─────────────────────────────────────────────

local function fmt_day_detail(date, data, buf, ns)
  -- Clear the day detail section
  local day_lines = {}

  if not date then
    for _ = 1, DAY_H do table.insert(day_lines, "") end
    vim.api.nvim_buf_set_lines(buf, R_DAY, R_DAY + DAY_H, false, day_lines)
    return
  end

  -- Parse date
  local y, mo, d = date:match("(%d+)-(%d+)-(%d+)")
  local weekday_names = { "Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday" }
  local t = os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d) })
  local wday = weekday_names[tonumber(os.date("%w", t)) + 1]

  local function lpad(s) return " " .. s end

  if not data then
    table.insert(day_lines, lpad(wday .. "  " .. date))
    table.insert(day_lines, lpad("No activity recorded"))
    for _ = #day_lines + 1, DAY_H do table.insert(day_lines, "") end
  else
    table.insert(day_lines, lpad(wday .. "  " .. date))
    table.insert(day_lines, lpad(string.format("Time    %s", fmt_dur(data.secs or 0))))
    table.insert(day_lines, lpad(string.format("Keys    %s  Saves  %s",
      fmt_num(data.keys or 0), fmt_num(data.saves or 0))))
    table.insert(day_lines, lpad(string.format("Files   %s  Sessions  %d",
      fmt_num(data.files or 0), data.sessions or 0)))
    for _ = #day_lines + 1, DAY_H do table.insert(day_lines, "") end
  end

  -- Pad all lines to WIN_W
  for i, l in ipairs(day_lines) do
    local w = vim.fn.strdisplaywidth(l)
    if w < WIN_W then day_lines[i] = l .. string.rep(" ", WIN_W - w) end
  end

  vim.api.nvim_buf_set_lines(buf, R_DAY, R_DAY + DAY_H, false, day_lines)

  -- Highlight
  if data then
    vim.api.nvim_buf_add_highlight(buf, ns, "TimeHeatTitle", R_DAY, 0, -1)
    for i = 1, DAY_H - 1 do
      vim.api.nvim_buf_add_highlight(buf, ns, "TimeHeatStat", R_DAY + i, 0, -1)
    end
  else
    vim.api.nvim_buf_add_highlight(buf, ns, "TimeHeatTitle", R_DAY, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns, "TimeHeatLabel", R_DAY + 1, 0, -1)
  end
end

-- ─── Main open function ──────────────────────────────────────────────────────

local function open_heatmap(project_filter)
  setup_hl()

  local entries = with_live(load_entries())
  local by_date = aggregate(entries, project_filter)
  local grid, _ = build_date_grid()

  -- Title
  local title
  if project_filter then
    title = vim.fn.fnamemodify(project_filter, ":t")
  else
    -- Count unique real projects (exclude _vim catch-all)
    local projs = {}
    for _, e in ipairs(entries) do
      if e.project ~= "_vim" then projs[e.project] = true end
    end
    title = "All Vim time  ·  " .. vim.tbl_count(projs) .. " projects"
  end

  local lines, hls, heat_cells = build_lines(by_date, grid, title)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype    = "nofile"
  vim.bo[buf].bufhidden  = "wipe"
  vim.bo[buf].swapfile   = false
  vim.bo[buf].filetype   = "timeheatmap"

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Apply static highlights
  local ns = vim.api.nvim_create_namespace("timeheatmap")
  for _, h in ipairs(hls) do
    local li, cs, ce, grp = h[1], h[2], h[3], h[4]
    pcall(vim.api.nvim_buf_add_highlight, buf, ns, grp, li, cs, ce)
  end

  -- Background fill
  for i = 0, WIN_H - 1 do
    vim.api.nvim_buf_add_highlight(buf, ns, "TimeHeatBg", i, 0, -1)
  end

  -- Open floating window
  local row = math.floor((vim.o.lines   - WIN_H) / 2)
  local col = math.floor((vim.o.columns - WIN_W) / 2)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row      = row,
    col      = col,
    width    = WIN_W,
    height   = WIN_H,
    style    = "minimal",
    border   = vim.g.border_style or "rounded",
    title    = " Time Tracker ",
    title_pos= "center",
    zindex   = 50,
  })

  -- Cursor:TimeHeatNoCursor makes the native vim cursor invisible (fg=bg=bg)
  -- Navigation is driven purely by the cyan extmark highlight
  vim.wo[win].winhighlight = "Normal:TimeHeatBg,FloatBorder:TimeHeatSep,FloatTitle:TimeHeatTitle,Cursor:TimeHeatNoCursor,CursorLine:TimeHeatBg,TermCursor:TimeHeatNoCursor"
  vim.wo[win].cursorline   = false
  vim.wo[win].number       = false
  vim.wo[win].relativenumber = false

  -- ── Cursor state ─────────────────────────────────────────────────────────
  -- cursor: { row = 1..7, col = 1..WEEKS }
  local cursor = { row = 1, col = WEEKS }  -- start at today's column

  -- Find today's column
  local today_str = os.date("%Y-%m-%d")
  for c = 1, WEEKS do
    for r = 1, 7 do
      if grid[c][r] == today_str then
        cursor.row = r
        cursor.col = c
        break
      end
    end
  end

  local cursor_ns = vim.api.nvim_create_namespace("timeheatmap_cursor")

  local HEAT_LEFT = 5
  local CELL_W    = 2

  local function draw_cursor()
    vim.api.nvim_buf_clear_namespace(buf, cursor_ns, 0, -1)

    local row_info = heat_cells[cursor.row][0]
    if not row_info then return end
    local li  = row_info.li
    local pos = row_info.positions[cursor.col]
    if not pos then return end

    local cs = pos - 1  -- 0-indexed byte
    local ce = cs + 3   -- ■ = 3 bytes; EMPTY/FUTURE = 1-2 bytes but we highlight same span

    -- Check what's actually there
    local line = vim.api.nvim_buf_get_lines(buf, li, li + 1, false)[1] or ""
    local byte = line:sub(pos, pos + 2)
    if byte == CELL then
      ce = cs + 3
    else
      ce = cs + #EMPTY
    end

    vim.api.nvim_buf_add_highlight(buf, cursor_ns, "TimeHeatCursor", li, cs, ce)

    -- Update day detail
    local date = grid[cursor.col][cursor.row]
    fmt_day_detail(date, date and by_date[date], buf, cursor_ns)
  end

  -- ── Keymaps ──────────────────────────────────────────────────────────────
  local opts = { buffer = buf, silent = true, nowait = true }

  local function move(dr, dc)
    local new_row = cursor.row + dr
    local new_col = cursor.col + dc
    if new_row < 1 then new_row = 1 end
    if new_row > 7 then new_row = 7 end
    if new_col < 1 then new_col = 1 end
    if new_col > WEEKS then new_col = WEEKS end
    cursor.row = new_row
    cursor.col = new_col
    vim.bo[buf].modifiable = true
    draw_cursor()
    vim.bo[buf].modifiable = false
    -- keep vim cursor in heatmap rows for visual context
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
  end

  vim.keymap.set("n", "h", function() move(0, -1) end, opts)
  vim.keymap.set("n", "l", function() move(0,  1) end, opts)
  vim.keymap.set("n", "k", function() move(-1, 0) end, opts)
  vim.keymap.set("n", "j", function() move( 1, 0) end, opts)
  vim.keymap.set("n", "<Left>",  function() move(0, -1) end, opts)
  vim.keymap.set("n", "<Right>", function() move(0,  1) end, opts)
  vim.keymap.set("n", "<Up>",    function() move(-1, 0) end, opts)
  vim.keymap.set("n", "<Down>",  function() move( 1, 0) end, opts)

  -- Jump to today
  vim.keymap.set("n", "t", function()
    for c = 1, WEEKS do
      for r = 1, 7 do
        if grid[c][r] == today_str then
          cursor.row = r
          cursor.col = c
          vim.bo[buf].modifiable = true
          draw_cursor()
          vim.bo[buf].modifiable = false
          vim.api.nvim_win_set_cursor(win, { 1, 0 })
          return
        end
      end
    end
  end, opts)

  -- Close
  for _, key in ipairs({ "q", "<Esc>", "<CR>" }) do
    vim.keymap.set("n", key, function()
      vim.api.nvim_win_close(win, true)
    end, opts)
  end

  -- Disable all other normal-mode movements that would break the layout
  for _, key in ipairs({ "gg", "G", "zz", "<C-f>", "<C-b>", "<C-d>", "<C-u>" }) do
    vim.keymap.set("n", key, "<Nop>", opts)
  end

  -- Initial draw (buffer still modifiable here), then lock
  draw_cursor()
  vim.bo[buf].modifiable = false
  vim.api.nvim_win_set_cursor(win, { R_HEAT + cursor.row, 0 })
end

-- ─── Commands ────────────────────────────────────────────────────────────────

function M.setup()
  -- :Stats — project-scoped
  vim.api.nvim_create_user_command("Stats", function()
    -- Detect current project
    local dir = vim.fn.expand("%:p:h")
    if dir == "" then dir = vim.fn.getcwd() end
    local project = nil
    local d = dir
    while d and d ~= "/" do
      if vim.fn.isdirectory(d .. "/.git") == 1 then
        project = d
        break
      end
      local parent = vim.fn.fnamemodify(d, ":h")
      if parent == d then break end
      d = parent
    end
    if not project then
      vim.notify("Not in a git project — use :StatsAll for global view", vim.log.levels.WARN)
      return
    end
    open_heatmap(project)
  end, { desc = "Show project time heatmap" })

  -- :StatsAll — global
  vim.api.nvim_create_user_command("StatsAll", function()
    open_heatmap(nil)
  end, { desc = "Show global time heatmap (all projects)" })
end

return M
