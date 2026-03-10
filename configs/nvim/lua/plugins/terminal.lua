-- terminal.lua — Per-buffer linked persistent terminals + lazygit popup

-- src_bufnr → Terminal instance
local buf_term_map = {}
-- term_bufnr → src_bufnr (reverse lookup, set on first open)
local term_src_map = {}

-- Walk up from dir to find .venv, returns activate path or nil
local function find_venv_activate(dir)
  local d = dir
  while d and d ~= "/" do
    local activate = d .. "/.venv/bin/activate"
    if vim.fn.filereadable(activate) == 1 then return activate end
    d = vim.fn.fnamemodify(d, ":h")
  end
  return nil
end

local function hide_and_return(term, term_bufnr)
  if term:is_open() then term:toggle() end
  local src_bufnr = term_src_map[term_bufnr]
  if src_bufnr and vim.api.nvim_buf_is_valid(src_bufnr) then
    vim.api.nvim_set_current_buf(src_bufnr)
  end
end

-- Main toggle: links terminal to the current buffer
-- direction: "horizontal" (default) or "float"
local function toggle_term(direction)
  direction = direction or "horizontal"
  local Terminal = require("toggleterm.terminal").Terminal
  local cur_bufnr = vim.api.nvim_get_current_buf()

  -- If we're inside a linked terminal → hide and return to source
  if vim.bo[cur_bufnr].buftype == "terminal" then
    for _, term in pairs(buf_term_map) do
      if term.bufnr == cur_bufnr then
        hide_and_return(term, cur_bufnr)
        return
      end
    end
    -- Unregistered terminal, just hide
    vim.cmd("hide")
    return
  end

  local src_bufnr = cur_bufnr
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then dir = vim.fn.getcwd() end

  -- Terminal already exists for this buffer → switch direction if needed, then toggle
  if buf_term_map[src_bufnr] then
    local term = buf_term_map[src_bufnr]
    if term.direction ~= direction then
      if term:is_open() then term:toggle() end
      term.direction = direction
    end
    term:toggle()
    return
  end

  -- Auto-activate venv for Python files
  local venv_cmd = nil
  if vim.bo[src_bufnr].filetype == "python" then
    local activate = find_venv_activate(dir)
    if activate then venv_cmd = "source " .. vim.fn.shellescape(activate) end
  end

  -- Create new terminal linked to this buffer
  local term
  local venv_activated = false
  term = Terminal:new({
    direction = direction,
    dir = dir,
    close_on_exit = false,
    float_opts = {
      border = vim.g.border_style or "rounded",
      width = math.floor(vim.o.columns * 0.9),
      height = math.floor(vim.o.lines * 0.85),
    },
    on_open = function(t)
      -- Register reverse mapping (src file → terminal)
      term_src_map[t.bufnr] = src_bufnr

      -- Only activate venv on first open
      if venv_cmd and not venv_activated then
        venv_activated = true
        vim.api.nvim_chan_send(t.job_id, venv_cmd .. "\n")
      end

      -- Esc Esc: hide terminal and return to source file
      vim.keymap.set("t", "<Esc><Esc>", function()
        hide_and_return(term, t.bufnr)
      end, { buffer = t.bufnr, silent = true, desc = "Hide terminal, return to file" })

      -- Ctrl+W W: also hides and returns
      vim.keymap.set("t", "<C-w>w", function()
        hide_and_return(term, t.bufnr)
      end, { buffer = t.bufnr, silent = true })
    end,
    on_exit = function(t)
      -- Clean up maps when shell process exits
      vim.schedule(function()
        buf_term_map[src_bufnr] = nil
        if t.bufnr then term_src_map[t.bufnr] = nil end
      end)
    end,
  })

  buf_term_map[src_bufnr] = term
  term:toggle()
end

-- Picker: list all linked terminals and jump to one
local function list_terms()
  local items = {}
  for src_bufnr, term in pairs(buf_term_map) do
    if vim.api.nvim_buf_is_valid(src_bufnr) then
      local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(src_bufnr), ":t")
      if name == "" then name = "[No Name]" end
      table.insert(items, {
        display = name .. (term:is_open() and "  [open]" or "  [hidden]"),
        src_bufnr = src_bufnr,
        term = term,
      })
    end
  end

  if #items == 0 then
    vim.notify("No linked terminals open", vim.log.levels.INFO)
    return
  end

  vim.ui.select(items, {
    prompt = "Switch terminal:",
    format_item = function(item) return item.display end,
  }, function(choice)
    if not choice then return end
    -- Hide any currently open terminal first
    for _, t in pairs(buf_term_map) do
      if t:is_open() then t:toggle() end
    end
    -- Show chosen terminal and switch to source buffer
    vim.api.nvim_set_current_buf(choice.src_bufnr)
    choice.term:toggle()
  end)
end

return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<leader>tt", function() toggle_term("horizontal") end, desc = "Toggle linked terminal", mode = { "n", "t" } },
      { "<leader>tf", function() toggle_term("float") end,      desc = "Toggle linked terminal (float)", mode = { "n", "t" } },
      { "<leader>tl", list_terms, desc = "List terminals" },
      { "<leader>gg", function()
        local Terminal = require("toggleterm.terminal").Terminal
        local lazygit = Terminal:new({
          cmd = "lazygit",
          hidden = true,
          direction = "float",
          float_opts = {
            border = vim.g.border_style or "rounded",
            width = math.floor(vim.o.columns * 0.9),
            height = math.floor(vim.o.lines * 0.9),
          },
          on_open = function(t)
            vim.cmd("startinsert!")
            vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = t.bufnr })
          end,
        })
        lazygit:toggle()
      end, desc = "Lazygit" },
    },
    opts = {
      size = function(term)
        if term.direction == "horizontal" then return 15
        elseif term.direction == "vertical" then return vim.o.columns * 0.4
        end
      end,
      open_mapping = false,
      shade_terminals = true,
      float_opts = { border = vim.g.border_style or "rounded" },
    },
  },
}
