-- completion.lua — blink.cmp (fast completion engine)
return {
  {
    "saghen/blink.cmp",
    version = "*",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    opts = {
      keymap = {
        preset = "default",
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide" },
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "snippet_forward", "select_next", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
        ["<Up>"] = { "select_prev", "fallback" },
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<C-d>"] = { "scroll_documentation_down", "fallback" },
        ["<C-u>"] = { "scroll_documentation_up", "fallback" },
      },
      cmdline = {
        enabled = true,
        keymap = {
          preset = "default",
          ["<Tab>"] = { "select_next", "fallback" },
          ["<S-Tab>"] = { "select_prev", "show", "fallback" },
          ["<CR>"] = { "accept", "fallback" },
          ["<Down>"] = { "select_next", "fallback" },
          ["<Up>"] = { "select_prev", "fallback" },
          ["<C-j>"] = { "select_next", "fallback" },
          ["<C-k>"] = { "select_prev", "fallback" },
          ["<C-e>"] = { "hide" },
        },
        completion = {
          menu = { auto_show = true },
          list = {
            selection = {
              preselect = false,
              auto_insert = true,
            },
          },
        },
      },
      appearance = {
        nerd_font_variant = "mono",
      },
      enabled = function()
        return vim.g.blink_enabled ~= false
      end,
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        menu = { border = vim.g.border_style or "rounded" },
        list = {
          selection = {
            preselect = false,
            auto_insert = true,
          },
        },
      },
      signature = { enabled = true },
    },
  },
}
