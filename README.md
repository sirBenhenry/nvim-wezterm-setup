# nvim-wezterm-setup

A terminal-first dev environment for **Windows 11 + WSL2 (Ubuntu 24.04)**.

Installs and configures:
- **WezTerm** — GPU-accelerated terminal with tab/pane support
- **Neovim 0.11+** — fully configured IDE-like editor (LSP, completion, git, file management)
- **Starship** — minimal fast shell prompt
- **zsh** — primary shell with fuzzy completion and auto-suggestions
- **Two themes** — Kanagawa and Catppuccin Macchiato, synced across every layer

---

## Installation

### Windows (recommended)

```powershell
# From PowerShell (run as Administrator for best results):
cd ~
Set-ExecutionPolicy Bypass -Scope Process -Force
git clone https://github.com/sirBenhenry/nvim-wezterm-setup
cd nvim-wezterm-setup
.\install.ps1
```

> **Note:** The `cd ~` is important — PowerShell opens in `C:\Windows\System32` by default. Running it from there clones the repo into System32, which is wrong.

The installer guides you through everything interactively. It will:
1. Install WezTerm
2. Install WSL2 + Ubuntu 24.04
3. Clone this repo into WSL
4. Run the Linux installer (install tools, create symlinks, configure git)
5. Deploy the WezTerm config
6. Optionally install the global keybinding overlay (Ctrl+Alt+K)

### Linux / WSL only

If you're already in WSL with the repo cloned:

```bash
bash setup/linux.sh
```

---

## What gets installed

| Tool | Purpose | Install method |
|------|---------|----------------|
| Neovim 0.11+ | Editor | bob (version manager) |
| lazygit | Git TUI | GitHub release |
| starship | Shell prompt | Official installer |
| eza | `ls` replacement | GitHub release |
| bat | `cat` with syntax highlighting | apt |
| fd | `find` replacement | apt (fdfind) |
| ripgrep | Fast grep | apt |
| fzf | Fuzzy finder | apt |
| zoxide | Smart `cd` | Official installer |
| yazi | Terminal file manager | GitHub release |
| win32yank | WSL clipboard bridge | GitHub release |

---

## Themes

Two themes ship out of the box:

| Theme | Description |
|-------|-------------|
| **kanagawa** | Japanese woodblock print — warm muted tones, dark navy base |
| **catppuccin** | Catppuccin Macchiato — soft pastels, clean and easy on the eyes |

**Switch theme:**

```bash
theme kanagawa
theme catppuccin
theme toggle      # flip between them
theme status      # see which is active
```

Theme is synced across Neovim, WezTerm, Starship, and FZF.

---

## Keybinding Reference

Open the searchable reference at any time:

- **Shell:** `keys` or `keys nvim` to pre-filter
- **Neovim:** `Space ?`
- **Overlay:** `Ctrl+Alt+K` (Windows, floats above all windows)

---

## WezTerm

### Tabs

| Key | Action |
|-----|--------|
| `Ctrl+Shift+T` | New WSL tab |
| `Ctrl+Shift+P` | New PowerShell tab |
| `Ctrl+Shift+Y` | Open Yazi file manager (new tab, current directory) |
| `Ctrl+1` – `Ctrl+6` | Switch to tab 1–6 |
| `Ctrl+Tab` | Next tab |
| `Ctrl+Shift+Tab` | Previous tab |

### Panes

| Key | Action |
|-----|--------|
| `Ctrl+Shift+D` | Split pane vertically (right) |
| `Ctrl+Shift+E` | Split pane horizontally (below) |
| `Ctrl+Shift+W` | Close current pane |
| `Ctrl+Shift+H/J/K/L` | Focus left / down / up / right pane |

### Clipboard

| Key | Action |
|-----|--------|
| `Ctrl+C` | Copy selection (or send Ctrl+C if no selection) |
| `Ctrl+V` | Paste |
| `Ctrl+Shift+C` | Force copy selection |
| `Ctrl+Shift+V` | Force paste |

---

## Neovim

### File Navigation

| Key | Action |
|-----|--------|
| `Space ff` | Fuzzy file search |
| `Space fg` | Live grep across project |
| `Space fb` | Switch open buffers |
| `Space fr` | Recent files |
| `Space fp` | Browse projects |
| `Space e` | Yazi file manager (current file) |
| `Space E` | Yazi file manager (project root) |
| `Shift+H / Shift+L` | Previous / next buffer |
| `Space bd` | Close buffer |
| `Space Space` | Fuzzy buffer switcher |

### Harpoon (quick file access)

| Key | Action |
|-----|--------|
| `Space ha` | Add file to Harpoon |
| `Space hm` | Open Harpoon menu |
| `Space 1–4` | Jump to Harpoon slot 1–4 |
| `Space hp / hn` | Previous / next Harpoon file |

### Windows / Splits

| Key | Action |
|-----|--------|
| `Ctrl+H/J/K/L` | Move focus between splits |
| `Space ww` | Cycle focus through splits |
| `Space sv` | Open file in new vertical split |
| `Space sh` | Open file in new horizontal split |
| `Ctrl+Arrow` | Resize splits |

### Terminals

| Key | Action |
|-----|--------|
| `Space tt` | Toggle terminal (horizontal split, linked to buffer) |
| `Space tf` | Toggle terminal (floating window) |
| `Esc Esc` | Hide terminal, return to source file |

### LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | Show all references |
| `gi` | Go to implementation |
| `K` | Hover documentation |
| `Space lr` | Rename symbol |
| `Space la` | Code actions |
| `Space ld` | Line diagnostics (float) |
| `Space lf` | Format file |

### Git (Gitsigns + Diffview)

| Key | Action |
|-----|--------|
| `Space gs` | Stage hunk |
| `Space gr` | Reset hunk |
| `Space gp` | Preview hunk diff |
| `Space gb` | Git blame line |
| `Space gv` | Open Diffview |
| `Space gc` | Close Diffview |
| `Space gh` | File git history |
| `Space gg` | Open Lazygit |
| `Space gC` | Commit with message prompt |
| `Space gP` | Push to remote |
| `Space gL` | Pull from remote |
| `Space gY` | Pull then push (sync) |
| `Space gN` | Publish new repo to GitHub |
| `]h / [h` | Next / previous hunk |
| `:GitStatus` | Git status float |
| `:GitLog` | Git log float |

### Search & Replace

| Key | Action |
|-----|--------|
| `Space /` | Search in buffer |
| `Space sr` | Project-wide search & replace (grug-far) |
| `Space fw` | Grep word under cursor |
| `Esc` | Clear search highlights |

### Flash (jump navigation)

| Key | Action |
|-----|--------|
| `s` | Jump to any visible location |
| `S` | Treesitter node selection |

### Completion

| Key | Action |
|-----|--------|
| `Tab` | Next completion item |
| `Shift+Tab` | Previous completion item |
| `Ctrl+J/K` | Navigate completion menu |
| `Enter` | Confirm completion |
| `Ctrl+E` | Dismiss menu |
| `Space ta` | Toggle between LSP completion and AI (Codeium) |

### Toggles

| Key | Action |
|-----|--------|
| `Space tv` | Toggle diagnostic virtual text |
| `Space tz` | Toggle Twilight (dim outside current block) |

### Project

| Key | Action |
|-----|--------|
| `Space pn` | New project wizard (dir + git + venv) |
| `Space pv` | Select Python venv |

### Time Tracking

| Key | Action |
|-----|--------|
| `:Stats` | Heatmap for current project |
| `:StatsAll` | Global heatmap across all projects |

### Misc

| Key | Action |
|-----|--------|
| `Ctrl+S` | Save file |
| `Space q` | Quit all |
| `Space ?` | Searchable keybinding reference |
| `Space u` | Undo tree |
| `;` | Enter command mode (replaces `:`) |

---

## Workflow: a typical session

Here's how a normal day looks using this setup:

### 1. Open WezTerm

WezTerm opens a WSL tab automatically. Your prompt shows the current directory and git branch via Starship.

### 2. Navigate to your project

```bash
z my-project          # zoxide smart cd — learns your directories
# or
prj                   # cd to your projects directory
cd my-project
```

> **Note:** `z` only works for directories you've visited before — zoxide learns from your `cd` history. On a fresh install, use `cd` normally first; `z` gets smarter over time.

### 3. Open Neovim

```bash
nvim .
```

The dashboard opens. From here:
- `Space ff` — find a file to open
- `Space fg` — search text across the whole project
- `Space fp` — browse all your projects and jump to one

### 4. Edit code

Neovim is fully set up with:
- **LSP** — type checking, go-to-definition, hover docs as you type
- **Completion** — `Tab` to cycle through completions, `Enter` to accept
- **Formatting** — `Space lf` to auto-format (prettier, black, stylua, etc.)

Use **Flash** (`s`) to jump to any visible text instantly instead of scrolling.

Use **Harpoon** to bookmark 4 files you're actively working on:
```
Space ha        → add current file
Space 1-4       → jump to slot
```

### 5. Terminal without leaving Neovim

```
Space tt        → open a terminal below the current file
Space tf        → open a floating terminal
```

The terminal is linked to your current buffer — it remembers state and stays open when toggled. Run tests, git commands, anything.

```
Esc Esc         → hide terminal, back to code
```

### 6. Git workflow

```
Space gg        → open Lazygit (full git UI)
Space gs        → stage current hunk
Space gC        → commit (type your message in a prompt)
Space gP        → push
Space gv        → Diffview (review all changes before committing)
```

### 7. Switch theme

```bash
theme toggle    # in the shell
```

Everything updates immediately — Neovim, Starship, FZF colours. WezTerm reloads automatically.

---

## Dual GitHub Accounts (optional)

If you have separate GitHub accounts (e.g. personal and work/school), the installer can set up:
- Two SSH keys with aliases (`github-primary`, `github-secondary`)
- Per-directory git identities via `~/.gitconfig` `includeIf` rules
- Neovim's `:GitPublish` command that auto-selects the right account based on your project path

This is optional — you can skip it and use a single account.

---

## File Structure

```
configs/
  nvim/                    # Symlinked to ~/.config/nvim/
  zshrc                    # Symlinked to ~/.zshrc
  bashrc                   # Symlinked to ~/.bashrc
  aliases.sh               # Symlinked to ~/.bash_aliases
  wezterm.lua              # Copied to C:\Users\<you>\.wezterm.lua
  keybindings.tsv          # Single source of truth for all keybindings
  starship-kanagawa.toml   # Starship config for kanagawa theme
  starship-catppuccin.toml # Starship config for catppuccin theme
overlay/
  keybinds-overlay.ps1     # Windows WPF keybinding overlay
  keybinds-overlay-start.vbs # Silent launcher (placed in Windows Startup)
scripts/
  theme.sh                 # Theme switcher
  keybinds.sh              # Shell keybinding picker (fzf)
  health-check.sh          # Validate the environment
setup/
  linux.sh                 # Linux/WSL interactive installer
install.ps1                # Windows interactive installer
```

---

## Health Check

After installation:

```bash
bash scripts/health-check.sh
```

This validates tools, symlinks, configs, and git setup.

---

## Uninstall

```powershell
cd ~/nvim-wezterm-setup
.\install.ps1
# choose option 2 (Uninstall)
```

This removes the Windows-side files (WezTerm config, overlay, config dir). It then prints the WSL commands to clean up inside Ubuntu.

---

## Updating

```bash
cd ~/nvim-wezterm-setup
git pull
cp configs/wezterm.lua /mnt/c/Users/<WindowsUsername>/.wezterm.lua
nvim   # then :Lazy sync for plugin updates
```
