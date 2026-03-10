-- codeium.lua — AI completion (free, toggleable)
return {
  {
    "Exafunction/codeium.nvim",
    event = "InsertEnter",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("codeium").setup({
        enable_cmp_source = false,  -- we use blink.cmp, not nvim-cmp
        virtual_text = {
          enabled = true,
          key_bindings = {
            accept = "<Tab>",         -- Tab accepts (falls back to normal tab when no suggestion)
            next = "",                -- we handle cycling ourselves below
            prev = "",
            dismiss = "<C-e>",
          },
        },
      })

      -- Grey out suggestions so they don't look like real code
      vim.api.nvim_set_hl(0, "CodeiumSuggestion", { fg = "#555555", italic = true })

      -- Arrow key cycling: only when a suggestion is visible, otherwise normal cursor
      local vt = require("codeium.virtual_text")
      local function has_suggestion()
        return vt.get_current_completion_item() ~= nil
      end

      vim.keymap.set("i", "<Down>", function()
        if has_suggestion() then
          vt.cycle_completions(1)
        else
          return "<Down>"
        end
      end, { expr = true, silent = true, desc = "Codeium next / cursor down" })

      vim.keymap.set("i", "<Up>", function()
        if has_suggestion() then
          vt.cycle_completions(-1)
        else
          return "<Up>"
        end
      end, { expr = true, silent = true, desc = "Codeium prev / cursor up" })

      -- Shift+Tab also cycles (non-conditional, only useful with suggestions)
      vim.keymap.set("i", "<S-Tab>", function()
        vt.cycle_completions(1)
      end, { silent = true, desc = "Codeium next suggestion" })

      -- Toggle between Codeium mode and blink.cmp mode
      -- Space ta: Codeium on  → blink off
      --           Codeium off → blink on
      vim.g.blink_enabled = true  -- start with blink.cmp active
      vim.g.codeium_enabled = 0  -- start with Codeium off

      local function codeium_off()
        vim.g.codeium_enabled = 0
        pcall(function() require("codeium.virtual_text").clear() end)
        vim.g.blink_enabled = true
        vim.notify("blink.cmp on  |  Codeium off", vim.log.levels.INFO)
      end

      local function codeium_on()
        vim.g.codeium_enabled = 1
        vim.g.blink_enabled = false
        vim.notify("Codeium on  |  blink.cmp off", vim.log.levels.INFO)
      end

      vim.keymap.set("n", "<leader>ta", function()
        if vim.g.blink_enabled == false then
          codeium_off()
        else
          codeium_on()
        end
      end, { desc = "Toggle Codeium / blink.cmp" })
    end,
  },
}
