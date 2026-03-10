-- git-commands.lua — :Git* commands for common git operations
--
-- For :GitPublish to work with GitHub, create ~/.config/nvim-wezterm-setup/git-accounts.lua:
--
--   return {
--     {
--       -- Directory prefix that uses this account (e.g. "~/projects" or "~/work")
--       dir = vim.fn.expand("~/projects"),
--       -- SSH host alias (matches ~/.ssh/config Host entry)
--       -- Use "github.com" for single account, or a custom alias for multi-account
--       ssh_host = "github.com",
--       -- Your GitHub username
--       github_user = "yourusername",
--     },
--     -- Add a second entry here for a work/school account if needed
--   }
--
-- The installer will create this file for you during setup.

local M = {}

-- Walk up from buffer dir to find .git/
local function git_root()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then dir = vim.fn.getcwd() end
  while dir ~= "/" do
    if vim.fn.isdirectory(dir .. "/.git") == 1 then
      return dir
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return nil
end

-- Run a git command async, show output in notify
local function git_run(args, opts)
  opts = opts or {}
  local root = git_root()
  if not root then
    vim.notify("Not in a git repo", vim.log.levels.ERROR)
    return
  end

  local cmd = vim.list_extend({ "git", "-C", root }, args)

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_exit = function(_, code, _)
      vim.schedule(function()
        if code == 0 then
          if opts.on_success then
            opts.on_success()
          else
            vim.notify(opts.success_msg or ("git " .. args[1] .. " done"), vim.log.levels.INFO)
          end
        else
          vim.notify("git " .. args[1] .. " failed (exit " .. code .. ")", vim.log.levels.ERROR)
        end
      end)
    end,
    on_stdout = function(_, data)
      if opts.on_output and data then
        vim.schedule(function() opts.on_output(data) end)
      end
    end,
    on_stderr = function(_, data)
      if opts.on_output and data then
        vim.schedule(function() opts.on_output(data) end)
      end
    end,
  })
end

-- Show output in a floating window
local function float_output(title, lines)
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  if #lines == 0 then
    vim.notify(title .. ": nothing to show", vim.log.levels.INFO)
    return
  end

  local width = math.min(80, math.max(40, unpack(vim.tbl_map(function(l) return #l end, lines))))
  local height = math.min(20, #lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true })
end

-- :GitStatus
function M.status()
  local root = git_root()
  if not root then
    vim.notify("Not in a git repo", vim.log.levels.ERROR)
    return
  end
  local all_lines = {}
  git_run({ "status", "--short" }, {
    on_output = function(data)
      vim.list_extend(all_lines, data)
    end,
    on_success = function()
      float_output("git status", all_lines)
    end,
  })
end

-- :GitLog
function M.log()
  local root = git_root()
  if not root then
    vim.notify("Not in a git repo", vim.log.levels.ERROR)
    return
  end
  local all_lines = {}
  git_run({ "log", "--oneline", "-20" }, {
    on_output = function(data)
      vim.list_extend(all_lines, data)
    end,
    on_success = function()
      float_output("git log", all_lines)
    end,
  })
end

-- :GitCommit [msg]
function M.commit(msg)
  local function do_commit(m)
    local root = git_root()
    local status = vim.fn.system("git -C " .. root .. " status --porcelain")
    if status:match("^%s*$") then
      vim.notify("Nothing to commit — working tree clean", vim.log.levels.INFO)
      return
    end
    git_run({ "add", "-A" }, {
      success_msg = "staged all",
      on_success = function()
        git_run({ "commit", "-m", m }, {
          success_msg = "committed: " .. m,
          on_success = function()
            vim.notify("committed: " .. m, vim.log.levels.INFO)
            pcall(function() require("custom.timetracker").record_commit() end)
          end,
        })
      end,
    })
  end

  if msg and msg ~= "" then
    do_commit(msg)
  else
    vim.ui.input({ prompt = "Commit message: " }, function(input)
      if not input or input == "" then
        vim.notify("Commit cancelled", vim.log.levels.WARN)
        return
      end
      do_commit(input)
    end)
  end
end

-- :GitPush (auto sets upstream on first push)
function M.push()
  local root = git_root()
  if not root then
    vim.notify("Not in a git repo", vim.log.levels.ERROR)
    return
  end

  local upstream = vim.fn.system("git -C " .. root .. " rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null")
  local function on_push_success(msg)
    return function()
      vim.notify(msg, vim.log.levels.INFO)
      pcall(function() require("custom.timetracker").record_push() end)
    end
  end

  if vim.v.shell_error ~= 0 or upstream:match("^%s*$") then
    local branch = vim.fn.system("git -C " .. root .. " branch --show-current"):gsub("%s+", "")
    git_run({ "push", "-u", "origin", branch }, { on_success = on_push_success("pushed (set upstream)") })
  else
    git_run({ "push" }, { on_success = on_push_success("pushed") })
  end
end

-- :GitPull
function M.pull()
  git_run({ "pull" }, { success_msg = "pulled" })
end

-- :GitSync (pull then push)
function M.sync()
  git_run({ "pull" }, {
    success_msg = "pulled",
    on_success = function()
      vim.notify("Pulled. Pushing...", vim.log.levels.INFO)
      M.push()
    end,
  })
end

-- :GitPublish — create GitHub repo + push
-- Reads account config from ~/.config/nvim-wezterm-setup/git-accounts.lua
function M.publish()
  local root = git_root()
  if not root then
    vim.notify("Not in a git repo", vim.log.levels.ERROR)
    return
  end

  -- Load user's account config
  local config_file = vim.fn.expand("~/.config/nvim-wezterm-setup/git-accounts.lua")
  local accounts = {}
  if vim.fn.filereadable(config_file) == 1 then
    local ok, result = pcall(dofile, config_file)
    if ok and type(result) == "table" then
      accounts = result
    end
  end

  -- Find matching account based on directory prefix
  local matched = nil
  for _, acct in ipairs(accounts) do
    local dir = vim.fn.expand(acct.dir)
    if root:sub(1, #dir) == dir then
      matched = acct
      break
    end
  end

  -- If no match or no accounts configured, prompt
  if not matched then
    if #accounts == 0 then
      vim.notify(
        "No git accounts configured.\n" ..
        "Create ~/.config/nvim-wezterm-setup/git-accounts.lua — see :h git-commands for format.",
        vim.log.levels.WARN
      )
    else
      vim.notify("No matching account for: " .. root, vim.log.levels.WARN)
    end
    return
  end

  local name = vim.fn.fnamemodify(root, ":t")
  local remote_url = "git@" .. matched.ssh_host .. ":" .. matched.github_user .. "/" .. name .. ".git"

  vim.ui.select({ "public", "private" }, {
    prompt = "Repo visibility (" .. matched.github_user .. "/" .. name .. "):",
  }, function(visibility)
    if not visibility then return end

    vim.notify("Creating repo on GitHub...", vim.log.levels.INFO)

    local gh_cmd = {
      "gh", "repo", "create", matched.github_user .. "/" .. name,
      "--" .. visibility,
      "--source=" .. root,
    }

    local err_lines = {}
    vim.fn.jobstart(gh_cmd, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stderr = function(_, data)
        if data then vim.list_extend(err_lines, data) end
      end,
      on_exit = function(_, code)
        vim.schedule(function()
          if code == 0 then
            vim.fn.system("git -C " .. root .. " remote remove origin 2>/dev/null")
            vim.fn.system("git -C " .. root .. " remote add origin " .. remote_url)
            vim.notify("Created " .. matched.github_user .. "/" .. name .. ". Run :GitPush to push.", vim.log.levels.INFO)
          else
            local msg = table.concat(err_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
            vim.notify("gh repo create failed: " .. msg, vim.log.levels.ERROR)
          end
        end)
      end,
    })
  end)
end

-- Register commands
vim.api.nvim_create_user_command("GitStatus",  function() M.status() end, {})
vim.api.nvim_create_user_command("GitLog",     function() M.log() end, {})
vim.api.nvim_create_user_command("GitCommit",  function(opts) M.commit(opts.args) end, { nargs = "?" })
vim.api.nvim_create_user_command("GitPush",    function() M.push() end, {})
vim.api.nvim_create_user_command("GitPull",    function() M.pull() end, {})
vim.api.nvim_create_user_command("GitSync",    function() M.sync() end, {})
vim.api.nvim_create_user_command("GitPublish", function() M.publish() end, {})

return M
