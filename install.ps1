# install.ps1 — Windows installer for nvim-wezterm-setup
# Run from PowerShell (as Administrator recommended):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\install.ps1
#
# What this does:
#   1. Installs WezTerm terminal emulator
#   2. Installs WSL2 + Ubuntu 24.04
#   3. Clones nvim-wezterm-setup into WSL
#   4. Runs the Linux interactive installer in WSL
#   5. Deploys WezTerm config to ~\.wezterm.lua
#   6. Optionally installs the keybinding overlay (Ctrl+Alt+K)

#Requires -Version 5.1
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ── Colours ──────────────────────────────────────────────
function Write-Step   { Write-Host "==> $args" -ForegroundColor Cyan }
function Write-Ok     { Write-Host "  OK  $args" -ForegroundColor Green }
function Write-Warn   { Write-Host "  !   $args" -ForegroundColor Yellow }
function Write-Err    { Write-Host "  ERR $args" -ForegroundColor Red }
function Write-Dim    { Write-Host "      $args" -ForegroundColor DarkGray }
function Ask-Question { param($Prompt, $Default = "")
    $hint = if ($Default) { " [$Default]" } else { "" }
    Write-Host "  ?   $Prompt$hint " -ForegroundColor Yellow -NoNewline
    $ans = Read-Host
    if ($ans -eq "") { $ans = $Default }
    return $ans
}
function Confirm-Step { param($Prompt, [bool]$DefaultYes = $true)
    $hint = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    Write-Host "  ?   $Prompt $hint " -ForegroundColor Yellow -NoNewline
    $ans = Read-Host
    if ($ans -eq "") { return $DefaultYes }
    return $ans -match '^[Yy]'
}

# ── Header ───────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     nvim-wezterm-setup  ·  Windows       ║" -ForegroundColor Cyan
Write-Host "  ║     WezTerm · WSL2 · Ubuntu · Neovim     ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Dim "  This installer sets up your Windows terminal environment."
Write-Dim "  It will ask before doing anything significant."
Write-Host ""

# ── Check elevation ──────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Not running as Administrator."
    Write-Warn "Some steps (WSL install) require elevation."
    Write-Warn "Restart PowerShell as Administrator for best results."
    if (-not (Confirm-Step "Continue without admin rights?" $false)) {
        Write-Host "Aborted."; exit 0
    }
}

# ── WezTerm ──────────────────────────────────────────────
Write-Step "WezTerm"
$weztermPath = "$env:LOCALAPPDATA\Programs\WezTerm\wezterm.exe"
$weztermFound = (Test-Path $weztermPath) -or (Get-Command wezterm -ErrorAction SilentlyContinue)

if ($weztermFound) {
    Write-Ok "WezTerm already installed"
} else {
    if (Confirm-Step "Install WezTerm terminal emulator?") {
        Write-Dim "  Trying winget first..."
        $wingetOk = $false
        try {
            winget install --id wez.wezterm --accept-source-agreements --accept-package-agreements -e 2>&1 | Out-Null
            $wingetOk = $true
            Write-Ok "WezTerm installed via winget"
        } catch { $wingetOk = $false }

        if (-not $wingetOk) {
            Write-Dim "  winget failed — downloading installer directly..."
            $wt_url = "https://github.com/wez/wezterm/releases/latest/download/WezTerm-windows-installer.exe"
            $wt_tmp = "$env:TEMP\wezterm-installer.exe"
            Invoke-WebRequest -Uri $wt_url -OutFile $wt_tmp -UseBasicParsing
            Start-Process $wt_tmp -ArgumentList "/S" -Wait
            Write-Ok "WezTerm installed"
        }
    } else {
        Write-Warn "Skipping WezTerm — install it manually from https://wezfurlong.org/wezterm/"
    }
}

# ── WSL2 + Ubuntu ────────────────────────────────────────
Write-Step "WSL2 + Ubuntu 24.04"
$wslFound = $false
try {
    $wslDistros = wsl --list --quiet 2>&1
    $wslFound = ($wslDistros -match "Ubuntu")
} catch {}

if ($wslFound) {
    Write-Ok "Ubuntu WSL already installed"
} else {
    if (Confirm-Step "Install WSL2 + Ubuntu 24.04?") {
        Write-Dim "  This enables the Windows Subsystem for Linux feature and installs Ubuntu."
        Write-Dim "  A reboot may be required."
        try {
            wsl --install -d Ubuntu-24.04 2>&1
            Write-Ok "WSL + Ubuntu installation started"
            Write-Warn "If prompted to reboot, do so then re-run this installer."
        } catch {
            Write-Err "WSL install failed: $_"
            Write-Warn "Try manually: wsl --install -d Ubuntu-24.04"
        }
    } else {
        Write-Warn "Skipping WSL install. You'll need WSL with Ubuntu to continue."
    }
}

# ── WSL username ─────────────────────────────────────────
Write-Step "WSL username"
Write-Dim "  Your WSL username is the name you chose when Ubuntu first asked for one."
Write-Dim "  It's usually the same as your Windows username but lowercase."
$wslUser = Ask-Question "Your WSL username" "$env:USERNAME".ToLower()
Write-Ok "WSL username: $wslUser"

# ── Clone repo in WSL ────────────────────────────────────
Write-Step "Clone nvim-wezterm-setup into WSL"
$wslHomePath = "\\wsl.localhost\Ubuntu\home\$wslUser"
$repoWslPath = "/home/$wslUser/nvim-wezterm-setup"
$repoWinPath = "$wslHomePath\nvim-wezterm-setup"

if (Test-Path "$repoWinPath\configs") {
    Write-Ok "Repo already exists at $repoWslPath"
} else {
    $repoUrl = Ask-Question "Repo URL to clone" "https://github.com/sirBenhenry/nvim-wezterm-setup"
    Write-Dim "  Cloning into WSL home directory..."
    try {
        wsl -d Ubuntu -u $wslUser -- git clone $repoUrl $repoWslPath 2>&1
        Write-Ok "Repo cloned to $repoWslPath"
    } catch {
        Write-Err "Clone failed: $_"
        Write-Warn "Clone manually in WSL: git clone $repoUrl ~/nvim-wezterm-setup"
    }
}

# ── Run Linux installer in WSL ───────────────────────────
Write-Step "Linux installer"
Write-Dim "  Running setup/linux.sh inside WSL (interactive — you'll be asked questions)."
Write-Host ""
if (Confirm-Step "Run the Linux installer now?") {
    try {
        wsl -d Ubuntu -u $wslUser -- bash "$repoWslPath/setup/linux.sh"
        Write-Ok "Linux installer complete"
    } catch {
        Write-Warn "Linux installer exited with error. Check output above."
    }
} else {
    Write-Warn "Skipped. Run in WSL: bash ~/nvim-wezterm-setup/setup/linux.sh"
}

# ── Deploy WezTerm config ─────────────────────────────────
Write-Step "WezTerm config"
$weztermConfigSrc = "$wslHomePath\nvim-wezterm-setup\configs\wezterm.lua"
$weztermConfigDst = "$env:USERPROFILE\.wezterm.lua"

if (Test-Path $weztermConfigSrc) {
    Copy-Item $weztermConfigSrc $weztermConfigDst -Force
    Write-Ok "WezTerm config deployed to $weztermConfigDst"
} else {
    Write-Warn "Source not found: $weztermConfigSrc"
    Write-Warn "Deploy manually: copy $weztermConfigSrc $weztermConfigDst"
}

# ── Write wsl-username config file ───────────────────────
Write-Step "Config files"
$configDir = "$env:USERPROFILE\.config\nvim-wezterm-setup"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
Set-Content -Path "$configDir\wsl-username" -Value $wslUser -NoNewline
Write-Ok "Wrote $configDir\wsl-username"

# ── Keybinding overlay ───────────────────────────────────
Write-Step "Keybinding overlay (optional)"
Write-Dim "  The overlay shows a searchable keybinding cheat sheet (Ctrl+Alt+K)."
Write-Dim "  It runs as a background Windows process and starts with your session."
Write-Host ""
if (Confirm-Step "Install the keybinding overlay?" $false) {
    $overlayPs1 = "$wslHomePath\nvim-wezterm-setup\overlay\keybinds-overlay.ps1"
    $overlayVbs  = "$wslHomePath\nvim-wezterm-setup\overlay\keybinds-overlay-start.vbs"
    $startupDir  = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"

    if (Test-Path $overlayVbs) {
        Copy-Item $overlayVbs "$startupDir\keybinds-overlay.vbs" -Force
        Write-Ok "Overlay startup shortcut installed"
        Write-Dim "  It will auto-start on next login."
        Write-Dim "  To start now, double-click: $startupDir\keybinds-overlay.vbs"
        if (Confirm-Step "Start the overlay now?") {
            Start-Process "wscript.exe" -ArgumentList "`"$startupDir\keybinds-overlay.vbs`""
            Write-Ok "Overlay started — press Ctrl+Alt+K to open it"
        }
    } else {
        Write-Warn "Overlay files not found at $overlayPs1"
        Write-Warn "Make sure the repo was cloned correctly."
    }
} else {
    Write-Dim "  Skipped. To install later, copy overlay\keybinds-overlay-start.vbs to:"
    Write-Dim "  $env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\"
}

# ── Done ─────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║          Installation complete!          ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Ok "WezTerm config: $env:USERPROFILE\.wezterm.lua"
Write-Ok "WSL user:       $wslUser"
Write-Host ""
Write-Step "Next steps"
Write-Host "  1. Open WezTerm (start menu or taskbar)"
Write-Host "  2. A WSL terminal will open — Neovim and tools are ready"
Write-Host "  3. Press Ctrl+Alt+K to open the keybinding overlay (if installed)"
Write-Host "  4. Run: theme toggle    (switch between kanagawa/catppuccin)"
Write-Host "  5. Run: keys            (searchable keybinding reference)"
Write-Host ""
Write-Dim "  Health check (in WSL): bash ~/nvim-wezterm-setup/scripts/health-check.sh"
Write-Host ""
