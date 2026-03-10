-- keymaps.lua — Key mappings (non-plugin)

local map = vim.keymap.set

-- ── Swiss keyboard comfort ──────────────────────────────
-- ; enters command mode (: is Shift+. on Swiss QWERTZ — painful)
map("n", ";", ":", { desc = "Command mode" })
-- Space / searches in buffer (/ is Shift+7 on Swiss — painful)
-- (mapped in telescope.lua as Telescope current_buffer_fuzzy_find)

-- Fuzzy split: pick file then open in split
map("n", "<leader>sv", function()
  require("telescope.builtin").find_files({
    attach_mappings = function(_, map_t)
      map_t("i", "<CR>", function(prompt_bufnr)
        local sel = require("telescope.actions.state").get_selected_entry()
        require("telescope.actions").close(prompt_bufnr)
        if sel then vim.cmd("vsplit " .. vim.fn.fnameescape(sel.path or sel.filename)) end
      end)
      return true
    end,
  })
end, { desc = "Split vertical (fuzzy)" })

map("n", "<leader>sh", function()
  require("telescope.builtin").find_files({
    attach_mappings = function(_, map_t)
      map_t("i", "<CR>", function(prompt_bufnr)
        local sel = require("telescope.actions.state").get_selected_entry()
        require("telescope.actions").close(prompt_bufnr)
        if sel then vim.cmd("split " .. vim.fn.fnameescape(sel.path or sel.filename)) end
      end)
      return true
    end,
  })
end, { desc = "Split horizontal (fuzzy)" })

-- Window navigation: Ctrl+HJKL
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
map("n", "<leader>ww", "<C-w>w", { desc = "Cycle windows" })

-- Resize windows
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Buffer navigation (no tab bar)
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Save
map({ "n", "i", "v", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear highlights" })

-- Better indenting (stay in visual mode)
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Ctrl+C copies visual selection to system clipboard
map("v", "<C-c>", "y", { desc = "Copy to clipboard" })

-- Don't yank on paste in visual mode
map("v", "p", '"_dP', { desc = "Paste without yank" })

-- Toggle inline diagnostics (off by default, gutter signs only)
local diagnostics_visible = false
map("n", "<leader>tv", function()
  diagnostics_visible = not diagnostics_visible
  vim.diagnostic.config({ virtual_text = diagnostics_visible and { prefix = "●", spacing = 4 } or false })
  vim.notify("Inline diagnostics " .. (diagnostics_visible and "on" or "off"), vim.log.levels.INFO)
end, { desc = "Toggle inline diagnostics" })

-- Fold toggle: close containing fold, or open if on a closed fold
map("n", "<leader>tc", function()
  if vim.fn.foldclosed(vim.fn.line(".")) ~= -1 then
    vim.cmd("normal! zo")
  else
    vim.cmd("normal! zc")
  end
end, { desc = "Toggle fold (collapse)" })
map("n", "<leader>tM", "zM", { desc = "Collapse all folds" })
map("n", "<leader>tR", "zR", { desc = "Expand all folds" })

-- Quick quit
map("n", "<leader>q", "<cmd>qa<cr>", { desc = "Quit all" })

-- Terminal: double-Esc to exit terminal mode
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
