-- lint-runner.lua — Pylint integration with auto-fix and two-panel UI
-- :LintFile  (Space ll) — lint current buffer
-- :LintProject (Space lL) — lint all .py files from git root
-- Flow: ruff --fix → pylint JSON → auto-fix remaining → two-panel review UI

local M = {}

-- ── Utilities ──────────────────────────────────────────────────────

local function git_root(path)
  local r = vim.fn.systemlist("git -C " .. vim.fn.shellescape(path) .. " rev-parse --show-toplevel 2>/dev/null")
  if r and r[1] and r[1] ~= "" and not r[1]:match("^fatal") then
    return r[1]
  end
  return path
end

local function find_exe(names, root)
  local venv  = root .. "/.venv/bin/"
  local mason = vim.fn.stdpath("data") .. "/mason/bin/"
  for _, name in ipairs(names) do
    for _, prefix in ipairs({ venv, "", mason }) do
      local candidate = prefix .. name
      if vim.fn.executable(candidate) == 1 then return candidate end
    end
  end
  return nil
end

local function find_pylintrc(root)
  for _, p in ipairs({
    root .. "/.github/autograding/pylintrc",
    root .. "/.pylintrc",
    root .. "/pylintrc",
  }) do
    if vim.fn.filereadable(p) == 1 then return p end
  end
  return nil
end

local function load_school_config(root)
  local p = root .. "/.github/autograding/lint.json"
  if vim.fn.filereadable(p) == 0 then return nil end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(p), "\n"))
  return ok and data or nil
end

-- ── Issue categorization ───────────────────────────────────────────

local DOCSTRING = {
  ["missing-module-docstring"]   = "module",
  ["missing-class-docstring"]    = "class",
  ["missing-function-docstring"] = "function",
}

local AUTOFIXABLE = {
  ["trailing-whitespace"]   = true,
  ["missing-final-newline"] = true,
  ["unnecessary-semicolon"] = true,
}

local function categorize(issues)
  local auto, needs_input, manual = {}, {}, {}
  for _, issue in ipairs(issues) do
    if AUTOFIXABLE[issue.symbol] then
      table.insert(auto, issue)
    elseif DOCSTRING[issue.symbol] then
      table.insert(needs_input, issue)
    else
      table.insert(manual, issue)
    end
  end
  return auto, needs_input, manual
end

-- ── Pylint-specific auto-fixer ─────────────────────────────────────

local function apply_fixes(issues_by_file)
  local total = 0
  for filepath, issues in pairs(issues_by_file) do
    local lines = vim.fn.readfile(filepath)
    if not lines or #lines == 0 then goto continue end

    table.sort(issues, function(a, b) return a.line > b.line end)

    local add_final_newline = false
    for _, issue in ipairs(issues) do
      local lnum = issue.line
      local line  = lines[lnum]
      if not line then goto skip end

      if issue.symbol == "trailing-whitespace" then
        lines[lnum] = line:gsub("%s+$", "")
        total = total + 1
      elseif issue.symbol == "unnecessary-semicolon" then
        lines[lnum] = line:gsub(";%s*$", "")
        total = total + 1
      elseif issue.symbol == "missing-final-newline" then
        add_final_newline = true
        total = total + 1
      end
      ::skip::
    end

    if add_final_newline and lines[#lines] ~= "" then
      table.insert(lines, "")
    end
    vim.fn.writefile(lines, filepath)
    ::continue::
  end
  return total
end

-- ── Two-panel Lint UI ──────────────────────────────────────────────

local ui_state = nil

-- Forward declarations (mutually recursive)
local confirm_edit, cancel_edit

local function close_ui()
  local s = ui_state
  if not s then return end
  ui_state = nil

  -- Clean up edit-mode keymaps from right buffer
  if s.right_buf and vim.api.nvim_buf_is_valid(s.right_buf) then
    pcall(vim.keymap.del, "n", "<CR>",  { buffer = s.right_buf })
    pcall(vim.keymap.del, "n", "<Esc>", { buffer = s.right_buf })
  end

  -- Clean up autocmd group
  pcall(vim.api.nvim_del_augroup_by_id, s.close_augroup)

  pcall(vim.api.nvim_win_close, s.left_win,  true)
  pcall(vim.api.nvim_win_close, s.right_win, true)
end

local function build_left_lines(issues, current)
  local n     = #issues
  local lines = {
    "",
    string.format("  %d issue%s remaining", n, n == 1 and "" or "s"),
    "",
  }
  for i, issue in ipairs(issues) do
    local prefix = i == current and "▶ " or "  "
    local kind   = DOCSTRING[issue.symbol] and "docstring" or "manual"
    local fname  = vim.fn.fnamemodify(issue.path, ":t")
    table.insert(lines, string.format(
      "%s%d. [%s] %s  %s:%d", prefix, i, issue["message-id"], kind, fname, issue.line
    ))
    table.insert(lines, "     " .. issue.message)
    table.insert(lines, "")
  end
  table.insert(lines, "  j/k navigate   Enter fix   Esc cancel   q close")
  table.insert(lines, "")
  return lines
end

local function refresh_left()
  local s = ui_state
  if not s or not vim.api.nvim_buf_is_valid(s.left_buf) then return end
  local lines = build_left_lines(s.issues, s.current)
  vim.bo[s.left_buf].modifiable = true
  vim.api.nvim_buf_set_lines(s.left_buf, 0, -1, false, lines)
  vim.bo[s.left_buf].modifiable = false
  -- Cursor: 3-line header, then 3 lines per issue
  local lnum = 4 + (s.current - 1) * 3
  pcall(vim.api.nvim_win_set_cursor, s.left_win, { lnum, 0 })
end

-- Approximate scroll target — used only for navigation preview.
-- May drift slightly after insertions; that's acceptable for scrolling.
local function get_effective_line(issue, s)
  local line = issue.line
  for _, ins_line in ipairs(s.insertions[issue.path] or {}) do
    if ins_line < line then line = line + 1 end
  end
  return line
end

-- Search the actual buffer for the def/class line by name, starting near hint.
-- This bypasses offset tracking entirely for the critical insertion point.
local function find_def_line(bufnr, issue, hint)
  local kind = DOCSTRING[issue.symbol]
  if kind == "module" then return nil end

  local name = (issue.obj and issue.obj ~= "") and vim.pesc(issue.obj) or nil
  if not name then return hint end

  local pattern = kind == "class"
    and ("^%s*class%s+" .. name)
    or  ("^%s*def%s+"   .. name .. "%s*%(")

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local n = #lines

  -- Search outward from hint so we find the closest match
  for radius = 0, n do
    local below = hint + radius
    local above = hint - radius
    if below <= n and lines[below] and lines[below]:match(pattern) then return below end
    if radius > 0 and above >= 1 and lines[above] and lines[above]:match(pattern) then return above end
  end
  return hint
end

local function show_in_right(issue)
  local s = ui_state
  if not s or not vim.api.nvim_win_is_valid(s.right_win) then return end

  local filepath       = issue.path
  local effective_line = get_effective_line(issue, s)

  -- Only load when the file actually changes — avoids reloading mid-edit
  if s.right_file ~= filepath then
    -- Explicitly switch focus to load the file — nvim_win_call doesn't
    -- reliably open files in floating windows
    local cur_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(s.right_win)
    vim.cmd("silent! edit " .. vim.fn.fnameescape(filepath))
    s.right_buf  = vim.api.nvim_win_get_buf(s.right_win)
    s.right_file = filepath

    -- :edit resets window options; re-apply
    vim.wo[s.right_win].number         = true
    vim.wo[s.right_win].relativenumber = false
    vim.wo[s.right_win].signcolumn     = "no"
    vim.wo[s.right_win].foldcolumn     = "0"
    vim.wo[s.right_win].wrap           = false
    vim.wo[s.right_win].scrolloff      = 8

    pcall(vim.api.nvim_win_set_config, s.right_win, {
      title     = " " .. vim.fn.fnamemodify(filepath, ":t") .. " ",
      title_pos = "center",
    })

    vim.api.nvim_set_current_win(cur_win)
  end

  local line_count = vim.api.nvim_buf_line_count(s.right_buf)
  local target     = math.max(1, math.min(effective_line, line_count))
  pcall(vim.api.nvim_win_set_cursor, s.right_win, { target, 0 })
  vim.api.nvim_win_call(s.right_win, function() vim.cmd("normal! zz") end)
end

local function move_selection(delta)
  local s = ui_state
  if not s or s.mode ~= "list" then return end
  s.current = math.max(1, math.min(#s.issues, s.current + delta))
  refresh_left()
  show_in_right(s.issues[s.current])
end

local function set_edit_keymaps(bufnr)
  vim.keymap.set("n", "<CR>",  confirm_edit, { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<Esc>", cancel_edit,  { buffer = bufnr, nowait = true })
end

local function clear_edit_keymaps(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.keymap.del, "n", "<CR>",  { buffer = bufnr })
    pcall(vim.keymap.del, "n", "<Esc>", { buffer = bufnr })
  end
end

local function enter_edit_mode()
  local s = ui_state
  if not s or s.mode ~= "list" then return end
  local issue = s.issues[s.current]
  if not issue then return end

  local is_docstring   = DOCSTRING[issue.symbol] ~= nil
  local filepath       = issue.path
  local bufnr          = s.right_buf
  local effective_line = get_effective_line(issue, s)

  set_edit_keymaps(bufnr)

  if is_docstring then
    local kind  = DOCSTRING[issue.symbol]
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    local insert_at, indent

    if kind == "module" then
      -- Insert at top, after any shebang/encoding lines
      insert_at = 0
      for i = 1, math.min(3, #lines) do
        if lines[i]:match("^#!") or lines[i]:match("coding") then
          insert_at = i
        end
      end
      indent = ""
    else
      -- Search the buffer for the actual def/class line — bypasses offset drift
      local actual = find_def_line(bufnr, issue, effective_line)
      local def_line = lines[actual] or ""
      indent    = (def_line:match("^(%s*)") or "") .. "    "
      insert_at = actual  -- 0-indexed insert = after 1-indexed line `actual`
    end

    -- Insert placeholder: indent + '''''' (cursor lands between the triple quotes)
    local placeholder = indent .. '""""""'
    vim.api.nvim_buf_set_lines(bufnr, insert_at, insert_at, false, { placeholder })

    s.placeholder_line = insert_at + 1  -- 1-indexed position in buffer
    -- Record where we inserted: 0 = module (before everything), else original pylint line
    local ins_marker = (kind == "module") and 0 or issue.line
    s.insertions[filepath] = s.insertions[filepath] or {}
    table.insert(s.insertions[filepath], ins_marker)
    s.mode              = "edit_docstring"

    -- Move focus to right panel, cursor between the quotes, enter insert mode
    vim.api.nvim_set_current_win(s.right_win)
    pcall(vim.api.nvim_win_set_cursor, s.right_win, { s.placeholder_line, #indent + 3 })
    vim.cmd("normal! zz")
    vim.cmd("startinsert")
  else
    -- Manual fix: navigate to the line, let user edit freely
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    s.mode = "edit_manual"
    vim.api.nvim_set_current_win(s.right_win)
    pcall(vim.api.nvim_win_set_cursor, s.right_win,
      { math.min(effective_line, line_count), 0 })
    vim.cmd("normal! zz")
  end
end

confirm_edit = function()
  local s = ui_state
  if not s then return end
  local issue = s.issues[s.current]
  local bufnr = s.right_buf

  clear_edit_keymaps(bufnr)

  if s.mode == "edit_docstring" and s.placeholder_line then
    -- If user left it blank, remove the placeholder line
    local line = vim.api.nvim_buf_get_lines(
      bufnr, s.placeholder_line - 1, s.placeholder_line, false
    )[1] or ""
    local text = line:match('"""(.-)"""') or ""
    if text == "" or text:match("^%s*$") then
      -- User left it blank — remove placeholder and undo the insertion marker
      vim.api.nvim_buf_set_lines(bufnr, s.placeholder_line - 1, s.placeholder_line, false, {})
      local ins = s.insertions[issue.path] or {}
      table.remove(ins)  -- remove the marker we just added
    end
    s.placeholder_line = nil
  end

  -- Save the file
  vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent! write") end)

  -- Remove resolved issue from list
  table.remove(s.issues, s.current)

  if #s.issues == 0 then
    close_ui()
    vim.notify("✓ All lint issues resolved.", vim.log.levels.INFO)
    return
  end

  s.current = math.min(s.current, #s.issues)
  s.mode    = "list"

  vim.api.nvim_set_current_win(s.left_win)
  refresh_left()
  show_in_right(s.issues[s.current])
end

cancel_edit = function()
  local s = ui_state
  if not s then return end
  local bufnr = s.right_buf

  clear_edit_keymaps(bufnr)

  if s.mode == "edit_docstring" and s.placeholder_line then
    -- Remove the placeholder we inserted
    vim.api.nvim_buf_set_lines(bufnr, s.placeholder_line - 1, s.placeholder_line, false, {})
    local issue = s.issues[s.current]
    local ins = s.insertions[issue.path] or {}
    table.remove(ins)  -- undo the insertion marker
    s.placeholder_line = nil
    vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent! write") end)
  end

  s.mode = "list"
  vim.api.nvim_set_current_win(s.left_win)
  refresh_left()
end

local function open_lint_ui(issues)
  if #issues == 0 then
    vim.notify("✓ Lint complete — no issues to review.", vim.log.levels.INFO)
    return
  end

  -- Sort by file then line — required for offset tracking to stay correct
  table.sort(issues, function(a, b)
    if a.path ~= b.path then return a.path < b.path end
    return a.line < b.line
  end)

  -- Dimensions
  local total_w = math.min(vim.o.columns - 4, 180)
  local total_h = math.min(vim.o.lines - 6, 40)
  local left_w  = math.floor(total_w * 0.35)
  local right_w = total_w - left_w - 3
  local row     = math.floor((vim.o.lines  - total_h) / 2)
  local col_l   = math.floor((vim.o.columns - total_w) / 2)
  local col_r   = col_l + left_w + 3

  -- Left panel (scratch, focused)
  local left_buf = vim.api.nvim_create_buf(false, true)
  local left_win = vim.api.nvim_open_win(left_buf, true, {
    relative  = "editor",
    row = row, col = col_l,
    width = left_w, height = total_h,
    style     = "minimal",
    border    = "rounded",
    title     = " Lint Issues ",
    title_pos = "center",
  })
  vim.wo[left_win].wrap       = false
  vim.wo[left_win].cursorline = true

  local first = issues[1]

  -- Right panel starts with a scratch buf; show_in_right will :edit the real file
  local right_init = vim.api.nvim_create_buf(false, true)
  local right_win  = vim.api.nvim_open_win(right_init, false, {
    relative  = "editor",
    row = row, col = col_r,
    width = right_w, height = total_h,
    style     = "minimal",
    border    = "rounded",
    title     = " " .. vim.fn.fnamemodify(first.path, ":t") .. " ",
    title_pos = "center",
  })

  -- Auto-close state cleanup if either window is force-closed
  local aug = vim.api.nvim_create_augroup("LintUI", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group   = aug,
    pattern = { tostring(left_win), tostring(right_win) },
    callback = function()
      vim.schedule(close_ui)
    end,
  })

  ui_state = {
    issues         = issues,
    current        = 1,
    mode           = "list",
    left_win       = left_win,
    left_buf       = left_buf,
    right_win      = right_win,
    right_buf      = right_init,
    right_file     = nil,  -- nil so show_in_right triggers :edit on first call
    insertions     = {},  -- { [filepath] = { list of original-line insertion markers } }
    placeholder_line = nil,
    close_augroup  = aug,
  }

  -- Left panel keymaps
  local lo = { buffer = left_buf, nowait = true }
  vim.keymap.set("n", "j",      function() move_selection(1)  end, lo)
  vim.keymap.set("n", "k",      function() move_selection(-1) end, lo)
  vim.keymap.set("n", "<Down>", function() move_selection(1)  end, lo)
  vim.keymap.set("n", "<Up>",   function() move_selection(-1) end, lo)
  vim.keymap.set("n", "<CR>",   enter_edit_mode,                   lo)
  vim.keymap.set("n", "q",      close_ui,                          lo)
  vim.keymap.set("n", "<Esc>",  close_ui,                          lo)

  -- Block accidental edits in the list panel
  for _, k in ipairs({ "i", "a", "o", "O", "s", "c", "d", "r", "x", "p" }) do
    vim.keymap.set("n", k, "<Nop>", lo)
  end

  -- Initial render
  refresh_left()
  show_in_right(first)
end

-- ── Main runner ────────────────────────────────────────────────────

function M.run(files, root)
  if #files == 0 then
    vim.notify("No Python files to lint.", vim.log.levels.WARN)
    return
  end

  root = root or git_root(vim.fn.fnamemodify(files[1], ":h"))

  local pylint = find_exe({ "pylint" }, root)
  local ruff   = find_exe({ "ruff" },   root)

  if not pylint then
    vim.notify("pylint not found. Install: pip install pylint", vim.log.levels.ERROR)
    return
  end

  local pylintrc = find_pylintrc(root)
  local rcflag   = pylintrc and ("--rcfile=" .. vim.fn.shellescape(pylintrc)) or ""
  local files_q  = table.concat(vim.tbl_map(vim.fn.shellescape, files), " ")

  local open_bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    open_bufs[vim.api.nvim_buf_get_name(buf)] = buf
  end

  local function reload_files(changed)
    for _, fp in ipairs(changed) do
      local buf = open_bufs[fp]
      if buf and vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_call(buf, function() vim.cmd("silent! edit!") end)
      end
    end
  end

  local function run_pylint()
    vim.notify("pylint running…", vim.log.levels.INFO)
    local out = {}
    local cmd  = string.format(
      "%s --output-format=json %s %s 2>/dev/null", pylint, rcflag, files_q)

    vim.fn.jobstart({ "sh", "-c", cmd }, {
      cwd             = root,
      stdout_buffered = true,
      on_stdout = function(_, data) if data then vim.list_extend(out, data) end end,
      on_exit   = function()
        local json = table.concat(out, "\n")
        local ok, issues = pcall(vim.json.decode, json)
        if not ok or type(issues) ~= "table" then issues = {} end

        if #issues == 0 then
          vim.notify("✓ All clean — no lint issues.", vim.log.levels.INFO)
          return
        end

        local auto, needs_input, manual = categorize(issues)

        -- Apply pylint auto-fixes
        local by_file = {}
        for _, issue in ipairs(auto) do
          by_file[issue.path] = by_file[issue.path] or {}
          table.insert(by_file[issue.path], issue)
        end
        local pylint_fixed = apply_fixes(by_file)
        reload_files(vim.tbl_keys(by_file))

        -- Combine docstring + manual into one list for the UI
        local ui_issues = {}
        vim.list_extend(ui_issues, needs_input)
        vim.list_extend(ui_issues, manual)

        local msg = string.format(
          "Auto-fixed %d  |  %d need your input",
          pylint_fixed, #ui_issues
        )
        vim.notify(msg, vim.log.levels.INFO)

        if #ui_issues > 0 then
          vim.schedule(function() open_lint_ui(ui_issues) end)
        end
      end,
    })
  end

  -- Step 1: ruff (if available)
  if ruff then
    vim.notify("ruff fixing…", vim.log.levels.INFO)
    local ruff_cmd = string.format(
      "%s check --fix --unsafe-fixes %s 2>/dev/null ; %s format %s 2>/dev/null",
      ruff, files_q, ruff, files_q
    )
    vim.fn.jobstart({ "sh", "-c", ruff_cmd }, {
      cwd     = root,
      on_exit = function()
        reload_files(files)
        vim.schedule(run_pylint)
      end,
    })
  else
    run_pylint()
  end
end

-- ── Public commands ────────────────────────────────────────────────

function M.lint_file()
  local fp = vim.api.nvim_buf_get_name(0)
  if fp == "" or not fp:match("%.py$") then
    vim.notify("Not a Python file.", vim.log.levels.WARN)
    return
  end
  vim.cmd("silent! write")
  local root = git_root(vim.fn.fnamemodify(fp, ":h"))
  M.run({ fp }, root)
end

function M.lint_project()
  local buf_path = vim.api.nvim_buf_get_name(0)
  local root = git_root(
    vim.fn.fnamemodify(buf_path ~= "" and buf_path or vim.fn.getcwd(), ":h"))

  local school = load_school_config(root)
  local files  = {}

  if school and school.files and #school.files > 0 then
    for _, f in ipairs(school.files) do
      local full = root .. "/" .. f
      if vim.fn.filereadable(full) == 1 then table.insert(files, full) end
    end
  else
    local found = vim.fn.systemlist(string.format(
      "find %s -name '*.py' -not -path '*/.venv/*' -not -path '*/__pycache__/*' -not -path '*/.git/*'",
      vim.fn.shellescape(root)
    ))
    for _, f in ipairs(found) do
      if f ~= "" then table.insert(files, f) end
    end
  end

  if #files == 0 then
    vim.notify("No Python files found.", vim.log.levels.WARN)
    return
  end

  vim.cmd("silent! wall")
  M.run(files, root)
end

-- ── Setup ──────────────────────────────────────────────────────────

function M.setup()
  vim.api.nvim_create_user_command("LintFile",    M.lint_file,    { desc = "Lint current Python file" })
  vim.api.nvim_create_user_command("LintProject", M.lint_project, { desc = "Lint all Python files in project" })

  vim.keymap.set("n", "<leader>ll", M.lint_file,    { desc = "Lint file" })
  vim.keymap.set("n", "<leader>lL", M.lint_project, { desc = "Lint project" })
end

return M
