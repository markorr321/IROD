function Show-IRODHelp {
    <#
    .SYNOPSIS
        Displays comprehensive help for IROD (Intune Remediation On Demand).
    #>
    param(
        [string]$Topic
    )

    $topics = @{
        'overview' = @{
            Title = "IROD Overview"
            Content = @"

  IROD (Intune Remediation On Demand) allows you to trigger Intune 
  Proactive Remediation scripts on-demand for one or more devices.

  Unlike scheduled remediations that run on a fixed schedule, IROD 
  lets you immediately execute remediation scripts when needed.

  Key Features:
    - Single device or multi-device remediation
    - Import devices from CSV/TXT files
    - Favorite scripts for quick access
    - Script preview (detection & remediation code)
    - Parallel execution for large batches (50+ devices)
    - History logging with export capability
    - Export remediation results to CSV

"@
        }
        'modes' = @{
            Title = "Execution Modes"
            Content = @"

  [1] Single Device
      Enter a device name to run remediation on one specific device.
      Useful for troubleshooting individual machines.

  [2] Multi-Device
      Opens a GUI to select multiple devices with:
        - Search/filter by device name or user
        - Pagination for large device lists
        - Select individual, page, or ALL devices
        - Checkbox selection

  [3] Import from File
      Load device names from a file for bulk operations:
        - CSV: Uses column named DeviceName, Name, ComputerName, or Device
        - TXT: One device name per line
      Unmatched devices are reported before proceeding.

  [4] Export Results
      Export remediation results for a script to CSV including:
        - Device name and user
        - Detection state and output
        - Remediation state and output
        - Error details

  [5] View History
      View and export your remediation history (last 30 days).

"@
        }
        'scripts' = @{
            Title = "Script Selection"
            Content = @"

  The script selector GUI provides:

  Search
    Type to filter scripts by name in real-time.

  Favorites (Star Icon)
    Click the star to mark/unmark scripts as favorites.
    Favorites appear at the top of the list.
    Stored in: %APPDATA%\IROD\favorites.json

  Preview Button
    View the detection and remediation PowerShell code.
    Scripts are base64-decoded from Intune.

  Tooltips
    Hover over a script to see its description.

  Columns
    - Script Name: Display name from Intune
    - Publisher: Who published the script
    - Version: Script version number
    - ID: Intune script GUID

"@
        }
        'devices' = @{
            Title = "Device Selection"
            Content = @"

  The device selector GUI provides:

  Search
    Filter devices by name or user principal name.

  Pagination
    Navigate through large device lists using:
    |<  First page
    <   Previous page
    >   Next page
    >|  Last page

  Selection Buttons
    Select ALL Devices - Selects all filtered devices (all pages)
    Select Page        - Selects devices on current page only
    Deselect All       - Clears all selections

  Confirmation
    - Normal selections: Type YES to confirm
    - Select ALL: Requires typing exact phrase with device count
      "I confirm remediation on all X devices"

"@
        }
        'parallel' = @{
            Title = "Parallel Execution"
            Content = @"

  For efficiency with large batches, IROD automatically switches 
  to parallel execution mode:

  Sequential Mode (1-50 devices)
    - Each device processed one at a time
    - Real-time output for each device
    - Easy to follow progress

  Parallel Mode (51+ devices)
    - 10 concurrent API calls
    - ~10x faster than sequential
    - Batch progress updates
    - Failed devices listed at end

  Both modes show:
    - Progress bar
    - Success/failure counts
    - Device-level error messages

"@
        }
        'history' = @{
            Title = "History & Logging"
            Content = @"

  IROD logs every remediation execution:

  Logged Information
    - Timestamp
    - Script name and ID
    - Device count and names
    - Executed by (Graph account)

  Storage Location
    C:\Windows\Temp\IROD_history.json

  Retention
    30 days (entries older than 30 days are automatically purged)

  Export
    From View History menu, press [E] to export to CSV.
    Choose your own path or use the default timestamped filename.

"@
        }
        'config' = @{
            Title = "Configuration"
            Content = @"

  App Registration (Optional)
    By default, IROD uses interactive authentication.
    For automated scenarios, configure an app registration:

    Environment Variables:
      IROD_CLIENTID - Your app registration Client ID
      IROD_TENANTID - Your Azure AD Tenant ID

    Or use the Configure-IROD cmdlet:
      Configure-IROD -ClientId "xxx" -TenantId "yyy"

    Clear configuration:
      Clear-IRODConfig

  Required Permissions
    - DeviceManagementManagedDevices.ReadWrite.All
    - DeviceManagementConfiguration.Read.All

  Files Created
    %APPDATA%\IROD\favorites.json  - Favorite scripts
    C:\Windows\Temp\IROD_history.json - Execution history

"@
        }
        'cmdlets' = @{
            Title = "Available Cmdlets"
            Content = @"

  Invoke-IntuneRemediation
    Main entry point. Run without parameters for interactive menu.
    
    Parameters:
      -DeviceName    Single device mode
      -MultiDevice   Multi-device GUI mode
      -ExportResults Export results mode
      -ClientId      App registration Client ID
      -TenantId      App registration Tenant ID
      -Help          Show cmdlet help

    Examples:
      Invoke-IntuneRemediation
      Invoke-IntuneRemediation -DeviceName "DESKTOP-ABC123"
      Invoke-IntuneRemediation -MultiDevice

  Configure-IROD
    Set up app registration for authentication.
    
    Example:
      Configure-IROD -ClientId "xxx" -TenantId "yyy"

  Clear-IRODConfig
    Remove stored configuration.

  Get-IntuneRemediationResults
    Export remediation results to CSV.
    
    Parameters:
      -RemediationName  Filter by script name
      -CsvPath          Output file path

"@
        }
        'tips' = @{
            Title = "Tips & Best Practices"
            Content = @"

  Performance
    - Use Import from File for large, planned deployments
    - Parallel mode activates automatically for 51+ devices
    - Consider running during off-peak hours for large batches

  Troubleshooting
    - Check Export Results for script output and errors
    - Single device mode is best for testing new scripts
    - View History to audit who ran what and when

  File Import Tips
    - Export device lists from other tools to CSV
    - Remove header row issues by using standard column names
    - Device names are matched case-insensitively

  Favorites
    - Star your most-used scripts for quick access
    - Favorites persist across sessions

  Safety
    - Select ALL requires typing confirmation phrase
    - Always verify device count before confirming
    - Use Export Results to verify script behavior first

"@
        }
    }

    if ($Topic -and $topics.ContainsKey($Topic.ToLower())) {
        $t = $topics[$Topic.ToLower()]
        Write-Host ""
        Write-Host "  $($t.Title)" -ForegroundColor Cyan
        Write-Host $t.Content -ForegroundColor White
        return
    }

    # Show main help menu
    Clear-Host
    Write-Host ""
    Write-Host "[ I R O D ]  Help" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Intune Remediation On Demand" -ForegroundColor DarkCyan
    Write-Host "  Trigger proactive remediation scripts on-demand" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Help Topics:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    [1] Overview        - What is IROD and key features" -ForegroundColor Cyan
    Write-Host "    [2] Execution Modes - Single, Multi, Import, Export" -ForegroundColor Cyan
    Write-Host "    [3] Script Selection - Favorites, preview, search" -ForegroundColor Cyan
    Write-Host "    [4] Device Selection - GUI, pagination, bulk select" -ForegroundColor Cyan
    Write-Host "    [5] Parallel Mode   - Auto-scaling for large batches" -ForegroundColor Cyan
    Write-Host "    [6] History         - Logging and export" -ForegroundColor Cyan
    Write-Host "    [7] Configuration   - App registration, permissions" -ForegroundColor Cyan
    Write-Host "    [8] Cmdlets         - Available commands and parameters" -ForegroundColor Cyan
    Write-Host "    [9] Tips            - Best practices and troubleshooting" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    [A] Show All        - Display all help topics" -ForegroundColor Green
    Write-Host "    [Enter] Return      - Back to main menu" -ForegroundColor Gray
    Write-Host ""

    $topicMap = @{
        '1' = 'overview'
        '2' = 'modes'
        '3' = 'scripts'
        '4' = 'devices'
        '5' = 'parallel'
        '6' = 'history'
        '7' = 'config'
        '8' = 'cmdlets'
        '9' = 'tips'
    }

    do {
        $helpChoice = Read-Host "  Select topic (1-9, A, or Enter)"
        
        if ([string]::IsNullOrWhiteSpace($helpChoice)) {
            return $false  # Return to main menu
        }
        
        if ($helpChoice -eq 'A' -or $helpChoice -eq 'a') {
            # Show all topics
            foreach ($key in @('overview', 'modes', 'scripts', 'devices', 'parallel', 'history', 'config', 'cmdlets', 'tips')) {
                $t = $topics[$key]
                Write-Host ""
                Write-Host "  $($t.Title)" -ForegroundColor Cyan
                Write-Host $t.Content -ForegroundColor White
            }
            Write-Host ""
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host | Out-Null
            return $true  # Show help menu again
        }
        
        if ($topicMap.ContainsKey($helpChoice)) {
            $t = $topics[$topicMap[$helpChoice]]
            Write-Host ""
            Write-Host "  $($t.Title)" -ForegroundColor Cyan
            Write-Host $t.Content -ForegroundColor White
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host | Out-Null
            return $true  # Show help menu again
        }
    } while ($true)
}
