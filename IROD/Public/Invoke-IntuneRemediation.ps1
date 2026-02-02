function Invoke-IntuneRemediation {
<#
.SYNOPSIS
    Trigger Intune Proactive Remediation scripts on-demand for single or multiple devices.

.DESCRIPTION
    Connects to Microsoft Graph, lists your remediation scripts, and lets you trigger the selected one
    on target devices. Supports single device mode or multi-device mode with a WPF GUI featuring pagination.

.PARAMETER DeviceName
    The name of a specific device to run remediation on. When specified, runs in single device mode.

.PARAMETER MultiDevice
    Switch to enable multi-device mode with a WPF GUI for selecting multiple devices.

.PARAMETER ClientId
    Client ID of the app registration to use for authentication. If not provided, checks IROD_CLIENTID environment variable.

.PARAMETER TenantId
    Tenant ID to use with the specified app registration. If not provided, checks IROD_TENANTID environment variable.

.EXAMPLE
    Invoke-IntuneRemediation
    Runs in interactive mode, prompting you to choose between single device or multi-device mode.

.EXAMPLE
    Invoke-IntuneRemediation -DeviceName "DESKTOP-ABC123"
    Runs remediation on a single device.

.EXAMPLE
    Invoke-IntuneRemediation -MultiDevice
    Opens WPF GUI to select multiple devices for remediation.

.NOTES
    Requires Microsoft.Graph.Authentication module (will be installed automatically if missing).
    Requires appropriate Microsoft Graph permissions.
#>

    [CmdletBinding()]
    param(
        [string]$DeviceName,
        [switch]$MultiDevice,
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
    Write-Host "[ I R O D ]" -ForegroundColor Cyan
    Write-Host ""

    # Determine execution mode FIRST
$executionMode = $null

if ($MultiDevice) {
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
    Write-Host "  [Q] Quit" -ForegroundColor Red
    Write-Host ""

    do {
        $choice = Read-Host "Enter choice (1, 2, or Q)"
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
    } while ($choice -ne '1' -and $choice -ne '2')

    if ($choice -eq '1') {
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
$scriptItems = $scripts | Select-Object displayName, id | Sort-Object displayName

$columns = @(
    @{ Header = "Script Name"; Property = "displayName"; Width = 550 }
    @{ Header = "ID"; Property = "id"; Width = 300 }
)

$selectedScript = Show-GridSelector -Items $scriptItems -Title "Select Remediation Script" -Columns $columns

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
if ($executionMode -eq 'MultiDevice') {
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
    Write-Host ""
    Write-Host "Devices Selected" -ForegroundColor Green
    Write-Host "Selected $($selectedDevices.Count) device$(if($selectedDevices.Count -ne 1){'s'}) for remediation:" -ForegroundColor White
    Write-Host ""
    foreach ($device in $selectedDevices) {
        Write-Host "  • $($device.DeviceName)" -ForegroundColor White
        Write-Host "    User: $($device.UserPrincipalName)" -ForegroundColor DarkGray
    }

    # Confirm
    Write-Host ""
        Write-Host "Confirm Remediation" -ForegroundColor Yellow
        Write-Host "  Script:  " -NoNewline -ForegroundColor Gray
    Write-Host $selectedScript.displayName -ForegroundColor White
    Write-Host "  Devices: " -NoNewline -ForegroundColor Gray
    Write-Host "$($selectedDevices.Count) selected" -ForegroundColor White
    Write-Host ""
    Write-Host "  This will immediately trigger the remediation script on all selected devices." -ForegroundColor Red
    Write-Host ""

    $confirm = Read-Host "Type YES to proceed"

    if ($confirm -ne 'YES') {
        Write-Host "`nCancelled. Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        return
    }

    # Show progress GUI
    Show-ProgressGui -Devices $selectedDevices -ScriptName $selectedScript.displayName -ScriptId $selectedScript.id

    Clear-Host
    Write-Host ""
    Write-Host "[ I R O D ]" -ForegroundColor Cyan
    Write-Host ""
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
    Write-Host ""
    Write-Host "Device Found" -ForegroundColor Green
    Write-Host "Selected device for remediation:" -ForegroundColor White
    Write-Host ""
    Write-Host "  • $($device.deviceName)" -ForegroundColor White
    Write-Host "    User: $($device.userPrincipalName)" -ForegroundColor DarkGray

    # Confirm
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
