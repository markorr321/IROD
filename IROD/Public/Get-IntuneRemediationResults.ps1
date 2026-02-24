function Get-IntuneRemediationResults {
    <#
    .SYNOPSIS
        Retrieves Intune remediation script results and exports them to a CSV file.

    .DESCRIPTION
        This function connects to Microsoft Graph API using Connect-MgGraph, retrieves the
        specified Intune remediation script results, and exports the data to a CSV file.
        Uses direct REST API calls for data retrieval.

    .PARAMETER RemediationName
        The display name of the Intune remediation script to retrieve results for.
        If not provided, lists available scripts and prompts for selection.

    .PARAMETER CsvPath
        The file path where the CSV results should be saved.

    .EXAMPLE
        Get-IntuneRemediationResults -RemediationName "Fix Disk Space" -CsvPath "C:\Reports\remediation.csv"
        Retrieves results for the "Fix Disk Space" remediation and saves to the specified CSV file.

    .EXAMPLE
        Get-IntuneRemediationResults -CsvPath ".\results.csv"
        Lists available remediation scripts and prompts for selection before exporting.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$RemediationName,

        [Parameter(Mandatory=$true)]
        [string]$CsvPath
    )

    function Get-AllGraphResults {
        <#
        .SYNOPSIS
            Handles pagination for Graph API requests using Invoke-MgGraphRequest.
        #>
        param(
            [Parameter(Mandatory=$true)]
            [string]$Uri
        )

        $allResults = @()
        $nextLink = $Uri

        do {
            try {
                $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
            }
            catch {
                throw "Graph API request failed: $_"
            }

            if ($response.value) {
                $allResults += $response.value
            }
            else {
                $allResults += $response
            }

            $nextLink = $response.'@odata.nextLink'
        } while ($nextLink)

        return $allResults
    }

    try {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan

        # Ensure we're connected to Microsoft Graph
        $context = Get-MgContext
        if (-not $context) {
            Write-Host "Not connected to Microsoft Graph. Initiating connection..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All", "DeviceManagementManagedDevices.Read.All"
        }
        else {
            Write-Host "Using existing Microsoft Graph connection (Tenant: $($context.TenantId))" -ForegroundColor Green
        }

        # Get all device health scripts (remediations)
        $scriptsUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"
        $allScripts = Get-AllGraphResults -Uri $scriptsUri

        # If RemediationName not provided, list available scripts and prompt for selection
        if (-not $RemediationName) {
            Write-Host "`nAvailable remediation scripts:" -ForegroundColor Yellow
            $allScripts | ForEach-Object { Write-Host "  - $($_.displayName)" -ForegroundColor Gray }
            Write-Host ""
            $RemediationName = Read-Host "Enter the remediation name"
        }

        Write-Host "Searching for remediation script: $RemediationName" -ForegroundColor Cyan

        # Find the specific remediation by name
        $remediation = $allScripts | Where-Object { $_.displayName -eq $RemediationName }

        if (-not $remediation) {
            Write-Error "Remediation script '$RemediationName' not found."
            Write-Host "`nAvailable remediation scripts:" -ForegroundColor Yellow
            $allScripts | ForEach-Object { Write-Host "  - $($_.displayName)" -ForegroundColor Gray }
            return
        }

        Write-Host "Found remediation: $($remediation.displayName) (ID: $($remediation.id))" -ForegroundColor Green

        # Get device run states for this remediation
        Write-Host "Retrieving device run states..." -ForegroundColor Cyan
        $runStatesUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($remediation.id)/deviceRunStates"
        $deviceRunStates = Get-AllGraphResults -Uri $runStatesUri

        if ($deviceRunStates.Count -eq 0) {
            Write-Warning "No device run states found for this remediation."
            return
        }

        Write-Host "Found $($deviceRunStates.Count) device run state(s)" -ForegroundColor Green

        # Process results into a more readable format
        $results = @()
        $counter = 0
        foreach ($runState in $deviceRunStates) {
            $counter++
            Write-Progress -Activity "Processing device run states" -Status "Device $counter of $($deviceRunStates.Count)" -PercentComplete (($counter / $deviceRunStates.Count) * 100)

            # Get managed device details
            $deviceName = "Unknown"
            $deviceUser = "Unknown"
            $deviceId = $runState.id.Split(":")[1]

            if ($deviceId) {
                try {
                    $deviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($deviceId)"
                    $deviceDetails = Invoke-MgGraphRequest -Method GET -Uri $deviceUri
                    $deviceName = $deviceDetails.deviceName
                    $deviceUser = $deviceDetails.userPrincipalName
                }
                catch {
                    Write-Verbose "Could not retrieve device details for $deviceId"
                }
            }

            $resultObject = [PSCustomObject]@{
                DeviceName = $deviceName
                UserPrincipalName = $deviceUser
                DetectionState = $runState.detectionState
                LastStateUpdateDateTime = $runState.lastStateUpdateDateTime
                PreRemediationDetectionScriptOutput = $runState.preRemediationDetectionScriptOutput
                RemediationState = $runState.remediationState
                PostRemediationDetectionScriptOutput = $runState.postRemediationDetectionScriptOutput
                RemediationScriptErrorDetails = $runState.remediationScriptErrorDetails
                DetectionScriptErrorDetails = $runState.detectionScriptErrorDetails
                ManagedDeviceId = $deviceId
            }

            $results += $resultObject
        }

        Write-Progress -Activity "Processing device run states" -Completed

        # Export to CSV
        Write-Host "Exporting results to: $CsvPath" -ForegroundColor Cyan
        $results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

        Write-Host "`nExport completed successfully!" -ForegroundColor Green
        Write-Host "Total records exported: $($results.Count)" -ForegroundColor Cyan

        # Display summary
        Write-Host "`nSummary:" -ForegroundColor Yellow
        $detectionStates = $results | Group-Object DetectionState
        foreach ($state in $detectionStates) {
            Write-Host "  $($state.Name): $($state.Count)" -ForegroundColor Gray
        }

    }
    catch {
        Write-Error "An error occurred: $_"
        throw
    }
}
