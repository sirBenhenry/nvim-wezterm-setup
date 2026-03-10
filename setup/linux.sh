#!/usr/bin/env bash
# setup/linux.sh — Interactive installer for nvim-wezterm-setup
# Run from inside WSL: bash setup/linux.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$HOME/.config/nvim-wezterm-setup"
STATE_DIR="$HOME/.local/share/nvim-wezterm-setup"

# ── Colours ──────────────────────────────────────────────
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_BLUE='\033[34m'
C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_DIM='\033[2m'

say()  { printf "${C_BLUE}==>${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$*"; }
ok()   { printf "${C_GREEN}  ✓${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}  !${C_RESET} %s\n" "$*"; }
err()  { printf "${C_RED}  ✗${C_RESET} %s\n" "$*" >&2; }
ask()  { printf "${C_CYAN}  ?${C_RESET} %s " "$*"; }
dim()  { printf "${C_DIM}%s${C_RESET}\n" "$*"; }

confirm() {
  local prompt="$1" default="${2:-y}"
  local yn
  if [[ "$default" == "y" ]]; then
    ask "$prompt [Y/n]"
    read -r yn; yn="${yn:-y}"
  else
    ask "$prompt [y/N]"
    read -r yn; yn="${yn:-n}"
  fi
  [[ "${yn,,}" =~ ^(y|yes)$ ]]
}

# ── Header ───────────────────────────────────────────────
clear
echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║      nvim-wezterm-setup  ·  installer    ║"
echo "  ║      Neovim · WezTerm · Starship · zsh   ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""
dim "  This script installs and configures your terminal dev environment."
dim "  It will ask before doing anything significant."
echo ""

# ── Check we're in WSL ──────────────────────────────────
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  warn "This doesn't appear to be a WSL environment."
  warn "The setup is designed for WSL2 + Ubuntu. Some steps may fail."
  confirm "Continue anyway?" n || { echo "Aborted."; exit 0; }
fi

# ── Dotfiles location ───────────────────────────────────
say "Repo location"
echo "  Detected: $REPO_DIR"
if ! confirm "Use this as your dotfiles directory?"; then
  ask "Enter the full path to the nvim-wezterm-setup repo:"
  read -r REPO_DIR
  REPO_DIR="${REPO_DIR/#\~/$HOME}"
  if [[ ! -d "$REPO_DIR" ]]; then
    err "Directory not found: $REPO_DIR"
    exit 1
  fi
fi
ok "Dotfiles dir: $REPO_DIR"

# ── WSL username (for WezTerm config) ───────────────────
say "WSL username"
dim "  WezTerm needs your WSL username to read configs across the WSL/Windows boundary."
WSL_USERNAME="$(whoami)"
echo "  Current user: $WSL_USERNAME"
if ! confirm "Is this your WSL username?"; then
  ask "Enter your WSL username:"
  read -r WSL_USERNAME
fi
ok "WSL username: $WSL_USERNAME"

# ── Theme choice ─────────────────────────────────────────
say "Theme"
echo "  1) kanagawa   — Japanese woodblock print, muted warm tones"
echo "  2) catppuccin — Catppuccin Macchiato, clean soft pastels"
ask "Choose theme [1/2, default: 1]:"
read -r THEME_CHOICE
case "${THEME_CHOICE:-1}" in
  2|catppuccin) THEME="catppuccin" ;;
  *)            THEME="kanagawa" ;;
esac
ok "Theme: $THEME"

# ── Projects directory ───────────────────────────────────
say "Projects directory"
dim "  Where do you keep your coding projects?"
DEFAULT_PROJECTS="$HOME/projects"
ask "Projects directory [$DEFAULT_PROJECTS]:"
read -r PROJECTS_DIR
PROJECTS_DIR="${PROJECTS_DIR:-$DEFAULT_PROJECTS}"
PROJECTS_DIR="${PROJECTS_DIR/#\~/$HOME}"
ok "Projects dir: $PROJECTS_DIR"

# ── Git identity ─────────────────────────────────────────
say "Git identity"
EXISTING_NAME="$(git config --global user.name 2>/dev/null || echo "")"
EXISTING_EMAIL="$(git config --global user.email 2>/dev/null || echo "")"

if [[ -n "$EXISTING_NAME" && -n "$EXISTING_EMAIL" ]]; then
  echo "  Existing git config: $EXISTING_NAME <$EXISTING_EMAIL>"
  if confirm "Keep existing git identity?"; then
    GIT_NAME="$EXISTING_NAME"
    GIT_EMAIL="$EXISTING_EMAIL"
  else
    EXISTING_NAME=""
  fi
fi

if [[ -z "$EXISTING_NAME" ]]; then
  ask "Your full name for git commits:"
  read -r GIT_NAME
  ask "Your email for git commits:"
  read -r GIT_EMAIL
fi
ok "Git identity: $GIT_NAME <$GIT_EMAIL>"

# ── Dual GitHub accounts (optional) ──────────────────────
say "Dual GitHub accounts (optional)"
echo ""
dim "  Many developers have two GitHub accounts — e.g. one personal and one"
dim "  for work or school. Git only supports one identity globally, but you"
dim "  can configure per-directory identities using SSH host aliases."
dim ""
dim "  This setup will create SSH keys for each account and configure"
dim "  ~/.ssh/config so git uses the right key automatically based on folder."
echo ""
SETUP_DUAL_GIT=false
if confirm "Set up dual GitHub account support?" n; then
  SETUP_DUAL_GIT=true

  echo ""
  say "Account 1 (primary — used for your main projects)"
  ask "GitHub username:"; read -r GIT_ACCOUNT1_USER
  ask "Directory prefix for this account [$PROJECTS_DIR]:"
  read -r GIT_ACCOUNT1_DIR
  GIT_ACCOUNT1_DIR="${GIT_ACCOUNT1_DIR:-$PROJECTS_DIR}"
  GIT_ACCOUNT1_DIR="${GIT_ACCOUNT1_DIR/#\~/$HOME}"
  ask "Email for this account:"; read -r GIT_ACCOUNT1_EMAIL

  echo ""
  say "Account 2 (secondary — e.g. work or school)"
  ask "GitHub username:"; read -r GIT_ACCOUNT2_USER
  ask "Directory prefix for this account:"
  read -r GIT_ACCOUNT2_DIR
  GIT_ACCOUNT2_DIR="${GIT_ACCOUNT2_DIR/#\~/$HOME}"
  ask "Email for this account:"; read -r GIT_ACCOUNT2_EMAIL
fi

# ── Install system packages ───────────────────────────────
say "System packages"
echo "  Packages: git, curl, wget, build-essential, ripgrep, fd-find, fzf,"
echo "            bat, eza, zoxide, zsh, python3-pip, python3-venv, unzip"
echo ""
if confirm "Install/update system packages via apt?"; then
  sudo apt-get update -qq
  sudo apt-get install -y \
    git curl wget unzip \
    build-essential \
    ripgrep fd-find \
    fzf \
    bat \
    zsh \
    python3-pip python3-venv \
    luarocks \
    2>&1 | grep -E '(Installing|Unpacking|newly installed|upgraded)' || true

  # eza — not in standard apt on Ubuntu 24.04; use official repo or cargo
  if ! command -v eza &>/dev/null; then
    warn "eza not found in apt — installing from GitHub release..."
    EZA_URL="https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
    curl -fsSL "$EZA_URL" | tar -xz -C /tmp
    sudo mv /tmp/eza /usr/local/bin/eza
  fi

  # zoxide — may not be in apt; install via script if missing
  if ! command -v zoxide &>/dev/null; then
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  fi

  # Create symlinks for Ubuntu rename (batcat → bat, fdfind → fd)
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
  fi
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi

  ok "System packages installed"
fi

# ── Install bob (Neovim version manager) + Neovim ───────
say "Neovim"
if ! command -v bob &>/dev/null; then
  echo "  Installing bob (Neovim version manager)..."
  cargo_bin="$HOME/.cargo/bin"
  if ! command -v cargo &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    export PATH="$HOME/.cargo/bin:$PATH"
  fi
  cargo install bob-nvim 2>&1 | tail -3
  export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"
fi

if ! command -v nvim &>/dev/null; then
  echo "  Installing Neovim (latest stable)..."
  bob install stable
  bob use stable
  ok "Neovim installed: $(nvim --version | head -1)"
else
  ok "Neovim already installed: $(nvim --version | head -1)"
fi

# ── Install Starship ─────────────────────────────────────
say "Starship prompt"
if ! command -v starship &>/dev/null; then
  echo "  Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y &>/dev/null
  ok "Starship installed"
else
  ok "Starship already installed"
fi

# ── Install lazygit ──────────────────────────────────────
say "Lazygit"
if ! command -v lazygit &>/dev/null; then
  echo "  Installing lazygit..."
  LG_VERSION="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | tr -d v)"
  LG_URL="https://github.com/jesseduffield/lazygit/releases/download/v${LG_VERSION}/lazygit_${LG_VERSION}_Linux_x86_64.tar.gz"
  curl -fsSL "$LG_URL" | tar -xz -C /tmp lazygit
  sudo mv /tmp/lazygit /usr/local/bin/lazygit
  ok "Lazygit installed"
else
  ok "Lazygit already installed"
fi

# ── Install yazi (optional) ──────────────────────────────
say "Yazi file manager"
dim "  Yazi is a fast terminal file manager used by Space+e in Neovim."
if confirm "Install yazi?" y; then
  if ! command -v yazi &>/dev/null; then
    echo "  Installing yazi..."
    YAZI_URL="https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip"
    curl -fsSL "$YAZI_URL" -o /tmp/yazi.zip
    unzip -q /tmp/yazi.zip -d /tmp/yazi-dl
    mkdir -p "$HOME/.local/bin"
    cp /tmp/yazi-dl/*/yazi "$HOME/.local/bin/yazi"
    rm -rf /tmp/yazi.zip /tmp/yazi-dl
    ok "Yazi installed to ~/.local/bin/yazi"
  else
    ok "Yazi already installed"
  fi
fi

# ── Install win32yank (WSL clipboard) ───────────────────
say "win32yank (WSL clipboard)"
WIN_HOME="${WIN_HOME:-/mnt/c/Users/$USER}"
WIN32YANK_DIR="$WIN_HOME/bin"
if ! command -v win32yank.exe &>/dev/null; then
  if [ -d "$WIN_HOME" ]; then
    mkdir -p "$WIN32YANK_DIR"
    W32Y_URL="https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip"
    echo "  Downloading win32yank.exe to $WIN32YANK_DIR..."
    curl -fsSL "$W32Y_URL" -o /tmp/win32yank.zip
    unzip -q -o /tmp/win32yank.zip win32yank.exe -d "$WIN32YANK_DIR"
    rm /tmp/win32yank.zip
    ok "win32yank installed to $WIN32YANK_DIR"
    warn "Add $WIN32YANK_DIR to your Windows PATH for full clipboard support."
  else
    warn "WIN_HOME ($WIN_HOME) not found — skipping win32yank."
    warn "Install it manually: https://github.com/equalsraf/win32yank"
  fi
else
  ok "win32yank already accessible"
fi

# ── Create config directories ────────────────────────────
mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$PROJECTS_DIR"

# ── Write config state files ─────────────────────────────
say "Writing config files"
echo "$WSL_USERNAME" > "$CONFIG_DIR/wsl-username"
echo "$THEME" > "$CONFIG_DIR/theme"
ok "Theme: $THEME"
ok "WSL username: $WSL_USERNAME"

# ── Create symlinks ──────────────────────────────────────
say "Creating symlinks"

symlink() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    ln -sf "$src" "$dst"
    ok "Updated: $dst → $src"
  elif [ -e "$dst" ]; then
    warn "$dst already exists (not a symlink) — backing up to ${dst}.bak"
    mv "$dst" "${dst}.bak"
    ln -sf "$src" "$dst"
    ok "Created: $dst → $src"
  else
    ln -sf "$src" "$dst"
    ok "Created: $dst → $src"
  fi
}

symlink "$REPO_DIR/configs/zshrc"    "$HOME/.zshrc"
symlink "$REPO_DIR/configs/bashrc"   "$HOME/.bashrc"
symlink "$REPO_DIR/configs/aliases.sh" "$HOME/.bash_aliases"

mkdir -p "$HOME/.config"
symlink "$REPO_DIR/configs/nvim"     "$HOME/.config/nvim"

# Starship config
case "$THEME" in
  catppuccin) ln -sf "$REPO_DIR/configs/starship-catppuccin.toml" "$HOME/.config/starship.toml" ;;
  *)          ln -sf "$REPO_DIR/configs/starship-kanagawa.toml"   "$HOME/.config/starship.toml" ;;
esac
ok "Starship config → $THEME"

# ── Set DOTFILES_DIR and PROJECTS_DIR in zshrc.local ────
say "Environment variables"
ZSHRC_LOCAL="$HOME/.zshrc.local"
{
  echo "# nvim-wezterm-setup local overrides — set by installer"
  echo "export DOTFILES_DIR=\"$REPO_DIR\""
  echo "export PROJECTS_DIR=\"$PROJECTS_DIR\""
} > "$ZSHRC_LOCAL"
ok "Wrote $ZSHRC_LOCAL"
dim "  DOTFILES_DIR=$REPO_DIR"
dim "  PROJECTS_DIR=$PROJECTS_DIR"

# Make sure zshrc sources .zshrc.local if not already
if ! grep -q 'zshrc.local' "$REPO_DIR/configs/zshrc"; then
  echo "" >> "$ZSHRC_LOCAL"
fi
# The zshrc template sources ~/.zshrc.local if it exists — nothing more needed

# ── Configure git ────────────────────────────────────────
say "Configuring git"
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global core.autocrlf input
git config --global push.default current
ok "Git: $GIT_NAME <$GIT_EMAIL>"

# ── Dual GitHub setup ────────────────────────────────────
if [[ "$SETUP_DUAL_GIT" == "true" ]]; then
  say "Setting up dual GitHub SSH accounts"

  SSH_DIR="$HOME/.ssh"
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  KEY1="$SSH_DIR/id_ed25519_${GIT_ACCOUNT1_USER}"
  KEY2="$SSH_DIR/id_ed25519_${GIT_ACCOUNT2_USER}"

  if [[ ! -f "$KEY1" ]]; then
    ssh-keygen -t ed25519 -C "$GIT_ACCOUNT1_EMAIL" -f "$KEY1" -N ""
    ok "SSH key created: $KEY1"
  else
    ok "SSH key exists: $KEY1"
  fi

  if [[ ! -f "$KEY2" ]]; then
    ssh-keygen -t ed25519 -C "$GIT_ACCOUNT2_EMAIL" -f "$KEY2" -N ""
    ok "SSH key created: $KEY2"
  else
    ok "SSH key exists: $KEY2"
  fi

  # Write ~/.ssh/config
  SSH_CONFIG="$SSH_DIR/config"
  cat >> "$SSH_CONFIG" << SSHEOF

# nvim-wezterm-setup: primary GitHub account ($GIT_ACCOUNT1_USER)
Host github-primary
    HostName github.com
    User git
    IdentityFile $KEY1

# nvim-wezterm-setup: secondary GitHub account ($GIT_ACCOUNT2_USER)
Host github-secondary
    HostName github.com
    User git
    IdentityFile $KEY2
SSHEOF
  chmod 600 "$SSH_CONFIG"
  ok "SSH config written"

  # Write per-directory gitconfigs
  ACC1_GITCONFIG="$HOME/.gitconfig-${GIT_ACCOUNT1_USER}"
  ACC2_GITCONFIG="$HOME/.gitconfig-${GIT_ACCOUNT2_USER}"

  printf '[user]\n\tname = %s\n\temail = %s\n' "$GIT_NAME" "$GIT_ACCOUNT1_EMAIL" > "$ACC1_GITCONFIG"
  printf '[user]\n\tname = %s\n\temail = %s\n' "$GIT_NAME" "$GIT_ACCOUNT2_EMAIL" > "$ACC2_GITCONFIG"

  git config --global "includeIf.gitdir:${GIT_ACCOUNT1_DIR}/.path" "$ACC1_GITCONFIG"
  git config --global "includeIf.gitdir:${GIT_ACCOUNT2_DIR}/.path" "$ACC2_GITCONFIG"
  ok "Git includeIf configured for each directory"

  # Write git-accounts.lua for :GitPublish
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_DIR/git-accounts.lua" << LUAEOF
-- git-accounts.lua — used by Neovim's :GitPublish command
-- Each entry: dir prefix, SSH host alias, GitHub username
return {
  {
    dir        = "${GIT_ACCOUNT1_DIR}",
    ssh_host   = "github-primary",
    github_user = "${GIT_ACCOUNT1_USER}",
  },
  {
    dir        = "${GIT_ACCOUNT2_DIR}",
    ssh_host   = "github-secondary",
    github_user = "${GIT_ACCOUNT2_USER}",
  },
}
LUAEOF
  ok "git-accounts.lua written to $CONFIG_DIR"

  echo ""
  warn "Action required: add your SSH public keys to GitHub."
  echo ""
  echo "  Account 1 ($GIT_ACCOUNT1_USER) — copy this key:"
  echo "  ────────────────────────────────────────────────"
  cat "${KEY1}.pub"
  echo ""
  echo "  Account 2 ($GIT_ACCOUNT2_USER) — copy this key:"
  echo "  ────────────────────────────────────────────────"
  cat "${KEY2}.pub"
  echo ""
  dim "  Add both at: https://github.com/settings/ssh/new"
  echo ""
  confirm "Press Enter once you've added the keys..." y || true
fi

# ── Deploy WezTerm config ────────────────────────────────
say "WezTerm config"
WIN_HOME="${WIN_HOME:-/mnt/c/Users/$USER}"
if [ -d "$WIN_HOME" ]; then
  cp "$REPO_DIR/configs/wezterm.lua" "$WIN_HOME/.wezterm.lua"
  ok "Deployed: $WIN_HOME/.wezterm.lua"
else
  warn "WIN_HOME ($WIN_HOME) not found — WezTerm config not deployed."
  warn "Run: cp $REPO_DIR/configs/wezterm.lua /mnt/c/Users/YourWindowsUsername/.wezterm.lua"
fi

# ── Install zsh plugins ──────────────────────────────────
say "Zsh plugins"
ZSH_PLUGINS_DIR="$HOME/.zsh"
mkdir -p "$ZSH_PLUGINS_DIR"

if [[ ! -d "$ZSH_PLUGINS_DIR/fzf-tab" ]]; then
  git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$ZSH_PLUGINS_DIR/fzf-tab" &>/dev/null
  ok "fzf-tab installed"
else
  ok "fzf-tab already installed"
fi

if [[ ! -d "$ZSH_PLUGINS_DIR/zsh-autosuggestions" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS_DIR/zsh-autosuggestions" &>/dev/null
  ok "zsh-autosuggestions installed"
else
  ok "zsh-autosuggestions already installed"
fi

if [[ ! -d "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting" &>/dev/null
  ok "zsh-syntax-highlighting installed"
else
  ok "zsh-syntax-highlighting already installed"
fi

# ── Set zsh as default shell ─────────────────────────────
if [[ "$SHELL" != "$(command -v zsh)" ]]; then
  say "Default shell"
  if confirm "Set zsh as your default shell?"; then
    chsh -s "$(command -v zsh)"
    ok "Default shell set to zsh (takes effect on next login)"
  fi
fi

# ── Sync Neovim plugins ──────────────────────────────────
say "Neovim plugins"
dim "  This will open Neovim headlessly to sync all lazy.nvim plugins."
dim "  It may take a minute on first run."
if confirm "Sync Neovim plugins now?"; then
  nvim --headless "+Lazy! sync" +qa 2>&1 | tail -5 || true
  ok "Plugin sync complete"
fi

# ── Done ─────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║          Installation complete!          ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""
ok "Theme:       $THEME"
ok "Dotfiles:    $REPO_DIR"
ok "Projects:    $PROJECTS_DIR"
ok "Git:         $GIT_NAME <$GIT_EMAIL>"
echo ""
say "Next steps"
echo "  1. Open a new terminal tab (or run: exec zsh)"
echo "  2. Open WezTerm — your config is deployed"
echo "  3. Run: nvim  (plugins will finish loading on first open)"
echo "  4. Run: theme toggle  (to try the other theme)"
echo "  5. Run: keys  (to open the keybinding reference)"
echo ""
if [[ "$SETUP_DUAL_GIT" == "true" ]]; then
  dim "  Dual git: use 'github-primary' and 'github-secondary' as SSH hosts"
  dim "  in your remote URLs, e.g.: git remote add origin git@github-primary:user/repo.git"
  echo ""
fi
dim "  Health check: bash $REPO_DIR/scripts/health-check.sh"
echo ""
