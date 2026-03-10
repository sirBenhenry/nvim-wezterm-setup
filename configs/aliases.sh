#!/usr/bin/env bash
# aliases.sh — Shell aliases for nvim-wezterm-setup environment.
# Symlinked to ~/.bash_aliases and sourced by ~/.bashrc and ~/.zshrc.

# ── Navigation ──────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ── eza (ls replacement) ───────────────────────────────────
if command -v eza &>/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -la --icons --group-directories-first --git'
  alias la='eza -a --icons --group-directories-first'
  alias lt='eza -T --icons --level=2'
fi

# ── bat (cat replacement) ──────────────────────────────────
if command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
  alias catp='bat'
fi

# ── Git shortcuts ──────────────────────────────────────────
alias gs='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline -20'
alias gla='git log --oneline --all --graph -20'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gpull='git pull'

# ── Quick navigation ───────────────────────────────────────
alias prj='cd "${PROJECTS_DIR:-$HOME/projects}"'
alias dots='cd "${DOTFILES_DIR:-$HOME/nvim-wezterm-setup}"'

# ── Safety ─────────────────────────────────────────────────
alias rm='rm -i'
alias mv='mv -i'
alias cpi='cp -i'

# ── Python ────────────────────────────────────────────────
alias py='python3'
alias pip='pip3'

# ── Utilities ──────────────────────────────────────────────
alias reload='source ~/.zshrc'
alias path='echo $PATH | tr ":" "\n"'
alias ports='ss -tlnp'
alias keys='"${DOTFILES_DIR:-$HOME/nvim-wezterm-setup}/scripts/keybinds.sh"'
alias theme='"${DOTFILES_DIR:-$HOME/nvim-wezterm-setup}/scripts/theme.sh"'
