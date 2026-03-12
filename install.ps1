# install.ps1 — Windows installer for nvim-wezterm-setup
#
#   cd ~
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   git clone https://github.com/sirBenhenry/nvim-wezterm-setup
#   cd nvim-wezterm-setup
#   .\install.ps1

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

function Invoke-Download {
    param($Uri, $OutFile, $Label = "")
    if ($Label) { Write-Dim "  Downloading $Label..." }
    # Try BITS first (native Windows progress bar + background transfer)
    try {
        Import-Module BitsTransfer -ErrorAction Stop
        Start-BitsTransfer -Source $Uri -Destination $OutFile -DisplayName $Label -ErrorAction Stop
        return
    } catch {}
    # Fallback: Invoke-WebRequest with built-in progress
    $prev = $ProgressPreference
    $ProgressPreference = 'Continue'
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
    $ProgressPreference = $prev
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

# Find the installed Ubuntu distro name (could be "Ubuntu" or "Ubuntu-24.04")
function Get-UbuntuDistro {
    try {
        $list = wsl --list --quiet 2>&1 | ForEach-Object { "$_".Trim() }
        foreach ($name in @("Ubuntu", "Ubuntu-24.04", "Ubuntu-22.04")) {
            if ($list -contains $name) { return $name }
        }
    } catch {}
    return $null
}

# ── Mode selection ───────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  +==========================================+" -ForegroundColor Cyan
Write-Host "  |         nvim-wezterm-setup               |" -ForegroundColor Cyan
Write-Host "  |    WezTerm / WSL2 / Ubuntu / Neovim      |" -ForegroundColor Cyan
Write-Host "  +==========================================+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1) Install" -ForegroundColor White
Write-Host "  2) Uninstall" -ForegroundColor White
Write-Host ""
Write-Host "  ?   What would you like to do? [1/2] " -ForegroundColor Yellow -NoNewline
$modeChoice = Read-Host
if ($modeChoice -eq "2") { $Uninstall = $true } else { $Uninstall = $false }

# ══════════════════════════════════════════════════════════
# UNINSTALL
# ══════════════════════════════════════════════════════════
if ($Uninstall) {
    Clear-Host
    Write-Host ""
    Write-Host "  +==========================================+" -ForegroundColor Yellow
    Write-Host "  |    nvim-wezterm-setup  -  Uninstall       |" -ForegroundColor Yellow
    Write-Host "  +==========================================+" -ForegroundColor Yellow
    Write-Host ""
    Write-Warn "This will remove nvim-wezterm-setup files and configs."
    Write-Dim  "  You will be asked about each component separately."
    Write-Dim  "  Skip anything you want to keep (e.g. if you had WezTerm before this setup)."
    Write-Host ""

    if (-not (Confirm-Step "Proceed with uninstall?" $false)) {
        Write-Host "Aborted."; exit 0
    }

    # Read WSL username before we delete the config dir
    $wslUser = $null
    $wslUserFile = "$env:USERPROFILE\.config\nvim-wezterm-setup\wsl-username"
    if (Test-Path $wslUserFile) {
        $wslUser = (Get-Content $wslUserFile -Raw).Trim()
    }

    # Remove WezTerm config
    $weztermCfg = "$env:USERPROFILE\.wezterm.lua"
    if (Test-Path $weztermCfg) {
        Remove-Item $weztermCfg -Force
        Write-Ok "Removed $weztermCfg"
    } else {
        Write-Dim "  $weztermCfg not found, skipping"
    }

    # Uninstall WezTerm application
    Write-Host ""
    Write-Step "WezTerm application"
    $weztermInstalled = (Test-Path "$env:LOCALAPPDATA\Programs\WezTerm\wezterm.exe") -or
                        ($null -ne (Get-Command wezterm -ErrorAction SilentlyContinue))
    if ($weztermInstalled) {
        Write-Dim "  WezTerm is currently installed."
        Write-Dim "  Skip this if you had WezTerm before installing nvim-wezterm-setup."
        if (Confirm-Step "Uninstall WezTerm?" $false) {
            $eap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
            winget uninstall --id wez.wezterm -e 2>&1 | ForEach-Object { Write-Dim "  $_" }
            $wtExit = $LASTEXITCODE
            $ErrorActionPreference = $eap
            if ($wtExit -eq 0) {
                Write-Ok "WezTerm uninstalled"
            } else {
                Write-Warn "winget uninstall failed. Remove WezTerm manually via Settings > Apps."
            }
        } else {
            Write-Dim "  Skipped - WezTerm kept."
        }
    } else {
        Write-Dim "  WezTerm not found, nothing to uninstall."
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
    $startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $startupVbs = "$startupDir\keybinds-overlay.vbs"
    $startupPs1 = "$startupDir\keybinds-overlay.ps1"
    if (Test-Path $startupVbs) {
        Remove-Item $startupVbs -Force
        if (Test-Path $startupPs1) { Remove-Item $startupPs1 -Force }
        Write-Ok "Removed overlay from startup"
    } else {
        Write-Dim "  Overlay shortcut not found, skipping"
    }

    # Kill overlay process if running
    Get-Process pwsh -ErrorAction SilentlyContinue |
        Where-Object { try { $_.CommandLine -like "*keybinds-overlay*" } catch { $false } } |
        ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }

    Write-Host ""
    Write-Ok "Windows-side cleanup done."

    # ── WSL cleanup ──────────────────────────────────────
    Write-Host ""
    Write-Step "WSL cleanup"
    Write-Dim "  Running the WSL cleanup removes symlinks and config files inside Ubuntu."
    Write-Dim "  This does not uninstall tools like nvim, lazygit, etc."
    Write-Host ""

    if (-not $wslUser) {
        $wslUser = Ask-Question "Your WSL username (needed to clean up inside Ubuntu)"
    }

    $ubuntuDistro = Get-UbuntuDistro
    $ubuntuReady = ($null -ne $ubuntuDistro)

    if ($ubuntuReady) {
        if (Confirm-Step "Remove nvim-wezterm-setup files inside Ubuntu?") {
            $eap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
            wsl -d $ubuntuDistro -u $wslUser -- bash -c "rm -f ~/.zshrc ~/.bashrc ~/.bash_aliases ~/.zshrc.local && rm -f ~/.config/starship.toml && rm -rf ~/.config/nvim ~/.config/nvim-wezterm-setup && rm -rf ~/.local/share/nvim-wezterm-setup && rm -rf ~/nvim-wezterm-setup"
            $ErrorActionPreference = $eap
            Write-Ok "WSL files removed"
        }
    } else {
        Write-Warn "Could not reach Ubuntu WSL - clean up manually inside Ubuntu:"
        Write-Host "  rm -rf ~/nvim-wezterm-setup" -ForegroundColor White
        Write-Host "  rm ~/.zshrc ~/.bashrc ~/.bash_aliases ~/.zshrc.local" -ForegroundColor White
        Write-Host "  rm -rf ~/.config/nvim ~/.config/nvim-wezterm-setup ~/.config/starship.toml" -ForegroundColor White
        Write-Host "  rm -rf ~/.local/share/nvim-wezterm-setup" -ForegroundColor White
    }

    # ── Uninstall WSL ─────────────────────────────────────
    Write-Host ""
    Write-Step "Uninstall WSL (optional)"
    Write-Warn "This permanently deletes your Ubuntu install and all files inside it."
    Write-Dim  "  Only do this if you don't use WSL for anything else."
    Write-Host ""
    if (Confirm-Step "Uninstall Ubuntu WSL completely?" $false) {
        $distroToRemove = if ($ubuntuDistro) { $ubuntuDistro } else { "Ubuntu" }
        Write-Dim "  Unregistering $distroToRemove..."
        wsl --unregister $distroToRemove 2>&1 | ForEach-Object { Write-Dim "  $_" }
        Write-Ok "Ubuntu WSL removed"
        Write-Dim "  WSL itself (the Windows feature) is still installed."
        Write-Dim "  To remove it fully, run: wsl --uninstall"
        if (Confirm-Step "Also remove the WSL Windows feature?" $false) {
            wsl --uninstall 2>&1 | ForEach-Object { Write-Dim "  $_" }
            Write-Ok "WSL feature removed (reboot to complete)"
        }
    } else {
        Write-Dim "  Skipped - Ubuntu WSL kept."
    }

    Write-Host ""
    Write-Ok "Uninstall complete."
    Write-Host ""
    exit 0
}

# ══════════════════════════════════════════════════════════
# INSTALL
# ══════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  +==========================================+" -ForegroundColor Cyan
Write-Host "  |    nvim-wezterm-setup  -  Install         |" -ForegroundColor Cyan
Write-Host "  +==========================================+" -ForegroundColor Cyan
Write-Host ""
Write-Dim "  This installer sets up your Windows terminal environment."
Write-Dim "  It will ask before doing anything significant."
Write-Dim "  Safe to re-run at any time  -  if something gets stuck, press Ctrl+C and run it again."
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
        $wt_url = "https://github.com/wez/wezterm/releases/latest/download/WezTerm-windows-installer.exe"
        $wt_tmp = "$env:TEMP\wezterm-installer.exe"
        Invoke-Download -Uri $wt_url -OutFile $wt_tmp -Label "WezTerm installer (~25 MB)"
        Start-Process $wt_tmp -ArgumentList "/S" -Wait
        Write-Ok "WezTerm installed"
    }
} else {
    Write-Warn "Skipping WezTerm - install it manually from https://wezfurlong.org/wezterm/"
}

# ── JetBrainsMono Nerd Font ───────────────────────────────
Write-Step "JetBrainsMono Nerd Font"
$fontInstalled = (Test-Path "$env:WINDIR\Fonts\JetBrainsMonoNerdFont-Regular.ttf") -or
                 (Test-Path "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\JetBrainsMonoNerdFont-Regular.ttf")

if ($fontInstalled) {
    Write-Ok "JetBrainsMono Nerd Font already installed"
} elseif (Confirm-Step "Install JetBrainsMono Nerd Font? (required for correct display in WezTerm)") {
    $fontZip = "$env:TEMP\JetBrainsMono.zip"
    $fontDir = "$env:TEMP\JetBrainsMono-nf"
    $eap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    Invoke-Download -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -OutFile $fontZip -Label "JetBrainsMono Nerd Font (~25 MB)"
    $ErrorActionPreference = $eap
    if (-not (Test-Path $fontZip)) {
        Write-Warn "Download failed. Install JetBrainsMono Nerd Font manually from https://www.nerdfonts.com/font-downloads"
    } else {
        Write-Dim "  Installing..."
        Expand-Archive -Path $fontZip -DestinationPath $fontDir -Force
        $userFontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        New-Item -ItemType Directory -Force -Path $userFontDir | Out-Null
        $fontReg = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
        Add-Type -AssemblyName System.Drawing
        $count = 0
        Get-ChildItem "$fontDir\JetBrainsMonoNerdFont-*.ttf" | ForEach-Object {
            $dest = "$userFontDir\$($_.Name)"
            Copy-Item $_.FullName $dest -Force
            try {
                $fc = New-Object System.Drawing.Text.PrivateFontCollection
                $fc.AddFontFile($dest)
                $familyName = $fc.Families[0].Name
                # Include weight/style in key so variants don't overwrite each other
                $style = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -replace '^.*-', ''
                $regKey = if ($style -eq 'Regular') { "$familyName (TrueType)" } else { "$familyName $style (TrueType)" }
                Set-ItemProperty -Path $fontReg -Name $regKey -Value $dest -Force
            } catch {}
            $count++
        }
        Remove-Item $fontZip -Force -ErrorAction SilentlyContinue
        Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue
        # Notify running apps that fonts changed
        try {
            Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class WinFont{[DllImport("user32.dll")]public static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,IntPtr l);}' -ErrorAction SilentlyContinue
            [WinFont]::SendMessage([IntPtr]0xFFFF, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        } catch {}
        Write-Ok "Installed $count font files"
        Write-Dim "  Restart WezTerm for the font to take effect."
    }
} else {
    Write-Warn "Skipped. WezTerm will show font warnings until JetBrainsMono Nerd Font is installed."
}

# ── WSL2 + Ubuntu ────────────────────────────────────────
Write-Step "WSL2 + Ubuntu 24.04"

# Check if Ubuntu already works (handles both "Ubuntu" and "Ubuntu-24.04" distro names)
$ubuntuDistro = Get-UbuntuDistro
$ubuntuReady = ($null -ne $ubuntuDistro)

if ($ubuntuReady) {
    Write-Ok "Ubuntu WSL is ready ($ubuntuDistro)"
} elseif (Confirm-Step "Install WSL2 + Ubuntu 24.04?") {
    Write-Dim "  Note: WSL may require up to 2 reboots on a fresh system."
    Write-Dim "  After each reboot, re-run this installer  -  it will continue from where it left off."
    Write-Host ""
    Write-Dim "  Installing WSL + Ubuntu (this can take several minutes - progress shown below)..."
    Write-Host ""
    $eap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    wsl --install -d Ubuntu-24.04
    $ErrorActionPreference = $eap

    # Check if Ubuntu works now or if a reboot is needed
    $ubuntuDistro = Get-UbuntuDistro
    $ubuntuReady = ($null -ne $ubuntuDistro)

    if (-not $ubuntuReady) {
        Write-Host ""
        Write-Host "  +------------------------------------------+" -ForegroundColor Yellow
        Write-Host "  |         REBOOT REQUIRED                  |" -ForegroundColor Yellow
        Write-Host "  +------------------------------------------+" -ForegroundColor Yellow
        Write-Host ""
        Write-Warn "WSL was installed but needs a reboot to activate."
        Write-Warn "A second reboot may sometimes be needed  -  just reboot and re-run until it passes."
        Write-Host ""
        Write-Host "  After rebooting, do these steps in order:" -ForegroundColor White
        Write-Host "  1. Open 'Ubuntu' from the Start Menu" -ForegroundColor White
        Write-Host "     -> It will finish setting up and ask you to create a username" -ForegroundColor DarkGray
        Write-Host "     -> Choose a simple username with NO spaces (e.g. john)" -ForegroundColor DarkGray
        Write-Host "     -> Set a password, then close that window" -ForegroundColor DarkGray
        Write-Host "  2. Open PowerShell and run:" -ForegroundColor White
        Write-Host "     cd $PSScriptRoot" -ForegroundColor Cyan
        Write-Host "     Set-ExecutionPolicy Bypass -Scope Process -Force" -ForegroundColor Cyan
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
Write-Dim "  The value in [brackets] is pre-filled  -  press Enter to accept it."
Write-Host ""

$wslUser = ""
while ($true) {
    $wslUser = Ask-Question "Your WSL username" (("$env:USERNAME".ToLower()) -replace '\s+', '_')

    if ($wslUser -match '\s') {
        Write-Fail "Username cannot contain spaces. WSL usernames are like: john, jane, myname"
        continue
    }
    if ($wslUser -cmatch '[A-Z]') {
        Write-Warn "Username has uppercase letters - WSL usernames are usually all lowercase."
        if (-not (Confirm-Step "Use '$wslUser' anyway?")) { continue }
    }

    # Verify the user actually exists in WSL
    $userExists = $false
    try {
        $check = wsl -d $ubuntuDistro -u $wslUser -e echo "ok" 2>&1
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
$wslHomePath = "\\wsl.localhost\$ubuntuDistro\home\$wslUser"
$repoWslPath = "/home/$wslUser/nvim-wezterm-setup"
$repoWinPath = "$wslHomePath\nvim-wezterm-setup"

if (Test-Path "$repoWinPath\configs") {
    Write-Dim "  Repo exists - pulling latest changes..."
    $eap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    wsl -d $ubuntuDistro -u $wslUser -- git -C $repoWslPath pull 2>&1 | ForEach-Object { Write-Dim "  $_" }
    $ErrorActionPreference = $eap
    Write-Ok "Repo up to date at $repoWslPath"
} else {
    Write-Dim "  Press Enter to clone from the official repo, or type a different URL."
    $repoUrl = Ask-Question "Repo URL to clone" "https://github.com/sirBenhenry/nvim-wezterm-setup"
    Write-Dim "  Cloning into WSL..."

    $eap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    wsl -d $ubuntuDistro -u $wslUser -- git clone $repoUrl $repoWslPath 2>&1 | ForEach-Object { Write-Dim "  $_" }
    $ErrorActionPreference = $eap
    if (-not (Test-Path "$repoWinPath\configs")) {
        Stop-WithError "Git clone failed. Check the URL and your internet connection."
    }
    Write-Ok "Repo cloned to $repoWslPath"
}

# ── Run Linux installer in WSL ───────────────────────────
Write-Step "Linux installer"
Write-Dim "  This installs tools inside Ubuntu (neovim, starship, lazygit, etc.)."
Write-Dim "  It runs interactively and takes a few minutes  -  answer the prompts as they appear."
Write-Dim "  If it gets stuck, press Ctrl+C and re-run install.ps1  -  it will resume safely."
Write-Host ""
if (Confirm-Step "Run the Linux installer now?") {
    $eap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    wsl -d $ubuntuDistro -u $wslUser -- bash "$repoWslPath/setup/linux.sh"
    $linuxExit = $LASTEXITCODE
    $ErrorActionPreference = $eap
    if ($linuxExit -ne 0) {
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

    $overlayPs1 = "$wslHomePath\nvim-wezterm-setup\overlay\keybinds-overlay.ps1"
    if ((Test-Path $overlayVbs) -and (Test-Path $overlayPs1)) {
        Copy-Item $overlayVbs "$startupDir\keybinds-overlay.vbs" -Force
        Copy-Item $overlayPs1 "$startupDir\keybinds-overlay.ps1" -Force
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
Write-Dim "  To uninstall: re-run .\install.ps1 and choose option 2"
Write-Dim "  Health check (in WSL): bash ~/nvim-wezterm-setup/scripts/health-check.sh"
Write-Host ""
