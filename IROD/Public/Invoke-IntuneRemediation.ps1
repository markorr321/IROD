function Invoke-IntuneRemediation {
<#
.SYNOPSIS
    Trigger Intune Proactive Remediation scripts on-demand for single or multiple devices.

.DESCRIPTION
    IROD (Intune Remediation On Demand) connects to Microsoft Graph and lets you trigger 
    proactive remediation scripts immediately on target devices, rather than waiting for 
    the scheduled run time.

    Features:
    - Single device or multi-device remediation
    - Import devices from CSV/TXT files for bulk operations
    - Script preview (view detection/remediation code)
    - Favorite scripts for quick access
    - Parallel execution for large batches (50+ devices)
    - History logging with 30-day retention
    - Export remediation results to CSV

.PARAMETER DeviceName
    The name of a specific device to run remediation on. When specified, runs in single device mode.

.PARAMETER MultiDevice
    Switch to enable multi-device mode with a WPF GUI for selecting multiple devices.

.PARAMETER ExportResults
    Switch to export remediation results for a script to CSV.

.PARAMETER ClientId
    Client ID of the app registration to use for authentication. 
    If not provided, checks IROD_CLIENTID environment variable.

.PARAMETER TenantId
    Tenant ID to use with the specified app registration. 
    If not provided, checks IROD_TENANTID environment variable.

.PARAMETER Help
    Shows detailed cmdlet help.

.EXAMPLE
    Invoke-IntuneRemediation
    
    Runs in interactive mode with menu options:
    [1] Single Device - Enter device name
    [2] Multi-Device - GUI selection
    [3] Import from File - Load from CSV/TXT
    [4] Export Results - Export to CSV
    [5] View History - See past remediations
    [H] Help - Documentation

.EXAMPLE
    Invoke-IntuneRemediation -DeviceName "DESKTOP-ABC123"
    
    Runs remediation on a single device by name.

.EXAMPLE
    Invoke-IntuneRemediation -MultiDevice
    
    Opens WPF GUI to search, filter, and select multiple devices.

.EXAMPLE
    Invoke-IntuneRemediation -ExportResults
    
    Exports remediation results (detection state, output, errors) to CSV.

.EXAMPLE
    Invoke-IntuneRemediation -ClientId "12345-..." -TenantId "67890-..."
    
    Uses specified app registration for authentication instead of interactive login.

.NOTES
    Author: IROD Project
    Version: 1.0.0
    
    Requirements:
    - PowerShell 5.1 or later
    - Microsoft.Graph.Authentication module (auto-installed if missing)
    - Graph permissions: DeviceManagementManagedDevices.ReadWrite.All, 
      DeviceManagementConfiguration.Read.All

    Files:
    - Favorites: %APPDATA%\IROD\favorites.json
    - History: C:\Windows\Temp\IROD_history.json (30-day retention)

    For detailed help, run the tool and press H for interactive documentation.

.LINK
    https://github.com/markorr321/IROD
#>

    [CmdletBinding()]
    param(
        [string]$DeviceName,
        [switch]$MultiDevice,
        [switch]$ExportResults,
        [string]$ClientId,
        [string]$TenantId,
        [switch]$Help
    )

    # Display help if requested
    if ($Help) {
        Get-Help Invoke-IntuneRemediation -Detailed
        return
    }

    # Check for module updates
    Test-IRODUpdate

    # Check for environment variables if parameters not provided
    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        $ClientId = $env:IROD_CLIENTID
    }
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        $TenantId = $env:IROD_TENANTID
    }

    Clear-Host
    Write-Host ""
    Write-Host "[ I R O D ]" -ForegroundColor Cyan -NoNewline
    Write-Host "  v1.0.2" -ForegroundColor DarkGray
    Write-Host "  with PowerShell" -ForegroundColor DarkCyan
    Write-Host ""

    # First-run theme selection
    if (-not (Test-IRODThemeConfigured)) {
        Write-Host "Welcome! Choose your preferred UI theme:" -ForegroundColor Cyan
        Write-Host "  [D] Dark  (default)" -ForegroundColor Green
        Write-Host "  [L] Light" -ForegroundColor Green
        Write-Host ""
        $themeChoice = Read-Host "Enter choice (D/L)"
        if ($themeChoice -eq 'L' -or $themeChoice -eq 'l') {
            Set-IRODTheme -Theme 'Light'
        } else {
            Set-IRODTheme -Theme 'Dark'
        }
        Write-Host ""
    }

    # Determine execution mode FIRST
$executionMode = $null

if ($ExportResults) {
    $executionMode = 'ExportResults'
    Write-Host "[Mode] Export Results (from parameter)" -ForegroundColor Gray
}
elseif ($MultiDevice) {
    $executionMode = 'MultiDevice'
    Write-Host "[Mode] Multi-Device (from parameter)" -ForegroundColor Gray
}
elseif ($DeviceName) {
    $executionMode = 'SingleDevice'
    Write-Host "[Mode] Single Device: $DeviceName (from parameter)" -ForegroundColor Gray
}
else {
    # Prompt user to choose mode
    Write-Host "  [1] Single Device" -ForegroundColor Green
    Write-Host "      Run remediation on one specific device" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [2] Multi-Device" -ForegroundColor Green
    Write-Host "      Select multiple devices via GUI" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [3] Import from File" -ForegroundColor Green
    Write-Host "      Load device names from CSV or TXT file" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [4] Export Results" -ForegroundColor Green
    Write-Host "      Export remediation results to CSV" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [5] View History" -ForegroundColor Green
    Write-Host "      View recent remediation history" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [H] Help" -ForegroundColor Cyan
    Write-Host "      View documentation and tips" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [Q] Quit" -ForegroundColor Red
    Write-Host ""

    do {
        $choice = Read-Host "Enter choice (1-5, H, or Q)"
        if ($choice -eq 'Q' -or $choice -eq 'q') {
            # Check if there's an active Graph session and disconnect
            try {
                $context = Get-MgContext -ErrorAction SilentlyContinue
                if ($context) {
                    Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Red
                    Disconnect-MgGraph | Out-Null
                    Write-Host "Disconnected." -ForegroundColor Green
                }
            }
            catch {
                # Silently continue if there's an issue checking/disconnecting
            }
            Write-Host "Exiting." -ForegroundColor Gray
            return
        }
        if ($choice -eq 'H' -or $choice -eq 'h') {
            # Show help and loop back
            do {
                $showHelpAgain = Show-IRODHelp
            } while ($showHelpAgain -eq $true)
            
            # Restart to show menu again
            Invoke-IntuneRemediation
            return
        }
        if ($choice -eq '5') {
            Clear-Host
            Write-Host ""
            Write-Host "[ I R O D ]" -ForegroundColor Cyan
            Show-IRODHistory -Limit 20
            Write-Host ""
            Write-Host "  [E] Export history to CSV" -ForegroundColor Green
            Write-Host "  [Enter] Return to menu" -ForegroundColor Gray
            Write-Host ""
            $historyChoice = Read-Host "Choice"
            
            if ($historyChoice -eq 'E' -or $historyChoice -eq 'e') {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $defaultFileName = "IROD_History_$timestamp.csv"
                Write-Host ""
                Write-Host "Opening save dialog..." -ForegroundColor Cyan
                
                $exportPath = Show-SaveFileDialog -DefaultFileName $defaultFileName -Title "Export History"
                
                if (-not $exportPath) {
                    Write-Host "  Export cancelled." -ForegroundColor Red
                }
                else {
                    Export-IRODHistory -Path $exportPath | Out-Null
                }
                Write-Host ""
                Write-Host "Press Enter to continue..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            
            # Restart to show menu again
            Invoke-IntuneRemediation
            return
        }
    } while ($choice -ne '1' -and $choice -ne '2' -and $choice -ne '3' -and $choice -ne '4')

    if ($choice -eq '4') {
        $executionMode = 'ExportResults'
        Clear-Host
        Write-Host ""
        Write-Host "[ I R O D ]" -ForegroundColor Cyan
        Write-Host ""
    }    elseif ($choice -eq '3') {
        $executionMode = 'ImportFromFile'
        Clear-Host
        Write-Host ""
        Write-Host "[ I R O D ]" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Import Devices from File" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Supported formats:" -ForegroundColor Gray
        Write-Host "    - CSV with column: DeviceName, Name, ComputerName, or Device" -ForegroundColor Gray
        Write-Host "    - TXT with one device name per line" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [1] Import from CSV" -ForegroundColor Green
        Write-Host "  [2] Export template CSV" -ForegroundColor Green
        Write-Host "  [B] Back to main menu" -ForegroundColor Gray
        Write-Host ""
        
        $importChoice = Read-Host "Choice"
        
        if ($importChoice -eq 'B' -or $importChoice -eq 'b') {
            Invoke-IntuneRemediation
            return
        }
        
        if ($importChoice -eq '2') {
            Write-Host ""
            Write-Host "Opening save dialog..." -ForegroundColor Cyan
            
            $templatePath = Show-SaveFileDialog -DefaultFileName "IROD_Import_Template.csv" -Title "Save Import Template"
            
            if (-not $templatePath) {
                Write-Host "  Template export cancelled." -ForegroundColor Red
            }
            else {
                # Create template CSV with example entries
                $templateContent = @"
DeviceName
DESKTOP-EXAMPLE1
LAPTOP-EXAMPLE2
PC-EXAMPLE3
"@
                $templateContent | Set-Content -Path $templatePath -Encoding UTF8
                Write-Host ""
                Write-Host "  Template exported to: $templatePath" -ForegroundColor Green
                Write-Host ""
                Write-Host "  Edit the file with your device names (one per row)," -ForegroundColor Gray
                Write-Host "  then run Import from File again." -ForegroundColor Gray
            }
            Write-Host ""
            Write-Host "Press Enter to continue..." -ForegroundColor Gray
            Read-Host | Out-Null
            Invoke-IntuneRemediation
            return
        }
        
        if ($importChoice -ne '1') {
            Write-Host "`nInvalid choice." -ForegroundColor Red
            Write-Host ""
            Write-Host "Press Enter to continue..." -ForegroundColor Gray
            Read-Host | Out-Null
            Invoke-IntuneRemediation
            return
        }
        
        Write-Host ""
        Write-Host "Opening file dialog..." -ForegroundColor Cyan
        
        $script:importFilePath = Show-OpenFileDialog -Title "Select Device Import File"
        
        if (-not $script:importFilePath) {
            Write-Host "`nNo file selected. Cancelled." -ForegroundColor Red
            Write-Host ""
            Write-Host "Press Enter to continue..." -ForegroundColor Gray
            Read-Host | Out-Null
            Invoke-IntuneRemediation
            return
        }
        
        Write-Host "  File: $script:importFilePath" -ForegroundColor Green
        Write-Host ""
    }    elseif ($choice -eq '1') {
        $executionMode = 'SingleDevice'
        Clear-Host
        Write-Host ""
        Write-Host "[ I R O D ]" -ForegroundColor Cyan
        Write-Host ""
        $DeviceName = Read-Host "Enter device name"
        if ([string]::IsNullOrWhiteSpace($DeviceName)) {
            Write-Host "`nError: No device name provided." -ForegroundColor Red
            Write-Host "Exiting." -ForegroundColor Gray
            return
        }
        Write-Host "Target device: $DeviceName" -ForegroundColor Green
    }
    else {
        $executionMode = 'MultiDevice'
        Clear-Host
        Write-Host ""
        Write-Host "[ I R O D ]" -ForegroundColor Cyan
        Write-Host ""
    }
}

# Connect
if (-not (Connect-ToGraph -ClientId $ClientId -TenantId $TenantId)) {
    Write-Host "`nAuthentication failed. Exiting." -ForegroundColor Red
    return
}

# Get and display scripts
Write-Host ""
Write-Host "Loading Remediation Scripts" -ForegroundColor Cyan

$scripts = Get-RemediationScripts

if ($scripts.Count -eq 0) {
    Write-Host "`nNo remediation scripts found in Intune." -ForegroundColor Yellow
    Write-Host "Disconnecting..." -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    return
}

Write-Host "Found $($scripts.Count) remediation script$(if($scripts.Count -ne 1){'s'})" -ForegroundColor Green

# Select script via WPF GUI
Write-Host ""
Write-Host "Select Remediation Script" -ForegroundColor Cyan
Write-Host "Opening script selection window..." -ForegroundColor Gray
$scriptItems = $scripts | Select-Object displayName, id, description, publisher, version | Sort-Object displayName

$columns = @(
    @{ Header = "Script Name"; Property = "displayName"; Width = 380 }
    @{ Header = "Publisher"; Property = "publisher"; Width = 140 }
    @{ Header = "Version"; Property = "version"; Width = 70 }
    @{ Header = "ID"; Property = "id"; Width = 280 }
)

$selectedScript = Show-GridSelector -Items $scriptItems -Title "Select Remediation Script" -Columns $columns -ShowPreview -ShowFavorites -TooltipProperty "description"

if ($script:exitRequested) {
    Write-Host "`nExit requested. Disconnecting from Microsoft Graph..." -ForegroundColor Yellow
    Disconnect-MgGraph | Out-Null
    Write-Host "Disconnected. Goodbye!" -ForegroundColor Red
    return
}

if (-not $selectedScript) {
    Write-Host "`nCancelled. Disconnecting from Microsoft Graph..." -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    Write-Host "Disconnected." -ForegroundColor Red
    return
}

# Handle based on mode
if ($executionMode -eq 'ExportResults') {
    # Export results mode
    Write-Host ""
    Write-Host "Selected Script: $($selectedScript.displayName)" -ForegroundColor Green
    Write-Host ""
    
    # Prompt for output path using Save File Dialog
    $timestamp = Get-Date -Format "yyyyMMdd_hhmmsstt"
    $defaultFilename = "$($selectedScript.displayName -replace '[\\/:*?"<>|]', '_')_Results_$timestamp.csv"
    Write-Host "Opening save dialog..." -ForegroundColor Cyan
    
    $csvPath = Show-SaveFileDialog -DefaultFileName $defaultFilename -Title "Export Remediation Results"
    
    if (-not $csvPath) {
        Write-Host "`nExport cancelled. Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        return
    }
    
    Write-Host ""
    Write-Host "Exporting results for: $($selectedScript.displayName)" -ForegroundColor Cyan
    Write-Host "Output file: $csvPath" -ForegroundColor Gray
    Write-Host ""
    
    # Call the export function using the script ID
    try {
        # Get device run states for this remediation with pagination
        Write-Host "Retrieving device run states..." -ForegroundColor Cyan
        $runStatesUri = "$script:GraphBaseUrl/deviceManagement/deviceHealthScripts/$($selectedScript.id)/deviceRunStates?`$expand=managedDevice"
        
        $deviceRunStates = @()
        $nextLink = $runStatesUri
        
        do {
            $response = Invoke-Graph -Uri $nextLink
            if ($response.value) {
                $deviceRunStates += $response.value
            }
            $nextLink = $response.'@odata.nextLink'
        } while ($nextLink)
        
        if ($deviceRunStates.Count -eq 0) {
            Write-Warning "No device run states found for this remediation."
        }
        else {
            Write-Host "Found $($deviceRunStates.Count) device run state(s)" -ForegroundColor Green
            
            # Process results into a more readable format
            $results = @()
            $counter = 0
            foreach ($runState in $deviceRunStates) {
                $counter++
                Write-Progress -Activity "Processing device run states" -Status "Device $counter of $($deviceRunStates.Count)" -PercentComplete (($counter / $deviceRunStates.Count) * 100)
                
                # Get device details from expanded managedDevice property
                $deviceName = "Unknown"
                $deviceUser = "Unknown"
                $deviceId = $null
                
                if ($runState.managedDevice) {
                    $deviceName = $runState.managedDevice.deviceName
                    $deviceUser = $runState.managedDevice.userPrincipalName
                    $deviceId = $runState.managedDevice.id
                }
                else {
                    # Fallback: Try to get device ID from managedDeviceId property
                    if ($runState.managedDeviceId) {
                        $deviceId = $runState.managedDeviceId
                    }
                    # Or extract from the run state ID
                    elseif ($runState.id) {
                        if ($runState.id.Contains("_")) {
                            $deviceId = $runState.id.Split("_")[1]
                        }
                        elseif ($runState.id.Contains(":")) {
                            $deviceId = $runState.id.Split(":")[1]
                        }
                    }
                    
                    if ($deviceId) {
                        try {
                            $deviceUri = "$script:GraphBaseUrl/deviceManagement/managedDevices/$deviceId"
                            $deviceDetails = Invoke-Graph -Uri $deviceUri
                            $deviceName = $deviceDetails.deviceName
                            $deviceUser = $deviceDetails.userPrincipalName
                        }
                        catch {
                            Write-Verbose "Could not retrieve device details for $deviceId"
                        }
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
            Write-Host "Exporting results to: $csvPath" -ForegroundColor Cyan
            $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            
            Write-Host "`nExport completed successfully!" -ForegroundColor Green
            Write-Host "Total records exported: $($results.Count)" -ForegroundColor Cyan
            
            # Display summary
            Write-Host "`nSummary:" -ForegroundColor Yellow
            $detectionStates = $results | Group-Object DetectionState
            foreach ($state in $detectionStates) {
                Write-Host "  $($state.Name): $($state.Count)" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Error "An error occurred during export: $_"
    }
    
    # Prompt to run again or exit
    Write-Host ""
    Write-Host "Next Action" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [R] Run again" -ForegroundColor Green
    Write-Host "  [X] Exit" -ForegroundColor Red
    Write-Host ""
    
    $runAgain = Read-Host "Choice (R/X)"
    
    if ($runAgain -eq 'R' -or $runAgain -eq 'r') {
        Write-Host ""
        Write-Host "Restarting tool..." -ForegroundColor Cyan
        Write-Host ""
        Invoke-IntuneRemediation
    }
    else {
        Write-Host ""
        Write-Host "Disconnecting from Microsoft Graph..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        Write-Host "Disconnected." -ForegroundColor Green
        Write-Host ""
    }
    return
}
elseif ($executionMode -eq 'MultiDevice') {
    # Multi-device mode with WPF GUI
    $allDevices = Get-AllManagedDevices

    if ($allDevices.Count -eq 0) {
        Write-Host "`nNo Windows devices found in Intune." -ForegroundColor Yellow
        Write-Host "Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        return
    }

    $selectedDevices = Show-DeviceSelectionGui -AllDevices $allDevices

    if ($script:exitRequested) {
        Write-Host "`nExit requested. Disconnecting from Microsoft Graph..." -ForegroundColor Yellow
        Disconnect-MgGraph | Out-Null
        Write-Host "Disconnected. Goodbye!" -ForegroundColor Red
        return
    }

    if (-not $selectedDevices -or $selectedDevices.Count -eq 0) {
        Write-Host "`nNo devices selected. Cancelled. Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        Write-Host "Disconnected." -ForegroundColor Red
        return
    }

    Clear-Host
    Write-Host ""
    Write-Host "[ I R O D ]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Devices Selected" -ForegroundColor Green
    Write-Host "Selected $($selectedDevices.Count) device$(if($selectedDevices.Count -ne 1){'s'}) for remediation" -ForegroundColor White
    Write-Host ""
    Write-Host "Confirm Remediation" -ForegroundColor Yellow
    Write-Host "  Script:  " -NoNewline -ForegroundColor Gray
    Write-Host $selectedScript.displayName -ForegroundColor White
    Write-Host "  Devices: " -NoNewline -ForegroundColor Gray
    Write-Host "$($selectedDevices.Count) selected" -ForegroundColor White
    Write-Host ""
    Write-Host "  This will immediately trigger the remediation script on all selected devices." -ForegroundColor Red
    Write-Host ""

    # Require more verbose confirmation if "Select ALL Devices" was used
    if ($script:AllDevicesSelected) {
        Write-Host "  WARNING: You selected ALL devices. This is a high-impact action." -ForegroundColor Yellow
        Write-Host ""
        $expectedPhrase = "I confirm remediation on all $($selectedDevices.Count) devices"
        Write-Host "  To proceed, type the following phrase exactly:" -ForegroundColor Cyan
        Write-Host "  $expectedPhrase" -ForegroundColor White
        Write-Host ""
        $confirm = Read-Host "Confirmation phrase"

        if ($confirm -ne $expectedPhrase) {
            Write-Host "`nConfirmation phrase did not match. Cancelled." -ForegroundColor Red
            Write-Host "Disconnecting..." -ForegroundColor Red
            Disconnect-MgGraph | Out-Null
            return
        }
    }
    else {
        $confirm = Read-Host "Type YES to proceed"

        if ($confirm -ne 'YES') {
            Write-Host "`nCancelled. Disconnecting..." -ForegroundColor Red
            Disconnect-MgGraph | Out-Null
            return
        }
    }

    # Log to history
    $deviceNamesList = @($selectedDevices | ForEach-Object { $_.DeviceName })
    $currentUser = try { (Get-MgContext).Account } catch { $env:USERNAME }
    Add-IRODHistoryEntry -ScriptId $selectedScript.id -ScriptName $selectedScript.displayName -DeviceNames $deviceNamesList -DeviceCount $selectedDevices.Count -ExecutedBy $currentUser

    # Show progress GUI
    Show-ProgressGui -Devices $selectedDevices -ScriptName $selectedScript.displayName -ScriptId $selectedScript.id

    Clear-Host
    Write-Host ""
    Write-Host "[ I R O D ]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Remediation Completed" -ForegroundColor Green
    Write-Host "All devices have been processed." -ForegroundColor White
}
elseif ($executionMode -eq 'ImportFromFile') {
    # Import from file mode - file path already validated at menu selection
    Write-Host "Loading Intune Devices" -ForegroundColor Cyan
    $allDevices = Get-AllManagedDevices
    
    if ($allDevices.Count -eq 0) {
        Write-Host "`nNo Windows devices found in Intune." -ForegroundColor Yellow
        Write-Host "Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        return
    }
    
    Write-Host "  Found $($allDevices.Count) devices in Intune" -ForegroundColor Green
    Write-Host ""
    Write-Host "Importing from File" -ForegroundColor Cyan
    
    $selectedDevices = Import-DevicesFromFile -FilePath $script:importFilePath -AllDevices $allDevices
    
    if (-not $selectedDevices -or $selectedDevices.Count -eq 0) {
        Write-Host "`nNo devices to process. Cancelled." -ForegroundColor Red
        Write-Host "Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        return
    }
    
    Write-Host ""
    Write-Host "Confirm Remediation" -ForegroundColor Yellow
    Write-Host "  Script:  " -NoNewline -ForegroundColor Gray
    Write-Host $selectedScript.displayName -ForegroundColor White
    Write-Host "  Devices: " -NoNewline -ForegroundColor Gray
    Write-Host "$($selectedDevices.Count) matched from file" -ForegroundColor White
    Write-Host ""
    Write-Host "  This will immediately trigger the remediation script on all matched devices." -ForegroundColor Red
    Write-Host ""
    
    $confirm = Read-Host "Type YES to proceed"
    
    if ($confirm -ne 'YES') {
        Write-Host "`nCancelled. Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        return
    }
    
    # Log to history
    $deviceNamesList = @($selectedDevices | ForEach-Object { $_.DeviceName })
    $currentUser = try { (Get-MgContext).Account } catch { $env:USERNAME }
    Add-IRODHistoryEntry -ScriptId $selectedScript.id -ScriptName $selectedScript.displayName -DeviceNames $deviceNamesList -DeviceCount $selectedDevices.Count -ExecutedBy $currentUser
    
    # Show progress GUI
    Show-ProgressGui -Devices $selectedDevices -ScriptName $selectedScript.displayName -ScriptId $selectedScript.id
    
    Clear-Host
    Write-Host ""
    Write-Host "[ I R O D ]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Remediation Completed" -ForegroundColor Green
    Write-Host "All devices have been processed." -ForegroundColor White
}
else {
    # Single device mode
    Write-Host ""
        Write-Host "Looking Up Device" -ForegroundColor Cyan
    
    $device = Get-DeviceByName -Name $DeviceName

    if (-not $device) {
        Write-Host "`nError: Device '$DeviceName' not found in Intune." -ForegroundColor Red
        Write-Host "Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        return
    }

    Clear-Host
    Write-Host ""
    Write-Host "[ I R O D ]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Device Found" -ForegroundColor Green
    Write-Host "Selected device for remediation:" -ForegroundColor White
    Write-Host ""
    Write-Host "  • $($device.deviceName)" -ForegroundColor White
    Write-Host "    User: $($device.userPrincipalName)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Confirm Remediation" -ForegroundColor Yellow
    Write-Host "  Script:  " -NoNewline -ForegroundColor Gray
    Write-Host $selectedScript.displayName -ForegroundColor White
    Write-Host "  Device: " -NoNewline -ForegroundColor Gray
    Write-Host $device.deviceName -ForegroundColor White
    Write-Host ""
    Write-Host "  This will immediately trigger the remediation script on this device." -ForegroundColor Red
    Write-Host ""

    $confirm = Read-Host "Type YES to proceed"

    if ($confirm -ne 'YES') {
        Write-Host "`nCancelled. Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        return
    }

    # Log to history
    $currentUser = try { (Get-MgContext).Account } catch { $env:USERNAME }
    Add-IRODHistoryEntry -ScriptId $selectedScript.id -ScriptName $selectedScript.displayName -DeviceNames @($device.deviceName) -DeviceCount 1 -ExecutedBy $currentUser

    # Create device object for progress GUI
    $deviceForGui = [PSCustomObject]@{
        Id = $device.id
        DeviceName = $device.deviceName
    }

    # Show progress GUI
    Show-ProgressGui -Devices @($deviceForGui) -ScriptName $selectedScript.displayName -ScriptId $selectedScript.id

    Clear-Host
    Write-Host ""
    Write-Host "[ I R O D ]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Remediation Completed" -ForegroundColor Green
    Write-Host "Device has been processed." -ForegroundColor White
}

# Prompt to run again or exit
Write-Host ""
Write-Host "Next Action" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [R] Run again" -ForegroundColor Green
Write-Host "  [X] Exit" -ForegroundColor Red
Write-Host ""

$runAgain = Read-Host "Choice (R/X)"

if ($runAgain -eq 'R' -or $runAgain -eq 'r') {
    Write-Host ""
    Write-Host "Restarting tool..." -ForegroundColor Cyan
    Write-Host ""
    Invoke-IntuneRemediation
}
else {
    Write-Host ""
    Write-Host "Disconnecting from Microsoft Graph..." -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    Write-Host "Disconnected." -ForegroundColor Green
    Write-Host ""
}
}
