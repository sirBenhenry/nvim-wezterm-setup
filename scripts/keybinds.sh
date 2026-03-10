#!/usr/bin/env bash
# keybinds.sh — Searchable keybinding menu using fzf
# Usage: keys [filter]
#   keys           → show all keybindings
#   keys nvim      → show only Neovim keybindings
#   keys wezterm   → show only WezTerm keybindings
#   keys copy      → search for "copy" in descriptions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_FILE="${KEYBINDS_FILE:-$(dirname "$SCRIPT_DIR")/configs/keybindings.tsv}"

if [[ ! -f "$DATA_FILE" ]]; then
  echo "Error: keybindings.tsv not found at $DATA_FILE" >&2
  exit 1
fi

# Colors for layer names (ANSI)
color_layer() {
  case "$1" in
    wezterm)   printf '\033[32m%-10s\033[0m' "WEZTERM";;
    nvim)      printf '\033[31m%-10s\033[0m' "NVIM";;
    vim)       printf '\033[91m%-10s\033[0m' "VIM";;
    zsh)       printf '\033[34m%-10s\033[0m' "ZSH";;
    *)         printf '%-10s' "$1";;
  esac
}

# Build formatted lines
# Tags (4th column) are appended invisibly so fzf searches them but they don't appear visually
format_lines() {
  while IFS=$'\t' read -r layer key desc tags; do
    [[ -z "$layer" || "$layer" == \#* ]] && continue
    local visible
    visible="$(printf '%s  \033[1m%-28s\033[0m %s' "$(color_layer "$layer")" "$key" "$desc")"
    if [[ -n "$tags" ]]; then
      printf '%s\t%s\n' "$visible" "$tags"
    else
      printf '%s\n' "$visible"
    fi
  done < "$DATA_FILE"
}

QUERY="${1:-}"

format_lines | fzf \
  --ansi \
  --query="$QUERY" \
  --prompt="Keys> " \
  --header="Search keybindings (Esc to close)" \
  --header-first \
  --layout=reverse \
  --height=80% \
  --border=rounded \
  --no-action \
  --bind="enter:abort" \
  --bind="esc:abort" || true
