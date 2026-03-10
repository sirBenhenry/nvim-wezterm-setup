-- lsp.lua — Mason + LSP configuration for Neovim 0.11+
return {
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup()
      -- Ensure Mason bin is on PATH so vim.lsp.enable() can find servers
      local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
      if not vim.env.PATH:find(mason_bin, 1, true) then
        vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
      end
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = { "pyright", "lua_ls", "bashls", "jsonls", "yamlls" },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = { "ruff", "stylua", "debugpy" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
    },
    config = function()
      -- LSP keymaps on attach
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_keymaps", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
          end

          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "Go to references")
          map("gi", vim.lsp.buf.implementation, "Go to implementation")
          map("K", vim.lsp.buf.hover, "Hover docs")
          map("<leader>lr", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>la", vim.lsp.buf.code_action, "Code action")
          map("<leader>ld", vim.diagnostic.open_float, "Line diagnostics")
          -- Space lf handled by conform.nvim (formatting.lua) — not mapped here
        end,
      })

      -- Capabilities (enhanced by blink.cmp if available)
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok, blink = pcall(require, "blink.cmp")
      if ok then
        capabilities = blink.get_lsp_capabilities(capabilities)
      end

      -- Use vim.lsp.config (Neovim 0.11+ native API)
      vim.lsp.config("pyright", {
        capabilities = capabilities,
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
            },
          },
        },
      })

      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
            diagnostics = { globals = { "vim" } },
          },
        },
      })

      -- Ruff: formatting only, disable diagnostics (pyright handles those)
      vim.lsp.config("ruff", {
        capabilities = capabilities,
        on_attach = function(client, _)
          client.server_capabilities.diagnosticProvider = nil
          client.server_capabilities.hoverProvider = false
        end,
      })

      vim.lsp.config("bashls", { capabilities = capabilities })
      vim.lsp.config("jsonls", { capabilities = capabilities })
      vim.lsp.config("yamlls", { capabilities = capabilities })

      -- Enable the configured servers
      vim.lsp.enable({ "pyright", "ruff", "lua_ls", "bashls", "jsonls", "yamlls" })

      -- Diagnostic appearance
      vim.diagnostic.config({
        virtual_text = false,
        underline = true,
        update_in_insert = false,
        float = { border = vim.g.border_style or "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "●",
            [vim.diagnostic.severity.WARN] = "●",
            [vim.diagnostic.severity.HINT] = "●",
            [vim.diagnostic.severity.INFO] = "●",
          },
        },
      })
    end,
  },
}
