#Requires -Version 5.1
<#
.SYNOPSIS
    List and trigger Intune Remediation Scripts on-demand for single or multiple devices.

.DESCRIPTION
    Connects to Microsoft Graph, lists your remediation scripts, and lets you trigger the selected one.
    Supports single device mode or multi-device mode with a WPF GUI featuring pagination.

.EXAMPLE
    .\RunRemediationOnDemand.ps1 -DeviceName "DESKTOP-ABC123"
    Runs remediation on a single device.

.EXAMPLE
    .\RunRemediationOnDemand.ps1 -MultiDevice
    Opens WPF GUI to select multiple devices for remediation.
#>

[CmdletBinding()]
param(
    [string]$DeviceName,
    [switch]$MultiDevice,
    [string]$TenantId,
    [switch]$UseDeviceCode
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$script:GraphBaseUrl = "https://graph.microsoft.com/beta"
$script:AccessToken = $null
$script:PageSize = 50

#region Authentication
function Connect-ToGraph {
    param([string]$TenantId, [switch]$UseDeviceCode)

    Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Cyan

    if (Get-Module -Name Microsoft.Graph.Authentication -ListAvailable) {
        $connectParams = @{
            Scopes = @(
                "DeviceManagementConfiguration.Read.All",
                "DeviceManagementManagedDevices.Read.All",
                "DeviceManagementManagedDevices.PrivilegedOperations.All"
            )
            NoWelcome = $true
        }
        if ($TenantId) { $connectParams.TenantId = $TenantId }
        if ($UseDeviceCode) { $connectParams.UseDeviceCode = $true }

        try {
            Connect-MgGraph @connectParams -ErrorAction Stop | Out-Null
            $context = Get-MgContext
            Write-Host "Connected as: $($context.Account)" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "Auth failed: $_" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "Microsoft.Graph module not found. Install it with:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph.Authentication -Scope CurrentUser" -ForegroundColor White
        return $false
    }
}

function Invoke-Graph {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [object]$Body
    )

    $params = @{ Method = $Method; Uri = $Uri }
    if ($Body) { $params.Body = $Body | ConvertTo-Json -Depth 10 }

    return Invoke-MgGraphRequest @params
}
#endregion

#region Core Functions
function Get-RemediationScripts {
    Write-Host "`nFetching remediation scripts..." -ForegroundColor Gray

    $uri = "$script:GraphBaseUrl/deviceManagement/deviceHealthScripts"
    $response = Invoke-Graph -Uri $uri

    $scripts = @($response.value)

    while ($response.'@odata.nextLink') {
        $response = Invoke-Graph -Uri $response.'@odata.nextLink'
        $scripts += $response.value
    }

    return $scripts
}

function Get-AllManagedDevices {
    Write-Host "Fetching Windows devices..." -ForegroundColor Gray

    # Only get Windows devices since remediation scripts only apply to Windows
    $uri = "$script:GraphBaseUrl/deviceManagement/managedDevices?`$select=id,deviceName,userPrincipalName,operatingSystem,complianceState,lastSyncDateTime&`$filter=operatingSystem eq 'Windows'"

    $response = Invoke-Graph -Uri $uri
    $devices = @($response.value)

    while ($response.'@odata.nextLink') {
        Write-Host "  Fetching more devices..." -ForegroundColor Gray
        $response = Invoke-Graph -Uri $response.'@odata.nextLink'
        $devices += $response.value
    }

    Write-Host "  Found $($devices.Count) Windows devices" -ForegroundColor Gray
    return $devices | Sort-Object deviceName
}

function Get-DeviceByName {
    param([string]$Name)

    Write-Host "Looking up device '$Name'..." -ForegroundColor Gray

    $uri = "$script:GraphBaseUrl/deviceManagement/managedDevices?`$filter=deviceName eq '$Name'"
    $response = Invoke-Graph -Uri $uri

    if ($response.value -and $response.value.Count -gt 0) {
        return $response.value[0]
    }
    return $null
}

function Invoke-Remediation {
    param(
        [string]$ScriptId,
        [string]$DeviceId
    )

    $uri = "$script:GraphBaseUrl/deviceManagement/managedDevices/$DeviceId/initiateOnDemandProactiveRemediation"
    $body = @{ scriptPolicyId = $ScriptId }

    Invoke-Graph -Uri $uri -Method POST -Body $body
}

function Sync-Device {
    param([string]$DeviceId)

    $uri = "$script:GraphBaseUrl/deviceManagement/managedDevices/$DeviceId/syncDevice"
    Invoke-Graph -Uri $uri -Method POST
}
#endregion

#region WPF GUI
function Show-DeviceSelectionGui {
    param([array]$AllDevices)

    $script:SelectedDevices = @()
    $script:CurrentPage = 1
    $script:AllDeviceObjects = @()
    $script:FilteredDeviceObjects = @()

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Select Devices for Remediation" Height="600" Width="900"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <TextBlock Grid.Row="0" Text="Select Devices for Remediation" FontSize="18" FontWeight="Bold" Margin="0,0,0,10"/>

        <!-- Search -->
        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,10">
            <TextBox Name="SearchBox" Width="300" Margin="0,0,10,0" VerticalContentAlignment="Center"/>
            <Button Name="SearchButton" Content="Search" Width="80" Margin="0,0,5,0"/>
            <Button Name="ClearButton" Content="Clear" Width="80"/>
        </StackPanel>

        <!-- Device Grid -->
        <DataGrid Name="DeviceGrid" Grid.Row="2" AutoGenerateColumns="False"
                  SelectionMode="Single" CanUserAddRows="False"
                  VerticalScrollBarVisibility="Auto" IsReadOnly="True">
            <DataGrid.Columns>
                <DataGridTemplateColumn Header="Select" Width="60">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <CheckBox IsChecked="{Binding IsSelected, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}"
                                      HorizontalAlignment="Center" VerticalAlignment="Center" Tag="{Binding Id}"/>
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
                <DataGridTextColumn Header="Device Name" Binding="{Binding DeviceName}" Width="180"/>
                <DataGridTextColumn Header="User" Binding="{Binding UserPrincipalName}" Width="220"/>
                <DataGridTextColumn Header="Compliance" Binding="{Binding ComplianceState}" Width="100"/>
                <DataGridTextColumn Header="Last Sync" Binding="{Binding LastSyncDisplay}" Width="*"/>
            </DataGrid.Columns>
        </DataGrid>

        <!-- Pagination -->
        <Grid Grid.Row="3" Margin="0,10,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <TextBlock Name="SelectionCount" Grid.Column="0" Text="0 devices selected" VerticalAlignment="Center" FontWeight="Bold"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Center">
                <Button Name="FirstPageBtn" Content="&lt;&lt;" Width="40" Margin="2"/>
                <Button Name="PrevPageBtn" Content="&lt;" Width="40" Margin="2"/>
                <TextBlock Name="PageInfo" Text="Page 1 of 1" VerticalAlignment="Center" Margin="10,0"/>
                <Button Name="NextPageBtn" Content="&gt;" Width="40" Margin="2"/>
                <Button Name="LastPageBtn" Content="&gt;&gt;" Width="40" Margin="2"/>
            </StackPanel>
            <TextBlock Name="TotalDevices" Grid.Column="2" Text="Total: 0 devices" VerticalAlignment="Center" HorizontalAlignment="Right"/>
        </Grid>

        <!-- Action Buttons -->
        <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="SelectAllPageBtn" Content="Select All on Page" Width="120" Margin="5"/>
            <Button Name="DeselectAllBtn" Content="Deselect All" Width="100" Margin="5"/>
            <Button Name="CancelBtn" Content="Cancel" Width="80" Margin="5"/>
            <Button Name="ConfirmBtn" Content="Run Remediation" Width="120" Margin="5" IsEnabled="False"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    # Get controls
    $searchBox = $window.FindName("SearchBox")
    $searchButton = $window.FindName("SearchButton")
    $clearButton = $window.FindName("ClearButton")
    $deviceGrid = $window.FindName("DeviceGrid")
    $pageInfo = $window.FindName("PageInfo")
    $firstPageBtn = $window.FindName("FirstPageBtn")
    $prevPageBtn = $window.FindName("PrevPageBtn")
    $nextPageBtn = $window.FindName("NextPageBtn")
    $lastPageBtn = $window.FindName("LastPageBtn")
    $selectAllPageBtn = $window.FindName("SelectAllPageBtn")
    $deselectAllBtn = $window.FindName("DeselectAllBtn")
    $cancelBtn = $window.FindName("CancelBtn")
    $confirmBtn = $window.FindName("ConfirmBtn")
    $selectionCount = $window.FindName("SelectionCount")
    $totalDevices = $window.FindName("TotalDevices")

    # Create device objects with selection state
    foreach ($device in $AllDevices) {
        $lastSync = if ($device.lastSyncDateTime) {
            ([DateTime]$device.lastSyncDateTime).ToString("yyyy-MM-dd HH:mm")
        } else { "Never" }

        $obj = [PSCustomObject]@{
            Id = $device.id
            DeviceName = $device.deviceName
            UserPrincipalName = $device.userPrincipalName
            OperatingSystem = $device.operatingSystem
            ComplianceState = $device.complianceState
            LastSyncDateTime = $device.lastSyncDateTime
            LastSyncDisplay = $lastSync
            IsSelected = $false
        }
        $script:AllDeviceObjects += $obj
    }

    $script:FilteredDeviceObjects = $script:AllDeviceObjects

    # Functions
    function Update-SelectionCount {
        $count = ($script:AllDeviceObjects | Where-Object { $_.IsSelected -eq $true }).Count
        $selectionCount.Text = "$count device$(if($count -ne 1){'s'}) selected"
        $confirmBtn.IsEnabled = $count -gt 0
    }

    function Update-DeviceGrid {
        $totalPages = [Math]::Max(1, [Math]::Ceiling($script:FilteredDeviceObjects.Count / $script:PageSize))
        $script:CurrentPage = [Math]::Min($script:CurrentPage, $totalPages)
        $script:CurrentPage = [Math]::Max(1, $script:CurrentPage)

        $startIndex = ($script:CurrentPage - 1) * $script:PageSize
        $pageDevices = @($script:FilteredDeviceObjects | Select-Object -Skip $startIndex -First $script:PageSize)

        $deviceGrid.ItemsSource = $pageDevices
        $pageInfo.Text = "Page $($script:CurrentPage) of $totalPages"
        $totalDevices.Text = "Total: $($script:FilteredDeviceObjects.Count) devices"

        # Update pagination buttons
        $firstPageBtn.IsEnabled = $script:CurrentPage -gt 1
        $prevPageBtn.IsEnabled = $script:CurrentPage -gt 1
        $nextPageBtn.IsEnabled = $script:CurrentPage -lt $totalPages
        $lastPageBtn.IsEnabled = $script:CurrentPage -lt $totalPages
    }

    function Apply-Filter {
        $filterText = $searchBox.Text.Trim().ToLower()
        if ([string]::IsNullOrEmpty($filterText)) {
            $script:FilteredDeviceObjects = $script:AllDeviceObjects
        } else {
            $script:FilteredDeviceObjects = @($script:AllDeviceObjects | Where-Object {
                $_.DeviceName -like "*$filterText*" -or $_.UserPrincipalName -like "*$filterText*"
            })
        }
        $script:CurrentPage = 1
        Update-DeviceGrid
    }

    # Event handlers
    $searchButton.Add_Click({ Apply-Filter })

    $searchBox.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            Apply-Filter
        }
    })

    $clearButton.Add_Click({
        $searchBox.Text = ""
        $script:FilteredDeviceObjects = $script:AllDeviceObjects
        $script:CurrentPage = 1
        Update-DeviceGrid
    })

    $firstPageBtn.Add_Click({
        $script:CurrentPage = 1
        Update-DeviceGrid
    })

    $prevPageBtn.Add_Click({
        if ($script:CurrentPage -gt 1) {
            $script:CurrentPage--
            Update-DeviceGrid
        }
    })

    $nextPageBtn.Add_Click({
        $totalPages = [Math]::Ceiling($script:FilteredDeviceObjects.Count / $script:PageSize)
        if ($script:CurrentPage -lt $totalPages) {
            $script:CurrentPage++
            Update-DeviceGrid
        }
    })

    $lastPageBtn.Add_Click({
        $script:CurrentPage = [Math]::Max(1, [Math]::Ceiling($script:FilteredDeviceObjects.Count / $script:PageSize))
        Update-DeviceGrid
    })

    $selectAllPageBtn.Add_Click({
        foreach ($item in $deviceGrid.ItemsSource) {
            $item.IsSelected = $true
        }
        $deviceGrid.Items.Refresh()
        Update-SelectionCount
    })

    $deselectAllBtn.Add_Click({
        foreach ($item in $script:AllDeviceObjects) {
            $item.IsSelected = $false
        }
        $deviceGrid.Items.Refresh()
        Update-SelectionCount
    })

    $cancelBtn.Add_Click({
        $script:SelectedDevices = @()
        $window.DialogResult = $false
        $window.Close()
    })

    $confirmBtn.Add_Click({
        $script:SelectedDevices = @($script:AllDeviceObjects | Where-Object { $_.IsSelected -eq $true })
        $window.DialogResult = $true
        $window.Close()
    })

    # Handle checkbox clicks
    $deviceGrid.Add_PreviewMouseLeftButtonUp({
        param($s, $e)
        $source = $e.OriginalSource

        if ($source -is [System.Windows.Controls.Primitives.ToggleButton] -or
            $source.TemplatedParent -is [System.Windows.Controls.CheckBox]) {

            $row = [System.Windows.Controls.DataGridRow]::GetRowContainingElement($source)
            if ($row -and $row.Item) {
                $item = $row.Item
                # Toggle the selection
                $item.IsSelected = -not $item.IsSelected
                $deviceGrid.Items.Refresh()
                Update-SelectionCount
            }
        }
    })

    # Initialize
    Update-DeviceGrid
    Update-SelectionCount

    $result = $window.ShowDialog()

    if ($result -and $script:SelectedDevices.Count -gt 0) {
        return $script:SelectedDevices
    }
    return $null
}

function Show-ProgressGui {
    param(
        [array]$Devices,
        [string]$ScriptName,
        [string]$ScriptId
    )

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Running Remediation" Height="450" Width="650"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,15">
            <TextBlock Text="Running Remediation Script" FontSize="16" FontWeight="Bold"/>
            <TextBlock Name="ScriptNameText" FontSize="12" Margin="0,5,0,0"/>
        </StackPanel>

        <!-- Progress Bar -->
        <StackPanel Grid.Row="1" Margin="0,0,0,15">
            <ProgressBar Name="ProgressBar" Height="20" Minimum="0" Maximum="100" Value="0"/>
            <TextBlock Name="ProgressText" Text="0 / 0 devices processed"
                       HorizontalAlignment="Center" Margin="0,8,0,0"/>
        </StackPanel>

        <!-- Results List -->
        <ListBox Name="ResultsList" Grid.Row="2" FontFamily="Consolas" FontSize="11"
                 ScrollViewer.VerticalScrollBarVisibility="Auto"/>

        <!-- Close Button -->
        <Button Name="CloseBtn" Grid.Row="3" Content="Close" Width="100" Height="30"
                HorizontalAlignment="Right" Margin="0,10,0,0" IsEnabled="False"/>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    $scriptNameText = $window.FindName("ScriptNameText")
    $progressBar = $window.FindName("ProgressBar")
    $progressText = $window.FindName("ProgressText")
    $resultsList = $window.FindName("ResultsList")
    $closeBtn = $window.FindName("CloseBtn")

    $scriptNameText.Text = "Script: $ScriptName"
    $progressBar.Maximum = $Devices.Count

    $closeBtn.Add_Click({
        $window.Close()
    })

    # Process devices asynchronously
    $window.Add_ContentRendered({
        $total = $Devices.Count
        $completed = 0
        $succeeded = 0
        $failed = 0

        foreach ($device in $Devices) {
            $deviceName = $device.DeviceName
            $deviceId = $device.Id

            $resultsList.Items.Add("[$(Get-Date -Format 'HH:mm:ss')] Processing: $deviceName...")
            $resultsList.ScrollIntoView($resultsList.Items[$resultsList.Items.Count - 1])
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)

            try {
                Invoke-Remediation -ScriptId $ScriptId -DeviceId $deviceId
                Sync-Device -DeviceId $deviceId
                $resultsList.Items.Add("[$(Get-Date -Format 'HH:mm:ss')] SUCCESS: $deviceName - Remediation triggered and sync initiated")
                $succeeded++
            }
            catch {
                $resultsList.Items.Add("[$(Get-Date -Format 'HH:mm:ss')] FAILED: $deviceName - $($_.Exception.Message)")
                $failed++
            }

            $completed++
            $progressBar.Value = $completed
            $progressText.Text = "$completed / $total devices processed"
            $resultsList.ScrollIntoView($resultsList.Items[$resultsList.Items.Count - 1])
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
        }

        $resultsList.Items.Add("")
        $resultsList.Items.Add("=" * 60)
        $resultsList.Items.Add("COMPLETED: $succeeded succeeded, $failed failed out of $total devices")
        $resultsList.Items.Add("=" * 60)
        $resultsList.ScrollIntoView($resultsList.Items[$resultsList.Items.Count - 1])

        $closeBtn.IsEnabled = $true
        $closeBtn.Focus()
    })

    $window.ShowDialog() | Out-Null
}
#endregion

#region Main
Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Intune Remediation On Demand" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Determine execution mode FIRST
$executionMode = $null

if ($MultiDevice) {
    $executionMode = 'MultiDevice'
}
elseif ($DeviceName) {
    $executionMode = 'SingleDevice'
}
else {
    # Prompt user to choose mode
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  SELECT EXECUTION MODE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Single Device  - Run remediation on one device" -ForegroundColor White
    Write-Host "  [2] Multi-Device   - Select multiple devices via GUI" -ForegroundColor White
    Write-Host ""

    do {
        $choice = Read-Host "Enter choice (1 or 2)"
    } while ($choice -ne '1' -and $choice -ne '2')

    if ($choice -eq '1') {
        $executionMode = 'SingleDevice'
        $DeviceName = Read-Host "`nEnter device name"
        if ([string]::IsNullOrWhiteSpace($DeviceName)) {
            Write-Host "`nNo device name provided. Exiting." -ForegroundColor Red
            exit 1
        }
    }
    else {
        $executionMode = 'MultiDevice'
    }
}

# Connect
if (-not (Connect-ToGraph -TenantId $TenantId -UseDeviceCode:$UseDeviceCode)) {
    exit 1
}

# Get and display scripts
$scripts = Get-RemediationScripts

if ($scripts.Count -eq 0) {
    Write-Host "`nNo remediation scripts found in Intune." -ForegroundColor Yellow
    exit 0
}

# Select script via Out-GridView
$selectedScript = $scripts |
    Select-Object displayName, id |
    Out-GridView -Title "Select Remediation Script" -OutputMode Single

if (-not $selectedScript) {
    Write-Host "`nCancelled." -ForegroundColor Gray
    exit 0
}

Write-Host "`nSelected: " -NoNewline
Write-Host $selectedScript.displayName -ForegroundColor Green

# Handle based on mode
if ($executionMode -eq 'MultiDevice') {
    # Multi-device mode with WPF GUI
    Write-Host "`nLoading devices..." -ForegroundColor Cyan

    $allDevices = Get-AllManagedDevices

    if ($allDevices.Count -eq 0) {
        Write-Host "`nNo Windows devices found in Intune." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Opening device selection GUI..." -ForegroundColor Gray

    $selectedDevices = Show-DeviceSelectionGui -AllDevices $allDevices

    if (-not $selectedDevices -or $selectedDevices.Count -eq 0) {
        Write-Host "`nNo devices selected. Cancelled." -ForegroundColor Gray
        exit 0
    }

    Write-Host "`nSelected $($selectedDevices.Count) device(s) for remediation:" -ForegroundColor Green
    foreach ($device in $selectedDevices) {
        Write-Host "  - $($device.DeviceName) ($($device.UserPrincipalName))" -ForegroundColor White
    }

    # Confirm
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "  CONFIRM MULTI-DEVICE REMEDIATION" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Script: $($selectedScript.displayName)" -ForegroundColor White
    Write-Host "  Devices: $($selectedDevices.Count) selected" -ForegroundColor White
    Write-Host ""

    $confirm = Read-Host "Type YES to trigger remediation on all selected devices"

    if ($confirm -ne 'YES') {
        Write-Host "`nAborted." -ForegroundColor Gray
        exit 0
    }

    # Show progress GUI
    Show-ProgressGui -Devices $selectedDevices -ScriptName $selectedScript.displayName -ScriptId $selectedScript.id

    Write-Host "`nDone! Remediation process completed." -ForegroundColor Cyan
}
else {
    # Single device mode (original behavior)
    $device = Get-DeviceByName -Name $DeviceName

    if (-not $device) {
        Write-Host "`nDevice '$DeviceName' not found in Intune." -ForegroundColor Red
        exit 1
    }

    Write-Host "Target: $($device.deviceName) ($($device.userPrincipalName))" -ForegroundColor Green

    # Confirm
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "  CONFIRM REMEDIATION" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Script: $($selectedScript.displayName)" -ForegroundColor White
    Write-Host "  Device: $($device.deviceName)" -ForegroundColor White
    Write-Host ""

    $confirm = Read-Host "Trigger now? (Y/N)"

    if ($confirm -ne 'Y' -and $confirm -ne 'y') {
        Write-Host "`nAborted." -ForegroundColor Gray
        exit 0
    }

    # Execute
    Write-Host "`nTriggering remediation..." -ForegroundColor Yellow

    try {
        Invoke-Remediation -ScriptId $selectedScript.id -DeviceId $device.id
        Write-Host "Remediation triggered" -ForegroundColor Green

        Write-Host "Syncing device..." -ForegroundColor Yellow
        Sync-Device -DeviceId $device.id
        Write-Host "Sync initiated" -ForegroundColor Green

        Write-Host "`nDone! Remediation will run on '$DeviceName' shortly." -ForegroundColor Cyan
    }
    catch {
        Write-Host "`n[ERROR] $_" -ForegroundColor Red
    }
}

# Prompt to run again or exit
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  [R] Run again" -ForegroundColor White
Write-Host "  [X] Exit" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan

$runAgain = Read-Host "Choice"

if ($runAgain -eq 'R' -or $runAgain -eq 'r') {
    Write-Host "`nRestarting..." -ForegroundColor Cyan
    & $PSCommandPath
}
else {
    Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Gray
    Disconnect-MgGraph | Out-Null
    Write-Host "Disconnected. Goodbye!" -ForegroundColor Gray
}
#endregion
