-- colorscheme.lua — Cyberdream (kanagawa theme) + Catppuccin (macchiato theme)
return {
  {
    "scottmckendry/cyberdream.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      transparent = false,
      italic_comments = true,
      hide_fillchars = false,
      terminal_colors = true,
      borderless_pickers = false,
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    priority = 1000,
    opts = {
      flavour = "macchiato",
      transparent_background = false,
      term_colors = true,
      no_italic = false,
      no_bold = false,
      integrations = {
        blink_cmp = true,
        gitsigns = true,
        telescope = { enabled = true },
        which_key = true,
        dashboard = true,
        diffview = true,
        mason = true,
        native_lsp = {
          enabled = true,
          virtual_text = { errors = { "italic" }, hints = { "italic" }, warnings = { "italic" }, information = { "italic" } },
          underlines = { errors = { "underline" }, hints = { "underline" }, warnings = { "underline" }, information = { "underline" } },
        },
      },
    },
  },
}
