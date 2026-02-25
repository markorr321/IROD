function Show-UpdateNotification {
    <#
    .SYNOPSIS
        Displays the update notification message.

    .DESCRIPTION
        Shows a formatted notification when a newer version of IROD
        is available on PowerShell Gallery.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [version]$CurrentVersion,

        [Parameter(Mandatory)]
        [version]$LatestVersion
    )

    Write-Host ""
    Write-Host "[!] IROD update available: $CurrentVersion -> $LatestVersion" -ForegroundColor Red
    Write-Host ""

    $response = Read-Host "Update now? (Y/N) [Press Enter to skip]"

    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host ""
        Write-Host "Updating IROD..." -ForegroundColor Cyan

        try {
            $updateSuccess = $false
            
            # Detect installation path to determine scope
            $installPath = $null
            $hasPSResourceGet = Get-Command Get-InstalledPSResource -ErrorAction SilentlyContinue
            $hasPowerShellGet = Get-Command Get-InstalledModule -ErrorAction SilentlyContinue
            
            if ($hasPSResourceGet) {
                $psResource = Get-InstalledPSResource -Name IROD -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($psResource) { $installPath = $psResource.InstalledLocation }
            }
            if (-not $installPath -and $hasPowerShellGet) {
                $psModule = Get-InstalledModule -Name IROD -ErrorAction SilentlyContinue
                if ($psModule) { $installPath = $psModule.InstalledLocation }
            }
            
            # Determine scope from install path (AllUsers = Program Files or /usr/local)
            $scope = if ($installPath -match 'Program Files|/usr/local') { 'AllUsers' } else { 'CurrentUser' }
            
            # Try Update-PSResource first (modern PowerShellGet v3+)
            if (-not $updateSuccess -and (Get-Command Update-PSResource -ErrorAction SilentlyContinue)) {
                Write-Host "  Trying Update-PSResource..." -ForegroundColor Gray
                $ErrorActionPreference = 'Stop'
                Update-PSResource -Name IROD -Scope $scope -TrustRepository -Confirm:$false -ErrorAction Stop
                $updateSuccess = $true
            }
            
            # Fallback to Update-Module (PowerShellGet v2)
            if (-not $updateSuccess -and (Get-Command Update-Module -ErrorAction SilentlyContinue)) {
                Write-Host "  Trying Update-Module..." -ForegroundColor Gray
                Update-Module -Name IROD -Force -ErrorAction Stop
                $updateSuccess = $true
            }
            
            # Last resort: fresh install
            if (-not $updateSuccess) {
                if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
                    Write-Host "  Trying fresh Install-PSResource..." -ForegroundColor Gray
                    Install-PSResource -Name IROD -Scope $scope -TrustRepository -Reinstall -Confirm:$false -ErrorAction Stop
                    $updateSuccess = $true
                }
                elseif (Get-Command Install-Module -ErrorAction SilentlyContinue) {
                    Write-Host "  Trying fresh Install-Module..." -ForegroundColor Gray
                    Install-Module -Name IROD -Force -AllowClobber -Scope $scope -ErrorAction Stop
                    $updateSuccess = $true
                }
            }
            
            if ($updateSuccess) {
                Write-Host ""
                Write-Host "Update complete! Please restart PowerShell and run Invoke-IntuneRemediation again." -ForegroundColor Green
                Write-Host ""
                Write-Host "Press Enter to Exit"
                $null = [Console]::ReadLine()
                exit
            }
            else {
                throw "No update method available"
            }
        }
        catch {
            Write-Host ""
            Write-Host "Update failed: $_" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please close all PowerShell sessions and update manually:" -ForegroundColor Yellow
            Write-Host "  Install-PSResource -Name IROD -Reinstall -TrustRepository" -ForegroundColor Yellow
            Write-Host "  -- or --" -ForegroundColor Gray
            Write-Host "  Install-Module -Name IROD -Force -AllowClobber" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press Enter to continue anyway"
            $null = [Console]::ReadLine()
        }
    }
    elseif ($response -eq 'N' -or $response -eq 'n') {
        Write-Host "Skipping update." -ForegroundColor Yellow
        Write-Host ""
    }
    else {
        Write-Host ""
    }
}
