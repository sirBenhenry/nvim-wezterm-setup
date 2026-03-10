-- venv-auto.lua — Auto-activate .venv on Python project open
-- Debounced: only checks once per directory per session

local M = {}
local checked_dirs = {}

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("venv_auto_detect", { clear = true }),
    pattern = "python",
    callback = function()
      local root = vim.fn.getcwd()
      if checked_dirs[root] then return end
      checked_dirs[root] = true

      -- Auto-activate existing .venv via venv-selector
      if vim.fn.isdirectory(root .. "/.venv") == 1 then
        vim.defer_fn(function()
          local ok, venv = pcall(require, "venv-selector")
          if ok then
            pcall(function() venv.retrieve_from_cache() end)
          end
        end, 500)
      end
    end,
  })
end

--- Manually init git + .venv in current buffer's directory
function M.project_init()
  -- Use the current buffer's parent directory, not cwd
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == "" then
    vim.notify("No file open — open a file in the project first", vim.log.levels.WARN)
    return
  end
  local root = vim.fn.fnamemodify(buf_path, ":p:h")
  vim.notify("ProjectInit in: " .. root, vim.log.levels.INFO)

  -- Git init (skip if already a repo)
  if vim.fn.isdirectory(root .. "/.git") == 0 then
    vim.fn.system({ "git", "init", root })
    -- Create .gitattributes with LF enforcement
    local f = io.open(root .. "/.gitattributes", "w")
    if f then
      f:write("* text=auto eol=lf\n")
      f:close()
    end
    -- Create .gitignore with Python defaults
    local gi = io.open(root .. "/.gitignore", "w")
    if gi then
      gi:write(".venv/\n__pycache__/\n*.pyc\n.env\n")
      gi:close()
    end
    vim.notify("git init done", vim.log.levels.INFO)
  else
    vim.notify("Already a git repo", vim.log.levels.INFO)
  end

  -- Create .venv (skip if exists)
  local venv_path = root .. "/.venv"
  if vim.fn.isdirectory(venv_path) == 1 then
    vim.notify(".venv already exists", vim.log.levels.INFO)
    return
  end

  vim.notify("Creating .venv...", vim.log.levels.INFO)
  vim.fn.jobstart({ "python3", "-m", "venv", venv_path }, {
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 then
          vim.notify("Failed to create .venv", vim.log.levels.ERROR)
          return
        end
        -- Install pylint into the new venv
        vim.fn.jobstart({ venv_path .. "/bin/pip", "install", "pylint" }, {
          on_exit = function(_, pip_code)
            vim.schedule(function()
              local msg = pip_code == 0
                and ".venv + pylint ready! Restart LSP to activate."
                or  ".venv created (pylint install failed). Restart LSP."
              vim.notify(msg, vim.log.levels.INFO)
            end)
          end,
        })
      end)
    end,
  })
end

vim.api.nvim_create_user_command("ProjectInit", function() M.project_init() end, {})

return M
