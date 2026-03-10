-- autocmds.lua — Auto commands + custom module loading

-- Load custom modules
require("custom.project-wizard")
require("custom.project-clone")
require("custom.venv-auto").setup()
require("custom.keybinds")
require("custom.git-commands")
require("custom.timetracker").setup()
require("custom.timeheatmap").setup()
require("custom.lint-runner").setup()

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- Restore cursor position on file open
autocmd("BufReadPost", {
  group = augroup("restore_cursor", { clear = true }),
  callback = function(event)
    local mark = vim.api.nvim_buf_get_mark(event.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(event.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Auto-save on focus lost / buffer leave
autocmd({ "FocusLost", "BufLeave", "QuitPre" }, {
  group = augroup("auto_save", { clear = true }),
  callback = function(event)
    local buf = event.buf
    if vim.bo[buf].modified and vim.bo[buf].buftype == "" and vim.fn.expand("%") ~= "" then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent! write")
      end)
    end
  end,
})

-- Clean up empty [No Name] buffers when opening a real file
autocmd("BufReadPost", {
  group = augroup("clean_no_name", { clear = true }),
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf)
        and vim.api.nvim_buf_get_name(buf) == ""
        and vim.bo[buf].buftype == ""
        and not vim.bo[buf].modified
        and vim.api.nvim_buf_line_count(buf) <= 1
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
      then
        vim.api.nvim_buf_delete(buf, {})
      end
    end
  end,
})

-- Timer autosave every 60 seconds
local save_timer = vim.uv.new_timer()
save_timer:start(60000, 60000, vim.schedule_wrap(function()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].modified and vim.bo[buf].buftype == "" and vim.fn.expand("%") ~= "" then
    vim.cmd("silent! write")
    vim.api.nvim_echo({ { " autosaved", "Comment" } }, false, {})
  end
end))

-- Resize splits when terminal is resized
autocmd("VimResized", {
  group = augroup("resize_splits", { clear = true }),
  command = "tabdo wincmd =",
})

-- Close some filetypes with q
autocmd("FileType", {
  group = augroup("close_with_q", { clear = true }),
  pattern = { "help", "man", "qf", "checkhealth", "lspinfo", "notify", "query" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Set indentation for specific file types
autocmd("FileType", {
  group = augroup("indent_settings", { clear = true }),
  pattern = { "lua", "json", "yaml", "html", "css", "javascript", "typescript" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
  end,
})
