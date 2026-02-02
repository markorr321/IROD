function Clear-IRODConfig {
    <#
    .SYNOPSIS
        Clears the saved IROD configuration.

    .DESCRIPTION
        Removes the user-level environment variables for ClientId and TenantId.
        On macOS, also offers to remove the configuration from PowerShell profile.
        After clearing, Invoke-IntuneRemediation will use the default authentication flow.

    .EXAMPLE
        Clear-IRODConfig
    #>
    [CmdletBinding()]
    param()

    try {
        [System.Environment]::SetEnvironmentVariable('IROD_CLIENTID', $null, 'User')
        [System.Environment]::SetEnvironmentVariable('IROD_TENANTID', $null, 'User')

        # Also clear from current session
        $env:IROD_CLIENTID = $null
        $env:IROD_TENANTID = $null

        Write-Host "IROD configuration cleared successfully." -ForegroundColor Green
        Write-Host "Invoke-IntuneRemediation will now use the default authentication flow.`n" -ForegroundColor Green

        # macOS-specific handling
        $isRunningOnMac = if ($null -ne $IsMacOS) { $IsMacOS } else { $PSVersionTable.OS -match 'Darwin' }
        if ($isRunningOnMac) {
            $profilePath = $PROFILE.CurrentUserAllHosts
            if (Test-Path $profilePath) {
                $profileContent = Get-Content -Path $profilePath -Raw
                if ($profileContent -match 'IROD_CLIENTID' -or $profileContent -match 'IROD_TENANTID') {
                    Write-Host "macOS Note:" -ForegroundColor Yellow
                    Write-Host "Configuration found in PowerShell profile." -ForegroundColor Gray
                    Write-Host "Would you like to remove it from your profile? (y/n)" -ForegroundColor Yellow
                    $choice = Read-Host

                    if ($choice -eq 'y' -or $choice -eq 'Y') {
                        $newContent = $profileContent -replace '(?ms)# IROD Configuration.*?\$env:IROD_TENANTID = ".*?"', ''
                        Set-Content -Path $profilePath -Value $newContent.Trim()
                        Write-Host "Removed from PowerShell profile: $profilePath`n" -ForegroundColor Green
                    } else {
                        Write-Host "Profile not modified. You can manually edit: $profilePath`n" -ForegroundColor Gray
                    }
                }
            }
        }
    }
    catch {
        Write-Host "Failed to clear configuration: $_" -ForegroundColor Red
    }
}
