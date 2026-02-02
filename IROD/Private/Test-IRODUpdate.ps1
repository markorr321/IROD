function Test-IRODUpdate {
    <#
    .SYNOPSIS
        Checks if a newer version of IROD is available on PowerShell Gallery.

    .DESCRIPTION
        Performs a non-intrusive check for updates once per 24 hours.
        Uses cached results to avoid excessive API calls.
        Silently handles all errors to not interrupt user experience.
    #>
    [CmdletBinding()]
    param()

    try {
        # Allow users to disable update checks via environment variable
        if ($env:IROD_DISABLE_UPDATE_CHECK -eq 'true') {
            return
        }

        # Get current module version
        $currentModule = Get-Module -Name IROD -ListAvailable |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $currentModule) {
            return
        }

        $currentVersion = $currentModule.Version

        # Setup cache file path (cross-platform)
        $tempPath = [System.IO.Path]::GetTempPath()
        $cacheFile = Join-Path $tempPath "IROD_UpdateCheck.json"

        # Check if we have valid cached data
        $shouldCheck = $true
        if (Test-Path $cacheFile) {
            try {
                $cache = Get-Content $cacheFile -Raw -ErrorAction Stop | ConvertFrom-Json

                if ($cache.LastCheckTime -and $cache.LatestVersion -and $cache.CurrentVersion) {
                    $lastCheck = [DateTime]::Parse($cache.LastCheckTime)
                    $hoursSinceCheck = ((Get-Date) - $lastCheck).TotalHours

                    if ($hoursSinceCheck -lt 24) {
                        $shouldCheck = $false
                        $latestVersion = [version]$cache.LatestVersion

                        if ($currentVersion -lt $latestVersion) {
                            Show-UpdateNotification -CurrentVersion $currentVersion -LatestVersion $latestVersion
                        }
                    }
                }
            } catch {
                Remove-Item $cacheFile -ErrorAction SilentlyContinue
                $shouldCheck = $true
            }
        }

        if ($shouldCheck) {
            try {
                $url = "https://www.powershellgallery.com/packages/IROD"
                $latestVersion = $null

                try {
                    $null = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 5 -ErrorAction Stop
                } catch {
                    if ($_.Exception.Response -and $_.Exception.Response.Headers) {
                        try {
                            $location = $_.Exception.Response.Headers.GetValues('Location') | Select-Object -First 1
                            if ($location) {
                                $versionString = Split-Path -Path $location -Leaf
                                $latestVersion = [version]$versionString
                            } else {
                                return
                            }
                        } catch {
                            return
                        }
                    } else {
                        return
                    }
                }

                if (-not $latestVersion) {
                    return
                }

                # Update cache
                $cacheData = @{
                    LastCheckTime = (Get-Date).ToString('o')
                    LatestVersion = $latestVersion.ToString()
                    CurrentVersion = $currentVersion.ToString()
                }

                try {
                    $cacheData | ConvertTo-Json | Set-Content $cacheFile -ErrorAction Stop
                } catch {
                    # Can't write cache - continue anyway
                }

                if ($currentVersion -lt $latestVersion) {
                    Show-UpdateNotification -CurrentVersion $currentVersion -LatestVersion $latestVersion
                }

            } catch {
                return
            }
        }

    } catch {
        return
    }
}
