function Test-IRODUpdate {
    <#
    .SYNOPSIS
        Checks if a newer version of IROD is available on PowerShell Gallery.

    .DESCRIPTION
        Performs a quick check for updates on each run.
        Silently handles all errors to not interrupt user experience.
    #>
    [CmdletBinding()]
    param()

    try {
        # Allow users to disable update checks via environment variable
        if ($env:IROD_DISABLE_UPDATE_CHECK -eq 'true') {
            return
        }

        # Get current module version (check loaded module first, then installed)
        $currentModule = Get-Module -Name IROD |
            Sort-Object Version -Descending |
            Select-Object -First 1
        
        if (-not $currentModule) {
            $currentModule = Get-Module -Name IROD -ListAvailable |
                Sort-Object Version -Descending |
                Select-Object -First 1
        }

        if (-not $currentModule) {
            return
        }

        $currentVersion = $currentModule.Version

        # Fast version check using URL redirect
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

            if ($currentVersion -lt $latestVersion) {
                Show-UpdateNotification -CurrentVersion $currentVersion -LatestVersion $latestVersion
            }

        } catch {
            return
        }

    } catch {
        return
    }
}
