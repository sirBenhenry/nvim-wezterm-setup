-- project-wizard.lua — New project creation wizard (<leader>pn)
-- Creates project in the configured PROJECTS_DIR, optionally with venv

local M = {}

-- Uses PROJECTS_DIR env var if set, otherwise defaults to ~/projects
local PROJECTS_DIR = vim.fn.expand(vim.env.PROJECTS_DIR or "~/projects")

function M.create()
  vim.ui.input({ prompt = "Project name: " }, function(name)
    if not name or name == "" then return end

    -- Sanitize name
    name = name:gsub("[^%w%-_]", "")
    if name == "" then
      vim.notify("Invalid project name", vim.log.levels.ERROR)
      return
    end

    local project_path = PROJECTS_DIR .. "/" .. name

    -- Check if already exists
    if vim.fn.isdirectory(project_path) == 1 then
      vim.notify("Project already exists: " .. project_path, vim.log.levels.WARN)
      return
    end

    -- Ask about venv
    vim.ui.select({ "Yes", "No" }, {
      prompt = "Create Python venv?",
    }, function(venv_choice)
      -- Create directory
      vim.fn.mkdir(project_path, "p")

      -- Git init
      vim.fn.system({ "git", "init", project_path })

      -- Create .gitattributes
      local gitattr = project_path .. "/.gitattributes"
      local f = io.open(gitattr, "w")
      if f then
        f:write("* text=auto eol=lf\n")
        f:close()
      end

      -- Create .gitignore with Python defaults
      local gi = io.open(project_path .. "/.gitignore", "w")
      if gi then
        gi:write(".venv/\n__pycache__/\n*.pyc\n.env\n")
        gi:close()
      end

      -- Create venv if requested
      if venv_choice == "Yes" then
        vim.notify("Creating project + venv...", vim.log.levels.INFO)
        local venv_path = project_path .. "/.venv"
        vim.fn.jobstart({ "python3", "-m", "venv", venv_path }, {
          on_exit = function(_, code)
            vim.schedule(function()
              if code ~= 0 then
                vim.notify("Project created but venv failed", vim.log.levels.WARN)
                vim.cmd("cd " .. vim.fn.fnameescape(project_path))
                vim.cmd("edit .")
                return
              end
              -- Install pylint into the new venv
              vim.fn.jobstart({ venv_path .. "/bin/pip", "install", "pylint" }, {
                on_exit = function(_, pip_code)
                  vim.schedule(function()
                    local msg = pip_code == 0
                      and "Project + venv + pylint ready: " .. name
                      or  "Project + venv ready (pylint install failed): " .. name
                    vim.notify(msg, vim.log.levels.INFO)
                    vim.cmd("cd " .. vim.fn.fnameescape(project_path))
                    vim.cmd("edit .")
                  end)
                end,
              })
            end)
          end,
        })
      else
        vim.notify("Project created: " .. name, vim.log.levels.INFO)
        vim.cmd("cd " .. vim.fn.fnameescape(project_path))
        vim.cmd("edit .")
      end
    end)
  end)
end

-- Register command + keymap
vim.api.nvim_create_user_command("ProjectNew", function() M.create() end, {})
vim.keymap.set("n", "<leader>pn", function() M.create() end, { desc = "New project" })

return M
