#!/usr/bin/env bash
set -euo pipefail

# theme.sh — Switch theme across all nvim-wezterm-setup components
# Usage: theme [kanagawa|catppuccin|toggle|status]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_FILE="$HOME/.config/nvim-wezterm-setup/theme"
CONFIGS="$(dirname "$SCRIPT_DIR")/configs"

# Detect Windows home via WIN_HOME env var (set in zshrc) or guess from username
WIN_HOME="${WIN_HOME:-/mnt/c/Users/$USER}"

VALID_THEMES=(kanagawa catppuccin)

mkdir -p "$(dirname "$THEME_FILE")"

get_current() {
  cat "$THEME_FILE" 2>/dev/null || echo "kanagawa"
}

set_theme() {
  local name="$1"
  echo "$name" > "$THEME_FILE"

  # 1. Swap starship config
  local starship_src="$CONFIGS/starship-${name}.toml"
  if [ -f "$starship_src" ]; then
    ln -sf "$starship_src" "$HOME/.config/starship.toml"
  fi

  # 2. Copy WezTerm config to Windows (WezTerm auto-reloads on change)
  if [ -d "$WIN_HOME" ]; then
    cp "$CONFIGS/wezterm.lua" "$WIN_HOME/.wezterm.lua"
  fi

  # 3. Signal running Neovim instances
  local signaled=0
  for sock in "/run/user/$(id -u)/nvim.*.0" /tmp/nvim*/0 /tmp/nvim.*/0; do
    if [ -S "$sock" ] 2>/dev/null; then
      nvim --server "$sock" --remote-send \
        "<Cmd>lua require('config.theme').apply('${name}')<CR>" 2>/dev/null && signaled=$((signaled + 1)) || true
    fi
  done

  # 4. Restart overlay app (if installed)
  local overlay_ps1="$WIN_HOME/.config/keybinds/keybinds-overlay.ps1"
  if command -v pwsh.exe &>/dev/null && [ -f "$overlay_ps1" ]; then
    pwsh.exe -NoProfile -Command "Get-Process pwsh -ErrorAction SilentlyContinue | Where-Object { \$_.Id -ne \$PID } | ForEach-Object { try { Stop-Process -Id \$_.Id -Force } catch {} }" 2>/dev/null || true
    nohup pwsh.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "$(wslpath -w "$overlay_ps1")" > /dev/null 2>&1 &
  fi

  # 5. Flush terminal input buffer
  sleep 0.3
  read -r -t 0.1 -n 10000 discard 2>/dev/null || true

  # 6. Report
  echo "Theme: $name"
  [ "$signaled" -gt 0 ] && echo "Neovim: $signaled instance(s) updated"
  echo "Run 'source ~/.zshrc' or open a new tab for FZF/BAT changes."
}

case "${1:-}" in
  kanagawa)   set_theme kanagawa ;;
  catppuccin) set_theme catppuccin ;;
  toggle)
    current=$(get_current)
    case "$current" in
      kanagawa)   set_theme catppuccin ;;
      *)          set_theme kanagawa ;;
    esac
    ;;
  status) echo "Current theme: $(get_current)" ;;
  *)
    echo "Usage: theme [kanagawa|catppuccin|toggle|status]"
    exit 1
    ;;
esac
