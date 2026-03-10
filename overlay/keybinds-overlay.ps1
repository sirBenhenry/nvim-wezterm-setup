# keybinds-overlay.ps1 — Global keybinding overlay (Ctrl+Alt+K)
# A floating, searchable keybinding cheat sheet that hovers above all windows.

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ── Resolve WSL username → TSV path ──────────────────────
$wslUsernameFile = "$env:USERPROFILE\.config\nvim-wezterm-setup\wsl-username"
$wslUser = if (Test-Path $wslUsernameFile) { (Get-Content $wslUsernameFile -Raw).Trim() } else { $null }

$tsvPath = $null
if ($wslUser) {
    $wslTsv = "\\wsl.localhost\Ubuntu\home\$wslUser\nvim-wezterm-setup\configs\keybindings.tsv"
    if (Test-Path $wslTsv) { $tsvPath = $wslTsv }
}
if (-not $tsvPath) {
    $fallback = "$env:USERPROFILE\nvim-wezterm-setup\configs\keybindings.tsv"
    if (Test-Path $fallback) { $tsvPath = $fallback }
}
if (-not $tsvPath) {
    $fallback2 = "$env:USERPROFILE\.config\keybindings.tsv"
    if (Test-Path $fallback2) { $tsvPath = $fallback2 }
}

$allEntries = @()
if ($tsvPath -and (Test-Path $tsvPath)) {
    Get-Content $tsvPath | ForEach-Object {
        $line = $_
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line -split "`t"
            if ($parts.Count -ge 3) {
                $allEntries += [PSCustomObject]@{
                    Layer = $parts[0].Trim()
                    Key   = $parts[1].Trim()
                    Desc  = $parts[2].Trim()
                }
            }
        }
    }
}

# ── Read current theme ───────────────────────────────────
function Get-CurrentTheme {
    $paths = @()
    if ($wslUser) {
        $paths += "\\wsl.localhost\Ubuntu\home\$wslUser\.config\nvim-wezterm-setup\theme"
    }
    $paths += "$env:USERPROFILE\.config\nvim-wezterm-setup\theme"
    foreach ($p in $paths) {
        if (Test-Path $p) { return (Get-Content $p -Raw).Trim() }
    }
    return "kanagawa"
}

$currentTheme = Get-CurrentTheme

# ══════════════════════════════════════════════════════════
# Theme palettes
# ══════════════════════════════════════════════════════════
$themeData = @{
    kanagawa = @{
        Colors = @{
            Base = "#1f1f28"; Mantle = "#16161d"
            Surface0 = "#2a2a37"; Surface1 = "#363646"
            Text = "#dcd7ba"; Subtext0 = "#9cabca"
            Blue = "#7e9cd8"; Green = "#76946a"
            Mauve = "#957fb8"; Red = "#c34043"
            Yellow = "#c0a36e"; Teal = "#6a9589"
            Peach = "#ffa066"; Pink = "#d27e99"
        }
        Accent = "#7e9cd8"
        CornerR = "6"; HeaderCR = "6,6,0,0"; FooterCR = "0,0,6,6"
        SearchCR = "4"; ShadowColor = "Black"; ShadowBlur = "20"
        BorderBrush = "#363646"; BorderOpacity = "1.0"
        HeaderTitle = "KEYBINDINGS"
        BadgeCR = "3"; RowCR = "4"; BtnCR = 4; BadgeAlpha = 45
        BgGradientTop = "#1f1f28"; BgGradientBot = "#1a1a25"
        SepColor = "#2a2a37"; SepOpacity = "0.6"
        HasGlow = $false; HasCornerBrackets = $false; HasScanlines = $false
        HasBlink = $false; HasTypewriter = $false; HasAltRows = $false
        HasAccentBars = $true
        GlowColor = $null; BlinkColor = $null; BlinkLabel = $null
        TypewriterTitle = "KEYBINDINGS"
        HasOuterGlow = $false
    }
    catppuccin = @{
        Colors = @{
            Base = "#24273a"; Mantle = "#1e2030"
            Surface0 = "#363a4f"; Surface1 = "#494d64"
            Text = "#cad3f5"; Subtext0 = "#a5adcb"
            Blue = "#8aadf4"; Green = "#a6da95"
            Mauve = "#c6a0f6"; Red = "#ed8796"
            Yellow = "#eed49f"; Teal = "#8bd5ca"
            Peach = "#f5a97f"; Pink = "#f5bde6"
        }
        Accent = "#8aadf4"
        CornerR = "8"; HeaderCR = "8,8,0,0"; FooterCR = "0,0,8,8"
        SearchCR = "6"; ShadowColor = "Black"; ShadowBlur = "18"
        BorderBrush = "#494d64"; BorderOpacity = "1.0"
        HeaderTitle = "KEYBINDINGS"
        BadgeCR = "4"; RowCR = "5"; BtnCR = 5; BadgeAlpha = 45
        BgGradientTop = "#24273a"; BgGradientBot = "#1e2030"
        SepColor = "#363a4f"; SepOpacity = "0.7"
        HasGlow = $false; HasCornerBrackets = $false; HasScanlines = $false
        HasBlink = $false; HasTypewriter = $false; HasAltRows = $false
        HasAccentBars = $true
        GlowColor = $null; BlinkColor = $null; BlinkLabel = $null
        TypewriterTitle = "KEYBINDINGS"
        HasOuterGlow = $false
    }
}

$td = $themeData[$currentTheme]
if (-not $td) { $td = $themeData["kanagawa"] }

$colors = $td.Colors
$accent = $td.Accent
$cornerR = $td.CornerR; $headerCR = $td.HeaderCR; $footerCR = $td.FooterCR
$searchCR = $td.SearchCR; $shadowColor = $td.ShadowColor; $shadowBlur = $td.ShadowBlur
$borderBrush = $td.BorderBrush; $borderOpacity = $td.BorderOpacity
$headerTitle = $td.HeaderTitle
$badgeCR = $td.BadgeCR; $rowCR = $td.RowCR; $btnCR = $td.BtnCR; $badgeAlpha = $td.BadgeAlpha
$bgGradientTop = $td.BgGradientTop; $bgGradientBot = $td.BgGradientBot
$sepColor = $td.SepColor; $sepOpacity = $td.SepOpacity

$layerColors = @{
    wezterm = $colors.Green
    nvim    = $colors.Red
    vim     = $colors.Peach
    zsh     = $colors.Blue
}

$layerLabels = @{
    wezterm = "WezTerm"
    nvim    = "Neovim"
    vim     = "Vim"
    zsh     = "Zsh"
}

# ── XAML Window ──────────────────────────────────────────
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Keys" WindowStyle="None" AllowsTransparency="True"
    Background="Transparent" Topmost="True" ShowInTaskbar="False"
    WindowStartupLocation="CenterScreen" Width="780" Height="650"
    ResizeMode="NoResize" Opacity="0">
    <Border CornerRadius="$cornerR" Background="$($colors.Base)" BorderBrush="$borderBrush" BorderThickness="1">
        <Border.Effect>
            <DropShadowEffect BlurRadius="$shadowBlur" ShadowDepth="0" Opacity="0.5" Color="$shadowColor"/>
        </Border.Effect>
        <Grid Margin="0">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Header -->
            <Border Grid.Row="0" Background="$($colors.Mantle)" CornerRadius="$headerCR" Padding="16,12">
                <Grid>
                    <TextBlock Text="$headerTitle" FontFamily="Cascadia Code,Consolas,monospace" FontSize="13" FontWeight="Bold"
                               Foreground="$accent" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                    <TextBlock Text="Ctrl+Alt+K" FontFamily="Cascadia Code,Consolas,monospace" FontSize="11"
                               Foreground="$($colors.Surface1)" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                </Grid>
            </Border>

            <!-- Separator 1 -->
            <Border Grid.Row="1" Height="1" Background="$sepColor" Opacity="$sepOpacity" Margin="0,0"/>

            <!-- Search box -->
            <Border Grid.Row="2" Background="$($colors.Surface0)" Margin="12,8,12,4" CornerRadius="$searchCR" Padding="10,6">
                <Grid>
                    <TextBlock x:Name="SearchPlaceholder" Text="Type to search..."
                               FontFamily="Cascadia Code,Consolas,monospace" FontSize="13"
                               Foreground="$($colors.Surface1)" VerticalAlignment="Center" Margin="2,0,0,0"
                               IsHitTestVisible="False"/>
                    <TextBox x:Name="SearchBox" Background="Transparent" BorderThickness="0"
                             FontFamily="Cascadia Code,Consolas,monospace" FontSize="13"
                             Foreground="$($colors.Text)" CaretBrush="$accent" VerticalAlignment="Center"/>
                </Grid>
            </Border>

            <!-- Separator 2 -->
            <Border Grid.Row="3" Height="1" Background="$sepColor" Opacity="$sepOpacity" Margin="12,4,12,0"/>

            <!-- Filter buttons -->
            <WrapPanel x:Name="FilterPanel" Grid.Row="4" Margin="12,6,12,4" Orientation="Horizontal"/>

            <!-- Separator 3 -->
            <Border Grid.Row="5" Height="1" Background="$sepColor" Opacity="$sepOpacity" Margin="12,0,12,4"/>

            <!-- Column headers -->
            <Grid Grid.Row="6" Margin="20,0,20,2">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="90"/>
                    <ColumnDefinition Width="200"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="LAYER" FontFamily="Cascadia Code,Consolas,monospace" FontSize="9.5"
                           Foreground="$($colors.Surface1)" FontWeight="SemiBold" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="1" Text="KEY" FontFamily="Cascadia Code,Consolas,monospace" FontSize="9.5"
                           Foreground="$($colors.Surface1)" FontWeight="SemiBold" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="2" Text="ACTION" FontFamily="Cascadia Code,Consolas,monospace" FontSize="9.5"
                           Foreground="$($colors.Surface1)" FontWeight="SemiBold" VerticalAlignment="Center"/>
            </Grid>

            <!-- Results list -->
            <Border Grid.Row="7" Margin="12,0,12,4">
                <Border.Background>
                    <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                        <GradientStop Color="$bgGradientTop" Offset="0"/>
                        <GradientStop Color="$bgGradientBot" Offset="1"/>
                    </LinearGradientBrush>
                </Border.Background>
                <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <ScrollViewer.Resources>
                        <Style TargetType="ScrollBar">
                            <Setter Property="Width" Value="6"/>
                        </Style>
                    </ScrollViewer.Resources>
                    <StackPanel x:Name="ResultsList"/>
                </ScrollViewer>
            </Border>

            <!-- Separator 4 -->
            <Border Grid.Row="8" Height="1" Background="$sepColor" Opacity="$sepOpacity" Margin="0,0"/>

            <!-- Footer -->
            <Border Grid.Row="9" Background="$($colors.Mantle)" CornerRadius="$footerCR" Padding="16,8">
                <Grid>
                    <TextBlock x:Name="CountLabel" Text="" FontFamily="Cascadia Code,Consolas,monospace" FontSize="11"
                               Foreground="$($colors.Surface1)" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                    <TextBlock Text="Esc close  Tab filter" FontFamily="Cascadia Code,Consolas,monospace" FontSize="11"
                               Foreground="$($colors.Surface1)" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
"@

# ── Create Window ────────────────────────────────────────
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$searchBox        = $window.FindName("SearchBox")
$searchPlaceholder = $window.FindName("SearchPlaceholder")
$resultsList      = $window.FindName("ResultsList")
$countLabel       = $window.FindName("CountLabel")
$filterPanel      = $window.FindName("FilterPanel")

# ── Fade-in animation ───────────────────────────────────
$script:fadeInStoryboard = New-Object System.Windows.Media.Animation.Storyboard
$fadeAnim = New-Object System.Windows.Media.Animation.DoubleAnimation
$fadeAnim.From = 0.0; $fadeAnim.To = 1.0
$fadeAnim.Duration = [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(180))
$fadeAnim.EasingFunction = New-Object System.Windows.Media.Animation.QuadraticEase
$fadeAnim.EasingFunction.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
[void][System.Windows.Media.Animation.Storyboard]::SetTarget($fadeAnim, $window)
[void][System.Windows.Media.Animation.Storyboard]::SetTargetProperty($fadeAnim, (New-Object System.Windows.PropertyPath("Opacity")))
[void]$script:fadeInStoryboard.Children.Add($fadeAnim)

# ── Build filter buttons ────────────────────────────────
$script:filterButtons = @{}

function Set-ActiveFilter {
    param($layer)
    $script:currentLayerFilter = $layer
    foreach ($key in $script:filterButtons.Keys) {
        $btn = $script:filterButtons[$key]
        $lc = $layerColors[$key]
        if (-not $lc) { $lc = $colors.Subtext0 }
        if ($key -eq $layer) {
            $btn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom($lc)
            $btn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($colors.Base)
            $btn.Opacity = 1.0
        } else {
            $btn.Background = [System.Windows.Media.Brushes]::Transparent
            $btn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($lc)
            $btn.Opacity = 0.6
        }
    }
    $allBtn = $script:filterButtons["_all"]
    if ($allBtn) {
        if ($layer -eq "") {
            $allBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom($accent)
            $allBtn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($colors.Base)
            $allBtn.Opacity = 1.0
        } else {
            $allBtn.Background = [System.Windows.Media.Brushes]::Transparent
            $allBtn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($colors.Subtext0)
            $allBtn.Opacity = 0.6
        }
    }
    Update-Results -query $searchBox.Text
}

$uniqueLayers = @("_all") + ($allEntries | ForEach-Object { $_.Layer } | Select-Object -Unique)

foreach ($layer in $uniqueLayers) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.FontFamily = New-Object System.Windows.Media.FontFamily("Cascadia Code,Consolas,monospace")
    $btn.FontSize = 10.5; $btn.FontWeight = "SemiBold"
    $btn.Padding = "8,3"; $btn.Margin = "0,0,4,0"
    $btn.Cursor = [System.Windows.Input.Cursors]::Hand
    $btn.BorderThickness = "1"

    $tpl = New-Object System.Windows.Controls.ControlTemplate([System.Windows.Controls.Button])
    $borderFactory = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.Border])
    $borderFactory.SetValue([System.Windows.Controls.Border]::CornerRadiusProperty, [System.Windows.CornerRadius]::new($btnCR))
    $borderFactory.SetValue([System.Windows.Controls.Border]::PaddingProperty, [System.Windows.Thickness]::new(8,3,8,3))
    $borderFactory.SetBinding([System.Windows.Controls.Border]::BackgroundProperty,
        (New-Object System.Windows.Data.Binding("Background") -Property @{
            RelativeSource = [System.Windows.Data.RelativeSource]::TemplatedParent }))
    $presenterFactory = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.ContentPresenter])
    $presenterFactory.SetValue([System.Windows.Controls.ContentPresenter]::HorizontalAlignmentProperty,
        [System.Windows.HorizontalAlignment]::Center)
    $borderFactory.AppendChild($presenterFactory)
    $tpl.VisualTree = $borderFactory
    $btn.Template = $tpl

    if ($layer -eq "_all") {
        $btn.Content = "All"
        $btn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom($accent)
        $btn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($colors.Base)
        $btn.Tag = ""
    } else {
        $lbl = $layerLabels[$layer]; if (-not $lbl) { $lbl = $layer }
        $btn.Content = $lbl
        $lc = $layerColors[$layer]; if (-not $lc) { $lc = $colors.Subtext0 }
        $btn.Background = [System.Windows.Media.Brushes]::Transparent
        $btn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($lc)
        $btn.Opacity = 0.6
        $btn.Tag = $layer
    }

    $btn.Add_Click({ param($sender, $e); Set-ActiveFilter -layer $sender.Tag }.GetNewClosure())
    [void]$filterPanel.Children.Add($btn)
    $script:filterButtons[$layer] = $btn
}

# ── Helper: create a result row ──────────────────────────
$hoverBrush = $c = [System.Windows.Media.BrushConverter]::new().ConvertFrom($colors.Surface0).Color
$hoverBrush = New-Object System.Windows.Media.SolidColorBrush(
    [System.Windows.Media.Color]::FromArgb(40, $c.R, $c.G, $c.B))
$transparentBrush = [System.Windows.Media.Brushes]::Transparent

function New-ResultRow {
    param($entry, [int]$index = 0)

    $layerColor = $layerColors[$entry.Layer]
    if (-not $layerColor) { $layerColor = $colors.Subtext0 }
    $layerLabel = $layerLabels[$entry.Layer]
    if (-not $layerLabel) { $layerLabel = $entry.Layer.ToUpper() }

    $outerGrid = New-Object System.Windows.Controls.Grid
    if ($td.HasAccentBars) {
        $accentCol = New-Object System.Windows.Controls.ColumnDefinition; $accentCol.Width = "3"
        $contentCol = New-Object System.Windows.Controls.ColumnDefinition; $contentCol.Width = "*"
        [void]$outerGrid.ColumnDefinitions.Add($accentCol)
        [void]$outerGrid.ColumnDefinitions.Add($contentCol)

        $accentBar = New-Object System.Windows.Controls.Border
        $accentBar.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom($layerColor)
        $accentBar.Opacity = 0.5; $accentBar.CornerRadius = "1"; $accentBar.Margin = "0,2,0,2"
        [void][System.Windows.Controls.Grid]::SetColumn($accentBar, 0)
        [void]$outerGrid.Children.Add($accentBar)
    } else {
        $contentCol = New-Object System.Windows.Controls.ColumnDefinition; $contentCol.Width = "*"
        [void]$outerGrid.ColumnDefinitions.Add($contentCol)
    }

    $grid = New-Object System.Windows.Controls.Grid
    $col1 = New-Object System.Windows.Controls.ColumnDefinition; $col1.Width = "90"
    $col2 = New-Object System.Windows.Controls.ColumnDefinition; $col2.Width = "200"
    $col3 = New-Object System.Windows.Controls.ColumnDefinition; $col3.Width = "*"
    [void]$grid.ColumnDefinitions.Add($col1)
    [void]$grid.ColumnDefinitions.Add($col2)
    [void]$grid.ColumnDefinitions.Add($col3)

    $bgColor = [System.Windows.Media.BrushConverter]::new().ConvertFrom($layerColor).Color
    $bgBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromArgb($badgeAlpha, $bgColor.R, $bgColor.G, $bgColor.B))
    $badge = New-Object System.Windows.Controls.Border
    $badge.CornerRadius = $badgeCR; $badge.Padding = "5,1"; $badge.Margin = "0,1,8,1"
    $badge.HorizontalAlignment = "Left"; $badge.Background = $bgBrush
    $badgeText = New-Object System.Windows.Controls.TextBlock
    $badgeText.Text = $layerLabel
    $badgeText.FontFamily = New-Object System.Windows.Media.FontFamily("Cascadia Code,Consolas,monospace")
    $badgeText.FontSize = 10; $badgeText.FontWeight = "SemiBold"
    $badgeText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($layerColor)
    $badge.Child = $badgeText
    [void][System.Windows.Controls.Grid]::SetColumn($badge, 0)
    [void]$grid.Children.Add($badge)

    $keyText = New-Object System.Windows.Controls.TextBlock
    $keyText.Text = $entry.Key
    $keyText.FontFamily = New-Object System.Windows.Media.FontFamily("Cascadia Code,Consolas,monospace")
    $keyText.FontSize = 12.5; $keyText.FontWeight = "Bold"
    $keyText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($colors.Text)
    $keyText.VerticalAlignment = "Center"; $keyText.Margin = "0,0,12,0"
    $keyText.TextTrimming = "CharacterEllipsis"
    [void][System.Windows.Controls.Grid]::SetColumn($keyText, 1)
    [void]$grid.Children.Add($keyText)

    $descText = New-Object System.Windows.Controls.TextBlock
    $descText.Text = $entry.Desc
    $descText.FontFamily = New-Object System.Windows.Media.FontFamily("Cascadia Code,Consolas,monospace")
    $descText.FontSize = 12
    $descText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($colors.Subtext0)
    $descText.VerticalAlignment = "Center"; $descText.TextTrimming = "CharacterEllipsis"
    [void][System.Windows.Controls.Grid]::SetColumn($descText, 2)
    [void]$grid.Children.Add($descText)

    $gridWrapper = New-Object System.Windows.Controls.Border
    $gridWrapper.Padding = "8,4"; $gridWrapper.Child = $grid
    $colIdx = if ($td.HasAccentBars) { 1 } else { 0 }
    [void][System.Windows.Controls.Grid]::SetColumn($gridWrapper, $colIdx)
    [void]$outerGrid.Children.Add($gridWrapper)

    $border = New-Object System.Windows.Controls.Border
    $border.CornerRadius = $rowCR; $border.Child = $outerGrid
    $border.Cursor = [System.Windows.Input.Cursors]::Arrow
    $border.Add_MouseEnter({ param($s, $e); $s.Background = $hoverBrush }.GetNewClosure())
    $border.Add_MouseLeave({ param($s, $e); $s.Background = $transparentBrush }.GetNewClosure())

    return $border
}

# ── Render results ───────────────────────────────────────
$script:currentLayerFilter = ""

function Update-Results {
    param($query)
    $resultsList.Children.Clear()
    $shown = 0

    foreach ($entry in $allEntries) {
        if ($shown -ge 500) { break }
        if ($script:currentLayerFilter -and $entry.Layer -ne $script:currentLayerFilter) { continue }
        if ($query) {
            $searchText = "$($entry.Layer) $($entry.Key) $($entry.Desc)".ToLower()
            $match = $true
            foreach ($word in $query.ToLower() -split '\s+') {
                if (-not $searchText.Contains($word)) { $match = $false; break }
            }
            if (-not $match) { continue }
        }
        $row = New-ResultRow -entry $entry -index $shown
        [void]$resultsList.Children.Add($row)
        $shown++
    }

    $total = $allEntries.Count
    $filterText = if ($script:currentLayerFilter) { " [$($layerLabels[$script:currentLayerFilter])]" } else { "" }
    $countLabel.Text = "$shown of $total$filterText"
}

# ── Layer cycling (Tab key) ──────────────────────────────
$layerOrder = @("") + ($allEntries | ForEach-Object { $_.Layer } | Select-Object -Unique)
$script:layerIndex = 0

# ── Events ───────────────────────────────────────────────
$searchBox.Add_TextChanged({
    $searchPlaceholder.Visibility = if ($searchBox.Text) { "Collapsed" } else { "Visible" }
    Update-Results -query $searchBox.Text
})

$window.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq "Escape") { $window.Hide(); $e.Handled = $true }
    elseif ($e.Key -eq "Tab") {
        $script:layerIndex = ($script:layerIndex + 1) % $layerOrder.Count
        Set-ActiveFilter -layer $layerOrder[$script:layerIndex]
        $e.Handled = $true
    }
})

$window.Add_Deactivated({ $window.Hide() })

$window.Add_IsVisibleChanged({
    if ($window.IsVisible) {
        $searchBox.Text = ""
        $script:layerIndex = 0
        Set-ActiveFilter -layer ""
        [void]$searchBox.Focus()
        [void]$script:fadeInStoryboard.Begin()
    }
})

$window.Add_Loaded({
    Update-Results -query ""
    [void]$searchBox.Focus()
})

# ── Global hotkey (Ctrl+Alt+K) ───────────────────────────
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HotKeyHelper {
    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
"@

$MOD_CONTROL = 0x0002; $MOD_ALT = 0x0001; $MOD_NOREPEAT = 0x4000
$VK_K = 0x4B; $HOTKEY_ID = 9001; $WM_HOTKEY = 0x0312

$window.Visibility = "Hidden"
[void]$window.Show()
[void]$window.Hide()

$helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
$hwnd = $helper.Handle

$source = [System.Windows.Interop.HwndSource]::FromHwnd($hwnd)
$source.AddHook({
    param([IntPtr]$hwnd, [int]$msg, [IntPtr]$wParam, [IntPtr]$lParam, [ref]$handled)
    if ($msg -eq $WM_HOTKEY) {
        if ($window.IsVisible) { [void]$window.Hide() }
        else {
            [void]$window.Show()
            [void]$window.Activate()
            [void]$searchBox.Focus()
        }
        $handled.Value = $true
    }
    [IntPtr]::Zero
}.GetNewClosure())

$registered = [HotKeyHelper]::RegisterHotKey($hwnd, $HOTKEY_ID, ($MOD_CONTROL -bor $MOD_ALT -bor $MOD_NOREPEAT), $VK_K)
if (-not $registered) {
    [System.Windows.MessageBox]::Show("Failed to register Ctrl+Alt+K hotkey.`nAnother app may be using it.", "Keybinds Overlay")
}

$app = New-Object System.Windows.Application
$app.ShutdownMode = "OnExplicitShutdown"
$app.Add_Exit({ [HotKeyHelper]::UnregisterHotKey($hwnd, $HOTKEY_ID) })
$app.Run()
