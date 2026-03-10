-- project-clone.lua — :ProjectClone — clone a repo with fuzzy destination picker
-- Paste a clone URL, drill into a destination dir, auto-create venv if Python

local M = {}

-- Uses PROJECTS_DIR env var if set, otherwise defaults to ~/projects
local DEFAULT_DIR = vim.fn.expand(vim.env.PROJECTS_DIR or "~/projects")

-- Extract repo name from various URL formats
local function repo_name(url)
  local name = url:match("([%w%-_%.]+)%.git$") or url:match("/([%w%-_%.]+)$") or url:match(":([%w%-_%.]+)%.git$")
  return name
end

-- Check if cloned project has Python markers
local function has_python_markers(dir)
  local markers = { "requirements.txt", "pyproject.toml", "setup.py", "setup.cfg", "Pipfile" }
  for _, m in ipairs(markers) do
    if vim.fn.filereadable(dir .. "/" .. m) == 1 then return true end
  end
  return false
end

-- Create venv in project dir (async)
local function create_venv(project_path, name)
  vim.notify("Creating .venv...", vim.log.levels.INFO)
  vim.fn.jobstart({ "python3", "-m", "venv", project_path .. "/.venv" }, {
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 then
          vim.notify(name .. ": .venv created", vim.log.levels.INFO)
        else
          vim.notify(name .. ": venv creation failed", vim.log.levels.WARN)
        end
      end)
    end,
  })
end

-- Clone into target dir, then cd + open
local function do_clone(url, parent_dir)
  local name = repo_name(url)
  if not name then
    vim.notify("Could not parse repo name from URL", vim.log.levels.ERROR)
    return
  end

  local project_path = parent_dir .. "/" .. name

  if vim.fn.isdirectory(project_path) == 1 then
    vim.notify("Already exists: " .. project_path, vim.log.levels.WARN)
    return
  end

  vim.notify("Cloning " .. name .. "...", vim.log.levels.INFO)

  vim.fn.jobstart({ "git", "clone", url, project_path }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 then
          vim.notify("Clone failed (exit " .. code .. ")", vim.log.levels.ERROR)
          return
        end

        vim.notify("Cloned: " .. name, vim.log.levels.INFO)
        vim.cmd("cd " .. vim.fn.fnameescape(project_path))
        vim.cmd("edit .")

        -- Auto-detect Python and offer venv
        if has_python_markers(project_path) then
          vim.ui.select({ "Yes", "No" }, {
            prompt = "Python project detected. Create .venv?",
          }, function(choice)
            if choice == "Yes" then
              create_venv(project_path, name)
            end
          end)
        end
      end)
    end,
  })
end

-- Fuzzy destination picker, then clone
local function pick_destination(url)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local function get_subdirs(dir)
    local dirs = {}
    local handle = vim.loop.fs_scandir(dir)
    if not handle then return dirs end
    while true do
      local dname, typ = vim.loop.fs_scandir_next(handle)
      if not dname then break end
      if typ == "directory" and dname:sub(1, 1) ~= "." then
        table.insert(dirs, dname .. "/")
      end
    end
    table.sort(dirs)
    return dirs
  end

  local function show_picker(dir)
    local subdirs = get_subdirs(dir)
    local display = dir:gsub(vim.fn.expand("~"), "~")
    local name = repo_name(url) or "repo"

    local entries = { "[clone here] \u{2192} " .. display .. "/" .. name }
    for _, d in ipairs(subdirs) do
      table.insert(entries, d)
    end

    pickers.new({
      layout_strategy = "center",
      layout_config = { width = 0.4, anchor = "N", preview_cutoff = 1 },
    }, {
      prompt_title = "Clone to: " .. display,
      finder = finders.new_table({ results = entries }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        map("i", "<Tab>", function()
          local entry = action_state.get_selected_entry()
          if not entry then return end
          local val = entry[1]
          if val:match("^%[clone here%]") then return end
          actions.close(prompt_bufnr)
          local next_dir = dir .. "/" .. val:gsub("/$", "")
          show_picker(next_dir)
        end)

        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry then return end
          local val = entry[1]

          if val:match("^%[clone here%]") then
            do_clone(url, dir)
          else
            local target = dir .. "/" .. val:gsub("/$", "")
            do_clone(url, target)
          end
        end)

        return true
      end,
    }):find()
  end

  show_picker(DEFAULT_DIR)
end

function M.clone()
  vim.ui.input({ prompt = "Clone URL: " }, function(url)
    if not url or url == "" then return end
    url = url:match("^%s*(.-)%s*$")

    if not repo_name(url) then
      vim.notify("Could not parse repo name from URL", vim.log.levels.ERROR)
      return
    end

    pick_destination(url)
  end)
end

vim.api.nvim_create_user_command("ProjectClone", function() M.clone() end, {})

return M
