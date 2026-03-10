-- keybinds.lua — Searchable keybinding menu (Space ?)
-- Reads from configs/keybindings.tsv and shows in Telescope

local M = {}

-- Look for keybindings.tsv next to the repo root (set via DOTFILES_DIR env var)
local DATA_FILE = vim.fn.expand(
  vim.env.DOTFILES_DIR and (vim.env.DOTFILES_DIR .. "/configs/keybindings.tsv")
  or "~/.config/nvim/keybindings.tsv"
)

local layer_icons = {
  wezterm = " WEZTERM",
  nvim = " NVIM",
  vim = " VIM",
  zsh = " ZSH",
}

function M.open()
  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("Telescope not available", vim.log.levels.ERROR)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local entry_display = require("telescope.pickers.entry_display")

  -- Parse the TSV file
  local entries = {}
  local f = io.open(DATA_FILE, "r")
  if not f then
    vim.notify("keybindings.tsv not found: " .. DATA_FILE, vim.log.levels.ERROR)
    return
  end

  for line in f:lines() do
    if line ~= "" and not line:match("^#") then
      local layer, key, desc, tags = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t?(.*)$")
      if layer and key and desc then
        table.insert(entries, {
          layer = layer,
          key = key,
          desc = desc,
          tags = tags or "",
          display_layer = layer_icons[layer] or layer,
        })
      end
    end
  end
  f:close()

  local displayer = entry_display.create({
    separator = "  ",
    items = {
      { width = 10 },
      { width = 28 },
      { remaining = true },
    },
  })

  pickers
    .new({}, {
      prompt_title = "Keybindings",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = function(e)
              return displayer({
                { e.value.display_layer, "TelescopeResultsComment" },
                { e.value.key, "TelescopeResultsIdentifier" },
                { e.value.desc },
              })
            end,
            ordinal = entry.layer .. " " .. entry.key .. " " .. entry.desc .. " " .. entry.tags,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = false,
      layout_config = {
        width = 0.8,
        height = 0.7,
      },
    })
    :find()
end

-- Register keymap
vim.keymap.set("n", "<leader>?", function()
  M.open()
end, { desc = "Keybindings menu" })

return M
