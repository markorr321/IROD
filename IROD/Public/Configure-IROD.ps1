function Configure-IROD {
    <#
    .SYNOPSIS
        Configure IROD with custom app registration credentials and theme.

    .DESCRIPTION
        Configures ClientId and TenantId (saved as user-level environment variables)
        and UI theme preference (saved to settings file). Once configured,
        Invoke-IntuneRemediation will automatically use these credentials.

    .PARAMETER Theme
        Set the UI theme to 'Dark' or 'Light'. If not specified, prompts interactively.

    .EXAMPLE
        Configure-IROD
        Interactively configure all settings.

    .EXAMPLE
        Configure-IROD -Theme Dark
        Set theme to Dark mode only.

    .NOTES
        Required App Registration Settings:
        - Platform: Mobile and desktop applications
        - Redirect URI: http://localhost
        - Allow public client flows: Yes
        - API Permissions (delegated):
          - DeviceManagementConfiguration.Read.All
          - DeviceManagementManagedDevices.Read.All
          - DeviceManagementManagedDevices.PrivilegedOperations.All
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Dark', 'Light')]
        [string]$Theme
    )

    # If only Theme parameter is provided, just set the theme and exit
    if ($PSBoundParameters.ContainsKey('Theme')) {
        Set-IRODTheme -Theme $Theme
        return
    }

    Write-Host ""
    Write-Host "[ I R O D ]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will configure your custom app registration for IROD."
    Write-Host "These settings will be saved as user-level environment variables.`n"

    # Prompt for ClientId
    $clientId = Read-Host "Enter your App Registration Client ID"
    if ([string]::IsNullOrWhiteSpace($clientId)) {
        Write-Host "ClientId cannot be empty. Configuration cancelled." -ForegroundColor Yellow
        return
    }

    # Prompt for TenantId
    $tenantId = Read-Host "Enter your Tenant ID"
    if ([string]::IsNullOrWhiteSpace($tenantId)) {
        Write-Host "TenantId cannot be empty. Configuration cancelled." -ForegroundColor Yellow
        return
    }

    # Set user-level environment variables
    try {
        [System.Environment]::SetEnvironmentVariable('IROD_CLIENTID', $clientId, 'User')
        [System.Environment]::SetEnvironmentVariable('IROD_TENANTID', $tenantId, 'User')

        # Also set for current session
        $env:IROD_CLIENTID = $clientId
        $env:IROD_TENANTID = $tenantId

        Write-Host "`nConfiguration saved successfully!" -ForegroundColor Green
        Write-Host "You can now run Invoke-IntuneRemediation without parameters.`n" -ForegroundColor Green

        # macOS-specific handling
        $isRunningOnMac = if ($null -ne $IsMacOS) { $IsMacOS } else { $PSVersionTable.OS -match 'Darwin' }
        if ($isRunningOnMac) {
            Write-Host "macOS Note:" -ForegroundColor Yellow
            Write-Host "Environment variables may not persist across terminal sessions on macOS." -ForegroundColor Gray
            Write-Host "To ensure persistence, add the following to your PowerShell profile:`n" -ForegroundColor Gray
            Write-Host "`$env:IROD_CLIENTID = `"$clientId`"" -ForegroundColor Cyan
            Write-Host "`$env:IROD_TENANTID = `"$tenantId`"`n" -ForegroundColor Cyan

            Write-Host "Would you like to:" -ForegroundColor Yellow
            Write-Host "  1) Add automatically to PowerShell profile" -ForegroundColor White
            Write-Host "  2) Do it manually later" -ForegroundColor White
            Write-Host ""
            $choice = Read-Host "Enter choice (1 or 2)"

            if ($choice -eq "1") {
                $profilePath = $PROFILE.CurrentUserAllHosts
                if (-not (Test-Path $profilePath)) {
                    New-Item -Path $profilePath -ItemType File -Force | Out-Null
                }

                $profileContent = @"

# IROD Configuration
`$env:IROD_CLIENTID = "$clientId"
`$env:IROD_TENANTID = "$tenantId"
"@
                Add-Content -Path $profilePath -Value $profileContent
                Write-Host "`nAdded to PowerShell profile: $profilePath" -ForegroundColor Green
                Write-Host "Configuration will persist across sessions.`n" -ForegroundColor Green
            } else {
                Write-Host "`nYou can add it manually later to: $($PROFILE.CurrentUserAllHosts)`n" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Host "`nFailed to save configuration: $_" -ForegroundColor Red
    }
}
