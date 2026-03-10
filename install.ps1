# install.ps1 — Windows installer for nvim-wezterm-setup
#
# INSTALL:
#   cd ~
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   git clone https://github.com/sirBenhenry/nvim-wezterm-setup
#   cd nvim-wezterm-setup
#   .\install.ps1
#
# UNINSTALL:
#   .\install.ps1 -Uninstall

param(
    [switch]$Uninstall
)

#Requires -Version 5.1
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ── Helpers ──────────────────────────────────────────────
function Write-Step { Write-Host "==> $args" -ForegroundColor Cyan }
function Write-Ok   { Write-Host "  OK  $args" -ForegroundColor Green }
function Write-Warn { Write-Host "  !   $args" -ForegroundColor Yellow }
function Write-Err  { Write-Host "  ERR $args" -ForegroundColor Red }
function Write-Dim  { Write-Host "      $args" -ForegroundColor DarkGray }
function Write-Fail { Write-Host "  FAIL $args" -ForegroundColor Red }

function Ask-Question {
    param($Prompt, $Default = "")
    $hint = if ($Default) { " [$Default]" } else { "" }
    Write-Host "  ?   $Prompt$hint " -ForegroundColor Yellow -NoNewline
    $ans = Read-Host
    if ($ans -eq "") { $ans = $Default }
    return $ans
}

function Confirm-Step {
    param($Prompt, [bool]$DefaultYes = $true)
    $hint = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    Write-Host "  ?   $Prompt $hint " -ForegroundColor Yellow -NoNewline
    $ans = Read-Host
    if ($ans -eq "") { return $DefaultYes }
    return $ans -match '^[Yy]'
}

function Stop-WithError {
    param($Message)
    Write-Host ""
    Write-Fail $Message
    Write-Host ""
    Write-Host "  Installation stopped. Fix the issue above and re-run install.ps1." -ForegroundColor Red
    Write-Host ""
    exit 1
}

# ══════════════════════════════════════════════════════════
# UNINSTALL
# ══════════════════════════════════════════════════════════
if ($Uninstall) {
    Clear-Host
    Write-Host ""
    Write-Host "  +==========================================+" -ForegroundColor Yellow
    Write-Host "  |    nvim-wezterm-setup  -  Uninstall      |" -ForegroundColor Yellow
    Write-Host "  +==========================================+" -ForegroundColor Yellow
    Write-Host ""
    Write-Warn "This will remove the Windows-side config files."
    Write-Dim  "  It does NOT remove WSL, Ubuntu, or anything installed inside WSL."
    Write-Dim  "  To clean up inside WSL, see the instructions printed at the end."
    Write-Host ""

    if (-not (Confirm-Step "Proceed with uninstall?" $false)) {
        Write-Host "Aborted."; exit 0
    }

    # Remove WezTerm config
    $weztermCfg = "$env:USERPROFILE\.wezterm.lua"
    if (Test-Path $weztermCfg) {
        Remove-Item $weztermCfg -Force
        Write-Ok "Removed $weztermCfg"
    } else {
        Write-Dim "  $weztermCfg not found, skipping"
    }

    # Remove config dir
    $configDir = "$env:USERPROFILE\.config\nvim-wezterm-setup"
    if (Test-Path $configDir) {
        Remove-Item $configDir -Recurse -Force
        Write-Ok "Removed $configDir"
    } else {
        Write-Dim "  $configDir not found, skipping"
    }

    # Remove overlay from startup
    $startupVbs = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\keybinds-overlay.vbs"
    if (Test-Path $startupVbs) {
        Remove-Item $startupVbs -Force
        Write-Ok "Removed overlay from startup"
    } else {
        Write-Dim "  Overlay shortcut not found, skipping"
    }

    # Kill overlay process if running
    Get-Process pwsh -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*keybinds-overlay*" } |
        ForEach-Object { Stop-Process -Id $_.Id -Force }

    Write-Host ""
    Write-Ok "Windows-side cleanup done."
    Write-Host ""
    Write-Step "To also clean up inside WSL, run these commands in Ubuntu:"
    Write-Host ""
    Write-Host "  rm -rf ~/nvim-wezterm-setup" -ForegroundColor White
    Write-Host "  rm ~/.zshrc ~/.bashrc ~/.bash_aliases ~/.zshrc.local" -ForegroundColor White
    Write-Host "  rm -rf ~/.config/nvim ~/.config/nvim-wezterm-setup ~/.config/starship.toml" -ForegroundColor White
    Write-Host "  rm -rf ~/.local/share/nvim-wezterm-setup" -ForegroundColor White
    Write-Host ""
    Write-Dim "  (This does not uninstall tools like nvim, lazygit, etc.)"
    Write-Host ""
    exit 0
}

# ══════════════════════════════════════════════════════════
# INSTALL
# ══════════════════════════════════════════════════════════
Clear-Host
Write-Host ""
Write-Host "  +==========================================+" -ForegroundColor Cyan
Write-Host "  |    nvim-wezterm-setup  -  Windows        |" -ForegroundColor Cyan
Write-Host "  |    WezTerm / WSL2 / Ubuntu / Neovim      |" -ForegroundColor Cyan
Write-Host "  +==========================================+" -ForegroundColor Cyan
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
$weztermFound = (Test-Path "$env:LOCALAPPDATA\Programs\WezTerm\wezterm.exe") -or
                ($null -ne (Get-Command wezterm -ErrorAction SilentlyContinue))

if ($weztermFound) {
    Write-Ok "WezTerm already installed"
} elseif (Confirm-Step "Install WezTerm terminal emulator?") {
    $wingetOk = $false
    Write-Dim "  Trying winget..."
    try {
        $result = winget install --id wez.wezterm --accept-source-agreements --accept-package-agreements -e 2>&1
        if ($LASTEXITCODE -eq 0) {
            $wingetOk = $true
            Write-Ok "WezTerm installed via winget"
        }
    } catch {}

    if (-not $wingetOk) {
        Write-Dim "  Downloading installer directly..."
        $wt_url = "https://github.com/wez/wezterm/releases/latest/download/WezTerm-windows-installer.exe"
        $wt_tmp = "$env:TEMP\wezterm-installer.exe"
        Invoke-WebRequest -Uri $wt_url -OutFile $wt_tmp -UseBasicParsing
        Start-Process $wt_tmp -ArgumentList "/S" -Wait
        Write-Ok "WezTerm installed"
    }
} else {
    Write-Warn "Skipping WezTerm - install it manually from https://wezfurlong.org/wezterm/"
}

# ── WSL2 + Ubuntu ────────────────────────────────────────
Write-Step "WSL2 + Ubuntu 24.04"

# Check if Ubuntu already works
$ubuntuReady = $false
try {
    $test = wsl -d Ubuntu -e echo "ok" 2>&1
    $ubuntuReady = ($test -match "ok")
} catch {}

if ($ubuntuReady) {
    Write-Ok "Ubuntu WSL is ready"
} elseif (Confirm-Step "Install WSL2 + Ubuntu 24.04?") {
    Write-Dim "  Installing WSL + Ubuntu..."
    wsl --install -d Ubuntu-24.04 2>&1 | ForEach-Object { Write-Dim "  $_" }

    # Check if Ubuntu works now (no reboot needed) or if we need to stop
    $ubuntuReady = $false
    try {
        $test = wsl -d Ubuntu -e echo "ok" 2>&1
        $ubuntuReady = ($test -match "ok")
    } catch {}

    if (-not $ubuntuReady) {
        Write-Host ""
        Write-Host "  +------------------------------------------+" -ForegroundColor Yellow
        Write-Host "  |         REBOOT REQUIRED                  |" -ForegroundColor Yellow
        Write-Host "  +------------------------------------------+" -ForegroundColor Yellow
        Write-Host ""
        Write-Warn "WSL was installed but needs a reboot to activate."
        Write-Host ""
        Write-Host "  After rebooting, do these steps in order:" -ForegroundColor White
        Write-Host "  1. Open 'Ubuntu' from the Start Menu" -ForegroundColor White
        Write-Host "     -> It will finish setting up and ask you to create a username" -ForegroundColor DarkGray
        Write-Host "     -> Choose a simple username with NO spaces (e.g. john)" -ForegroundColor DarkGray
        Write-Host "     -> Set a password, then close that window" -ForegroundColor DarkGray
        Write-Host "  2. Open PowerShell and run:" -ForegroundColor White
        Write-Host "     cd $PSScriptRoot" -ForegroundColor Cyan
        Write-Host "     .\install.ps1" -ForegroundColor Cyan
        Write-Host ""
        exit 0
    }

    Write-Ok "Ubuntu WSL is ready"
} else {
    Stop-WithError "WSL with Ubuntu is required to continue. Re-run when ready."
}

# ── WSL username ─────────────────────────────────────────
Write-Step "WSL username"
Write-Dim "  This is the username you created when Ubuntu first set up."
Write-Dim "  It must be lowercase with no spaces (e.g. john, not John Smith)."
Write-Host ""

$wslUser = ""
while ($true) {
    $wslUser = Ask-Question "Your WSL username" "$env:USERNAME".ToLower()

    if ($wslUser -match '\s') {
        Write-Fail "Username cannot contain spaces. WSL usernames are like: john, jane, myname"
        continue
    }
    if ($wslUser -match '[A-Z]') {
        Write-Warn "Username has uppercase letters - WSL usernames are usually all lowercase."
        if (-not (Confirm-Step "Use '$wslUser' anyway?")) { continue }
    }

    # Verify the user actually exists in WSL
    $userExists = $false
    try {
        $check = wsl -d Ubuntu -u $wslUser -e echo "ok" 2>&1
        $userExists = ($check -match "ok")
    } catch {}

    if (-not $userExists) {
        Write-Fail "User '$wslUser' not found in Ubuntu."
        Write-Warn "Open Ubuntu from the Start Menu to check your username, then try again."
        continue
    }

    break
}
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
    Write-Dim "  Cloning into WSL..."

    $cloneOutput = wsl -d Ubuntu -u $wslUser -- git clone $repoUrl $repoWslPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host $cloneOutput
        Stop-WithError "Git clone failed. Check the URL and your internet connection."
    }
    Write-Ok "Repo cloned to $repoWslPath"
}

# ── Run Linux installer in WSL ───────────────────────────
Write-Step "Linux installer"
Write-Dim "  Running setup/linux.sh inside WSL - it will ask you questions."
Write-Host ""
if (Confirm-Step "Run the Linux installer now?") {
    wsl -d Ubuntu -u $wslUser -- bash "$repoWslPath/setup/linux.sh"
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Linux installer exited with an error. Check the output above."
        Write-Warn "You can re-run it inside WSL: bash ~/nvim-wezterm-setup/setup/linux.sh"
    } else {
        Write-Ok "Linux installer complete"
    }
} else {
    Write-Warn "Skipped. Run inside WSL: bash ~/nvim-wezterm-setup/setup/linux.sh"
}

# ── Deploy WezTerm config ─────────────────────────────────
Write-Step "WezTerm config"
$weztermConfigSrc = "$wslHomePath\nvim-wezterm-setup\configs\wezterm.lua"
$weztermConfigDst = "$env:USERPROFILE\.wezterm.lua"

if (Test-Path $weztermConfigSrc) {
    Copy-Item $weztermConfigSrc $weztermConfigDst -Force
    Write-Ok "WezTerm config deployed to $weztermConfigDst"
} else {
    Write-Warn "Could not find WezTerm config at $weztermConfigSrc"
    Write-Warn "The Linux installer may not have run yet. Deploy manually later:"
    Write-Warn "  copy $weztermConfigSrc $weztermConfigDst"
}

# ── Write wsl-username config file ───────────────────────
$configDir = "$env:USERPROFILE\.config\nvim-wezterm-setup"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
Set-Content -Path "$configDir\wsl-username" -Value $wslUser -NoNewline
Write-Ok "Config written to $configDir"

# ── Keybinding overlay ───────────────────────────────────
Write-Step "Keybinding overlay (optional)"
Write-Dim "  Floating cheat sheet for all keybindings. Opens with Ctrl+Alt+K."
Write-Dim "  Runs silently in the background, starts automatically on login."
Write-Host ""
if (Confirm-Step "Install the keybinding overlay?" $false) {
    $overlayVbs = "$wslHomePath\nvim-wezterm-setup\overlay\keybinds-overlay-start.vbs"
    $startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"

    if (Test-Path $overlayVbs) {
        Copy-Item $overlayVbs "$startupDir\keybinds-overlay.vbs" -Force
        Write-Ok "Overlay will start automatically on next login"
        if (Confirm-Step "Start the overlay now?") {
            Start-Process "wscript.exe" -ArgumentList "`"$startupDir\keybinds-overlay.vbs`""
            Write-Ok "Overlay running - press Ctrl+Alt+K to open it"
        }
    } else {
        Write-Warn "Overlay files not found - make sure the Linux installer ran first."
    }
} else {
    Write-Dim "  Skipped. To install later, re-run: .\install.ps1"
}

# ── Done ─────────────────────────────────────────────────
Write-Host ""
Write-Host "  +==========================================+" -ForegroundColor Green
Write-Host "  |          Installation complete!          |" -ForegroundColor Green
Write-Host "  +==========================================+" -ForegroundColor Green
Write-Host ""
Write-Ok "WezTerm config: $env:USERPROFILE\.wezterm.lua"
Write-Ok "WSL user:       $wslUser"
Write-Host ""
Write-Step "Next steps"
Write-Host "  1. Open WezTerm from the Start Menu"
Write-Host "  2. Run: theme toggle    (switch between kanagawa/catppuccin)"
Write-Host "  3. Run: keys            (searchable keybinding reference)"
if ($null -ne (Get-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\keybinds-overlay.vbs" -ErrorAction SilentlyContinue)) {
    Write-Host "  4. Press Ctrl+Alt+K     (keybinding overlay)"
}
Write-Host ""
Write-Dim "  To uninstall: .\install.ps1 -Uninstall"
Write-Dim "  Health check (in WSL): bash ~/nvim-wezterm-setup/scripts/health-check.sh"
Write-Host ""
