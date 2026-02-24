function Get-IRODTheme {
    <#
    .SYNOPSIS
        Gets the current IROD theme (Dark or Light).
    #>
    $settingsPath = Join-Path $env:APPDATA "IROD\settings.json"
    
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            if ($settings.Theme -eq 'Light') {
                return 'Light'
            }
        }
        catch { }
    }
    
    return 'Dark'
}

function Test-IRODThemeConfigured {
    <#
    .SYNOPSIS
        Checks if the theme has been explicitly configured.
    #>
    $settingsPath = Join-Path $env:APPDATA "IROD\settings.json"
    
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            if ($null -ne $settings.Theme) {
                return $true
            }
        }
        catch { }
    }
    
    return $false
}

function Set-IRODTheme {
    <#
    .SYNOPSIS
        Sets the IROD theme (Dark or Light).
    #>
    param(
        [ValidateSet('Dark', 'Light')]
        [string]$Theme
    )
    
    $settingsDir = Join-Path $env:APPDATA "IROD"
    $settingsPath = Join-Path $settingsDir "settings.json"
    
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }
    
    $settings = @{}
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
        }
        catch {
            $settings = @{}
        }
    }
    
    $settings['Theme'] = $Theme
    $settings | ConvertTo-Json | Set-Content $settingsPath -Force
    
    Write-Host "Theme set to: $Theme" -ForegroundColor Green
}

function Get-IRODThemeColors {
    <#
    .SYNOPSIS
        Returns color definitions for the current theme.
    #>
    $theme = Get-IRODTheme
    
    if ($theme -eq 'Light') {
        return @{
            WindowBackground = "#F5F5F5"
            ControlBackground = "#FFFFFF"
            ControlBackgroundAlt = "#F0F0F0"
            ControlBackgroundHover = "#E5E5E5"
            ControlBackgroundSelected = "#0078D4"
            TextPrimary = "#1E1E1E"
            TextSecondary = "#666666"
            TextPlaceholder = "#999999"
            Border = "#CCCCCC"
            BorderHover = "#AAAAAA"
            AccentGreen = "#2E8B57"
            AccentGreenHover = "#3E9B67"
            HeaderBackground = "#E8E8E8"
            ListBackground = "#FFFFFF"
            ListItemHover = "#F0F0F0"
            SelectedBackground = "#0078D4"
            SelectedText = "#FFFFFF"
            TooltipBackground = "#FFFFFF"
            TooltipBorder = "#CCCCCC"
            ButtonBackground = "#E1E1E1"
            ButtonHover = "#D5D5D5"
            SuccessGreen = "#228B22"
            WarningRed = "#C42B1C"
        }
    }
    else {
        # Dark theme (default)
        return @{
            WindowBackground = "#1E1E1E"
            ControlBackground = "#2D2D30"
            ControlBackgroundAlt = "#252526"
            ControlBackgroundHover = "#3E3E42"
            ControlBackgroundSelected = "#094771"
            TextPrimary = "#FFFFFF"
            TextSecondary = "#CCCCCC"
            TextPlaceholder = "#808080"
            Border = "#3F3F46"
            BorderHover = "#4F4F56"
            AccentGreen = "#2E8B57"
            AccentGreenHover = "#3E9B67"
            HeaderBackground = "#2D2D30"
            ListBackground = "#252526"
            ListItemHover = "#2D2D30"
            SelectedBackground = "#094771"
            SelectedText = "#FFFFFF"
            TooltipBackground = "#2D2D30"
            TooltipBorder = "#3F3F46"
            ButtonBackground = "#2D2D30"
            ButtonHover = "#3E3E42"
            SuccessGreen = "#4EBB77"
            WarningRed = "#F85149"
        }
    }
}
