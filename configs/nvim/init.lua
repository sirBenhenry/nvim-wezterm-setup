-- init.lua — nvim-wezterm-setup Neovim config
-- Bootstrap lazy.nvim and load all modules

-- Set leader before anything else
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load core config
require("config.options")
require("config.clipboard")

-- Load plugins via lazy.nvim
require("lazy").setup("plugins", {
  defaults = { lazy = true },
  install = { colorscheme = { "catppuccin", "cyberdream" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

-- Load keymaps, autocmds, and theme after plugins
require("config.keymaps")
require("config.autocmds")
require("config.theme").apply()
