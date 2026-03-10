-- timetracker.lua — Automatic per-project time tracking with idle detection
-- Data: ~/.local/share/cli-setup/timelog.jsonl
-- Each line: { project, date, start, end, keys, saves, files }

local M = {}

local DATA_FILE = vim.fn.expand("~/.local/share/cli-setup/timelog.jsonl")
local IDLE_THRESHOLD = 120    -- seconds before session is considered idle
local CHECK_INTERVAL  = 30000 -- ms between idle checks

local state = {
  project      = nil,   -- current project root path ("_vim" when outside any git repo)
  session_start= nil,   -- os.time() when this segment started
  last_activity= nil,   -- os.time() of last keypress
  keys         = 0,
  saves        = 0,
  commits      = 0,
  pushes       = 0,
  files        = {},    -- set of bufnr touched this segment
  is_idle      = false,
  timer        = nil,
}

-- Walk up from path to find git root
local function detect_project(path)
  local d = path or vim.fn.expand("%:p:h")
  if d == "" or d == "." then d = vim.fn.getcwd() end
  while d and d ~= "/" do
    if vim.fn.isdirectory(d .. "/.git") == 1 then return d end
    local parent = vim.fn.fnamemodify(d, ":h")
    if parent == d then break end
    d = parent
  end
  return nil
end

local function ensure_dir()
  vim.fn.mkdir(vim.fn.fnamemodify(DATA_FILE, ":h"), "p")
end

-- Append a completed segment to the log
local function flush()
  if not state.project or not state.session_start then return end
  local now = os.time()
  local dur = now - state.session_start
  if dur < 5 then return end  -- ignore sub-5s blips

  ensure_dir()
  local f = io.open(DATA_FILE, "a")
  if not f then return end

  local entry = vim.fn.json_encode({
    project = state.project,
    date    = os.date("%Y-%m-%d", state.session_start),
    start   = state.session_start,
    ["end"] = now,
    keys    = state.keys,
    saves   = state.saves,
    commits = state.commits,
    pushes  = state.pushes,
    files   = vim.tbl_count(state.files),
  })
  f:write(entry .. "\n")
  f:close()

  -- Reset segment counters (project stays)
  state.keys    = 0
  state.saves   = 0
  state.commits = 0
  state.pushes  = 0
  state.files   = {}
  state.session_start = now
end

local function go_idle()
  if state.is_idle then return end
  flush()
  state.session_start = nil
  state.is_idle = true
end

local function resume()
  if not state.is_idle then return end
  state.session_start = os.time()
  state.is_idle = false
end

local function on_activity()
  state.last_activity = os.time()
  if state.is_idle then resume() end
end

local function switch_project(project)
  if project == state.project then return end
  flush()
  state.project       = project
  state.session_start = os.time()
  state.last_activity = os.time()
  state.keys          = 0
  state.saves         = 0
  state.commits       = 0
  state.pushes        = 0
  state.files         = {}
  state.is_idle       = false
end

local function idle_check()
  if not state.last_activity then return end
  if (os.time() - state.last_activity) >= IDLE_THRESHOLD then
    go_idle()
  end
end

function M.setup()
  ensure_dir()

  -- Periodic idle check
  state.timer = vim.uv.new_timer()
  state.timer:start(CHECK_INTERVAL, CHECK_INTERVAL, vim.schedule_wrap(idle_check))

  local g = vim.api.nvim_create_augroup("TimeTracker", { clear = true })

  -- Detect project + start/switch session
  -- Always track: real project root, or "_vim" for non-project buffers
  vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
    group = g,
    callback = function()
      if vim.bo.buftype ~= "" then return end
      local project = detect_project() or "_vim"
      switch_project(project)
    end,
  })

  -- Count ALL keypresses (normal, insert, visual, command) via global key hook
  -- Filter: skip empty/NUL keys and non-file buffers (e.g. heatmap window)
  vim.on_key(function(key)
    if key == "" or key == "\0" then return end
    local bt = vim.bo.buftype
    if bt ~= "" and bt ~= "terminal" then return end
    if state.project then
      state.keys = state.keys + 1
    end
    on_activity()
  end, vim.api.nvim_create_namespace("timetracker_keys"))

  -- Saves
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = g,
    callback = function(ev)
      state.saves = state.saves + 1
      state.files[ev.buf] = true
      on_activity()
    end,
  })

  -- File opens (track unique files)
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = g,
    callback = function(ev)
      if vim.bo[ev.buf].buftype == "" then
        state.files[ev.buf] = true
      end
    end,
  })

  -- Go idle immediately on focus loss — don't count time spent in other tabs.
  -- Tracking only resumes when a key is pressed back in nvim (on_activity → resume).
  vim.api.nvim_create_autocmd("FocusLost", {
    group = g,
    callback = go_idle,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = g,
    callback = function()
      flush()
      if state.timer then
        state.timer:stop()
        state.timer:close()
      end
    end,
  })
end

M.DATA_FILE = DATA_FILE

-- Expose current session state for live display
function M.current()
  return {
    project  = state.project,
    is_idle  = state.is_idle,
    keys     = state.keys,
    saves    = state.saves,
    commits  = state.commits,
    pushes   = state.pushes,
    files    = vim.tbl_count(state.files),
    elapsed  = (state.session_start and not state.is_idle)
               and (os.time() - state.session_start) or 0,
  }
end

-- Called by git-commands.lua after a successful commit
function M.record_commit()
  state.commits = state.commits + 1
  flush()
end

-- Called by git-commands.lua after a successful push
function M.record_push()
  state.pushes = state.pushes + 1
  flush()
end

return M
