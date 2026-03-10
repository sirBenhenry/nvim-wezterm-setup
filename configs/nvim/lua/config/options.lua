-- options.lua — Editor settings

local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & indentation
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Appearance
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Undo & backup
opt.undofile = true
opt.swapfile = false
opt.backup = false

-- Performance
opt.updatetime = 250
opt.timeoutlen = 300

-- Completion
opt.completeopt = { "menu", "menuone", "noselect" }

-- Cursor
opt.virtualedit = "onemore"  -- allow cursor one past end of line in normal mode

-- Folding (treesitter-based, all open by default)
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true
opt.foldtext = ""  -- use native fold rendering (preserves treesitter colors)

-- Misc
opt.mouse = "a"
opt.showmode = false
opt.breakindent = true
opt.fillchars = { eob = " " }

-- Line endings
opt.fileformat = "unix"
opt.fileformats = { "unix", "dos" }
