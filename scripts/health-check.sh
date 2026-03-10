#!/usr/bin/env bash
set -euo pipefail

# health-check.sh — Validate the nvim-wezterm-setup environment
# Run: bash scripts/health-check.sh

PASS=0
FAIL=0
WARN=0

check() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    printf '\033[1;32m  [PASS]\033[0m %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '\033[1;31m  [FAIL]\033[0m %s\n' "$label"
    FAIL=$((FAIL + 1))
  fi
}

check_warn() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    printf '\033[1;32m  [PASS]\033[0m %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '\033[1;33m  [WARN]\033[0m %s\n' "$label"
    WARN=$((WARN + 1))
  fi
}

echo ""
echo "═══════════════════════════════════════════════════"
echo "  nvim-wezterm-setup health check"
echo "═══════════════════════════════════════════════════"

# ── Shells ─────────────────────────────────────────────────
echo ""
echo "── Shells ──"
check "zsh available"                      command -v zsh
check_warn "PowerShell reachable from WSL" bash -c 'command -v pwsh.exe || command -v powershell.exe'

# ── CLI Tools ──────────────────────────────────────────────
echo ""
echo "── CLI Tools ──"
check "git installed"       command -v git
check "ripgrep (rg)"        command -v rg
check "fd installed"        bash -c 'command -v fd || command -v fdfind'
check "fzf installed"       command -v fzf
check "bat installed"       bash -c 'command -v bat || command -v batcat'
check "eza installed"       command -v eza
check "zoxide installed"    command -v zoxide

# ── Neovim ────────────────────────────────────────────────
echo ""
echo "── Neovim ──"
check "bob (nvim version mgr)"   command -v bob
check "neovim installed"         command -v nvim
check "neovim 0.10+"             bash -c 'nvim --version | head -1 | grep -qE "v0\.(1[0-9]|[2-9][0-9])|v[1-9]"'
check "lazygit installed"        command -v lazygit
check "nvim config exists"       test -f "$HOME/.config/nvim/init.lua"
check_warn "python3-pip"         command -v pip3
check_warn "python3-venv"        bash -c 'python3 -c "import venv" 2>/dev/null'

# ── Configs ────────────────────────────────────────────────
echo ""
echo "── Configs ──"
check "~/.zshrc is a symlink"         test -L "$HOME/.zshrc"
check "~/.bashrc is a symlink"        test -L "$HOME/.bashrc"
check "~/.bash_aliases is a symlink"  test -L "$HOME/.bash_aliases"
check "~/.config/nvim is a symlink"   test -L "$HOME/.config/nvim"
check "starship.toml exists"          test -f "$HOME/.config/starship.toml"

# WezTerm config — look for it via WIN_HOME or wsl-username file
WSLUSER_FILE="$HOME/.config/nvim-wezterm-setup/wsl-username"
if [ -f "$WSLUSER_FILE" ]; then
  WSL_USER="$(cat "$WSLUSER_FILE")"
  WIN_HOME_GUESS="/mnt/c/Users/$WSL_USER"
else
  WIN_HOME_GUESS="${WIN_HOME:-/mnt/c/Users/$USER}"
fi
check "WezTerm config deployed"  test -f "$WIN_HOME_GUESS/.wezterm.lua"

# Verify symlink targets
if [ -L "$HOME/.zshrc" ]; then
  target=$(readlink -f "$HOME/.zshrc")
  check "~/.zshrc → configs/zshrc"  bash -c "[[ '$target' == *configs/zshrc ]]"
fi
if [ -L "$HOME/.bash_aliases" ]; then
  target=$(readlink -f "$HOME/.bash_aliases")
  check "~/.bash_aliases → configs/aliases.sh"  bash -c "[[ '$target' == *configs/aliases.sh ]]"
fi

# ── Theme state ────────────────────────────────────────────
echo ""
echo "── Theme ──"
check "theme state file exists"  test -f "$HOME/.config/nvim-wezterm-setup/theme"
if [ -f "$HOME/.config/nvim-wezterm-setup/theme" ]; then
  CURRENT_THEME="$(cat "$HOME/.config/nvim-wezterm-setup/theme")"
  check "valid theme (kanagawa|catppuccin)"  bash -c '[[ "'"$CURRENT_THEME"'" =~ ^(kanagawa|catppuccin)$ ]]'
fi

# ── Git Config ─────────────────────────────────────────────
echo ""
echo "── Git Config ──"
check_warn "git user.name set"   git config --global user.name
check_warn "git user.email set"  git config --global user.email
check "core.autocrlf = input"    bash -c 'test "$(git config --global core.autocrlf)" = "input"'

# ── Cross-Environment ─────────────────────────────────────
echo ""
echo "── Cross-Environment ──"
check "win32yank reachable"  command -v win32yank.exe
check_warn "SSH key exists"  bash -c 'test -f "$HOME/.ssh/id_ed25519" || test -f "$HOME/.ssh/id_rsa"'

# ── Summary ────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
printf "  \033[1;32m%d passed\033[0m" "$PASS"
if [ "$FAIL" -gt 0 ]; then
  printf ", \033[1;31m%d failed\033[0m" "$FAIL"
fi
if [ "$WARN" -gt 0 ]; then
  printf ", \033[1;33m%d warnings\033[0m" "$WARN"
fi
echo ""
echo "═══════════════════════════════════════════════════"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
