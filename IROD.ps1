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
$script:exitRequested = $false

#region Module Check
function Install-RequiredModules {
    $requiredModules = @('Microsoft.Graph.Authentication')

    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            Write-Host "Module '$module' not found. Installing..." -ForegroundColor Yellow
            try {
                Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
                Write-Host "Module '$module' installed successfully." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to install '$module': $_" -ForegroundColor Red
                Write-Host "Please run: Install-Module $module -Scope CurrentUser" -ForegroundColor Yellow
                exit 1
            }
        }
    }
}

Install-RequiredModules
#endregion

#region Authentication
function Connect-ToGraph {
    param([string]$TenantId, [switch]$UseDeviceCode)

    Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Green

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
        Connect-MgGraph @connectParams -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        $context = Get-MgContext
        Write-Host "Connected as: $($context.Account)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Auth failed: $_" -ForegroundColor Red
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
    Write-Host "`nFetching remediation scripts..." -ForegroundColor White

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
    # Only get Windows devices since remediation scripts only apply to Windows
    $uri = "$script:GraphBaseUrl/deviceManagement/managedDevices?`$select=id,deviceName,userPrincipalName,operatingSystem,complianceState,lastSyncDateTime&`$filter=operatingSystem eq 'Windows'"

    $response = Invoke-Graph -Uri $uri
    $devices = @($response.value)

    while ($response.'@odata.nextLink') {
        $response = Invoke-Graph -Uri $response.'@odata.nextLink'
        $devices += $response.value
    }

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
function Show-GridSelector {
    param (
        [Parameter(Mandatory)]
        [array]$Items,
        [string]$Title = "Select Item",
        [array]$Columns,
        [switch]$MultiSelect
    )

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    $script:selectorItems = [System.Collections.ArrayList]::new($Items)
    $script:filteredItems = [System.Collections.ArrayList]::new($Items)
    $script:exitRequested = $false

    # Build column XAML
    $columnXaml = ""
    foreach ($col in $Columns) {
        $columnXaml += "<GridViewColumn Header=`"$($col.Header)`" Width=`"$($col.Width)`" DisplayMemberBinding=`"{Binding $($col.Property)}`"/>`n"
    }

    $selectionMode = if ($MultiSelect) { "Extended" } else { "Single" }

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="600" Width="900" WindowStartupLocation="CenterScreen" Topmost="True"
        Background="#1E1E1E">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3E3E42"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
    </Window.Resources>
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBox Name="SearchBox" Grid.Row="0" Margin="0,0,0,15" Padding="8" FontSize="14"/>
        <TextBlock Grid.Row="0" Margin="10,8,0,0" Foreground="#808080" IsHitTestVisible="False" Name="SearchPlaceholder" FontSize="14">Search...</TextBlock>

        <ListView Name="ItemList" Grid.Row="1" SelectionMode="$selectionMode"
                  Background="#252526" Foreground="White" BorderBrush="#3F3F46" BorderThickness="1">
            <ListView.Resources>
                <Style TargetType="GridViewColumnHeader">
                    <Setter Property="Background" Value="#2D2D30"/>
                    <Setter Property="Foreground" Value="White"/>
                    <Setter Property="BorderBrush" Value="#3F3F46"/>
                    <Setter Property="BorderThickness" Value="0,0,1,1"/>
                    <Setter Property="Padding" Value="8,6"/>
                    <Setter Property="FontWeight" Value="SemiBold"/>
                </Style>
                <Style TargetType="ListViewItem">
                    <Setter Property="Background" Value="Transparent"/>
                    <Setter Property="Foreground" Value="White"/>
                    <Setter Property="Padding" Value="8,4"/>
                    <Style.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#2D2D30"/>
                        </Trigger>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter Property="Background" Value="#094771"/>
                            <Setter Property="Foreground" Value="White"/>
                        </Trigger>
                    </Style.Triggers>
                </Style>
            </ListView.Resources>
            <ListView.View>
                <GridView>
                    $columnXaml
                </GridView>
            </ListView.View>
        </ListView>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
            <Button Name="ExitBtn" Content="Exit Tool" Width="90" Margin="0,0,10,0">
                <Button.Style>
                    <Style TargetType="Button">
                        <Setter Property="Background" Value="#C42B1C"/>
                        <Setter Property="Foreground" Value="White"/>
                        <Setter Property="BorderBrush" Value="#A52A2A"/>
                        <Setter Property="BorderThickness" Value="1"/>
                        <Setter Property="Padding" Value="12,6"/>
                        <Setter Property="FontSize" Value="13"/>
                        <Setter Property="Cursor" Value="Hand"/>
                        <Style.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#D13438"/>
                            </Trigger>
                        </Style.Triggers>
                    </Style>
                </Button.Style>
            </Button>
            <Button Name="OkBtn" Content="OK" Width="90" Margin="0,0,10,0" IsDefault="True">
                <Button.Style>
                    <Style TargetType="Button">
                        <Setter Property="Background" Value="#0E639C"/>
                        <Setter Property="Foreground" Value="White"/>
                        <Setter Property="BorderBrush" Value="#0C5086"/>
                        <Setter Property="BorderThickness" Value="1"/>
                        <Setter Property="Padding" Value="12,6"/>
                        <Setter Property="FontSize" Value="13"/>
                        <Setter Property="Cursor" Value="Hand"/>
                        <Style.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#1177BB"/>
                            </Trigger>
                        </Style.Triggers>
                    </Style>
                </Button.Style>
            </Button>
            <Button Name="CancelBtn" Content="Cancel" Width="90" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    $searchBox = $window.FindName("SearchBox")
    $searchPlaceholder = $window.FindName("SearchPlaceholder")
    $listView = $window.FindName("ItemList")
    $exitBtn = $window.FindName("ExitBtn")
    $okBtn = $window.FindName("OkBtn")
    $cancelBtn = $window.FindName("CancelBtn")

    $listView.ItemsSource = $script:filteredItems

    # Allow space key in search box
    $window.Add_PreviewKeyDown({
        param($src, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Space) {
            $focused = [System.Windows.Input.Keyboard]::FocusedElement
            if ($focused -eq $searchBox) {
                $caretIndex = $searchBox.CaretIndex
                $searchBox.Text = $searchBox.Text.Insert($caretIndex, " ")
                $searchBox.CaretIndex = $caretIndex + 1
                $e.Handled = $true
            }
        }
    })

    # Search filter
    $searchBox.Add_TextChanged({
        $searchText = $searchBox.Text.ToLower()
        $searchPlaceholder.Visibility = if ($searchText) { "Collapsed" } else { "Visible" }

        $script:filteredItems.Clear()
        foreach ($item in $script:selectorItems) {
            $match = $false
            foreach ($col in $Columns) {
                $val = $item.($col.Property)
                if ($val -and $val.ToString().ToLower().Contains($searchText)) {
                    $match = $true
                    break
                }
            }
            if ($match) {
                $null = $script:filteredItems.Add($item)
            }
        }
        $listView.Items.Refresh()
    })

    $script:selectorResult = $null
    $exitBtn.Add_Click({
        $script:selectorResult = $null
        $script:exitRequested = $true
        $window.Close()
    })

    $okBtn.Add_Click({
        if ($MultiSelect) {
            $script:selectorResult = @($listView.SelectedItems)
        } else {
            $script:selectorResult = $listView.SelectedItem
        }
        $window.Close()
    })

    $cancelBtn.Add_Click({
        $script:selectorResult = $null
        $window.Close()
    })

    # Double-click to select (single mode)
    if (-not $MultiSelect) {
        $listView.Add_MouseDoubleClick({
            if ($listView.SelectedItem) {
                $script:selectorResult = $listView.SelectedItem
                $window.Close()
            }
        })
    }

    $null = $window.ShowDialog()
    return $script:selectorResult
}

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
        WindowStartupLocation="CenterScreen" Topmost="True"
        Background="#1E1E1E">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3E3E42"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="White"/>
        </Style>
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="RowBackground" Value="#2D2D30"/>
            <Setter Property="AlternatingRowBackground" Value="#252526"/>
            <Setter Property="GridLinesVisibility" Value="None"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="0,0,1,1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
        <Style TargetType="DataGridCell">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#094771"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="DataGridRow">
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#2D2D30"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#094771"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="White"/>
        </Style>
    </Window.Resources>
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
        <Grid Grid.Row="1" Margin="0,0,0,10">
            <TextBox Name="SearchBox" Width="300" HorizontalAlignment="Left" Padding="5" FontSize="14"/>
            <TextBlock Name="SearchPlaceholder" Text="Search devices..."
                       Margin="5,5,0,0" Foreground="#808080" IsHitTestVisible="False"
                       HorizontalAlignment="Left" Width="300"/>
        </Grid>

        <!-- Device Grid -->
        <DataGrid Name="DeviceGrid" Grid.Row="2" AutoGenerateColumns="False"
                  SelectionMode="Single" CanUserAddRows="False"
                  VerticalScrollBarVisibility="Auto" IsReadOnly="True" RowHeight="32">
            <DataGrid.Columns>
                <DataGridTemplateColumn Header="Select" Width="70">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <CheckBox IsChecked="{Binding IsSelected, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}"
                                      HorizontalAlignment="Center" VerticalAlignment="Center" Tag="{Binding Id}"/>
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
                <DataGridTextColumn Header="Device Name" Binding="{Binding DeviceName}" Width="200">
                    <DataGridTextColumn.ElementStyle>
                        <Style TargetType="TextBlock">
                            <Setter Property="Padding" Value="8,0,0,0"/>
                            <Setter Property="VerticalAlignment" Value="Center"/>
                        </Style>
                    </DataGridTextColumn.ElementStyle>
                </DataGridTextColumn>
                <DataGridTextColumn Header="User" Binding="{Binding UserPrincipalName}" Width="240">
                    <DataGridTextColumn.ElementStyle>
                        <Style TargetType="TextBlock">
                            <Setter Property="Padding" Value="8,0,0,0"/>
                            <Setter Property="VerticalAlignment" Value="Center"/>
                        </Style>
                    </DataGridTextColumn.ElementStyle>
                </DataGridTextColumn>
                <DataGridTextColumn Header="Compliance" Binding="{Binding ComplianceState}" Width="110">
                    <DataGridTextColumn.ElementStyle>
                        <Style TargetType="TextBlock">
                            <Setter Property="Padding" Value="8,0,0,0"/>
                            <Setter Property="VerticalAlignment" Value="Center"/>
                        </Style>
                    </DataGridTextColumn.ElementStyle>
                </DataGridTextColumn>
                <DataGridTextColumn Header="Last Sync" Binding="{Binding LastSyncDisplay}" Width="*">
                    <DataGridTextColumn.ElementStyle>
                        <Style TargetType="TextBlock">
                            <Setter Property="Padding" Value="8,0,0,0"/>
                            <Setter Property="VerticalAlignment" Value="Center"/>
                        </Style>
                    </DataGridTextColumn.ElementStyle>
                </DataGridTextColumn>
            </DataGrid.Columns>
        </DataGrid>

        <!-- Pagination -->
        <Grid Grid.Row="3" Margin="0,10,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <TextBlock Name="SelectionCount" Grid.Column="0" Text="0 devices selected" VerticalAlignment="Center" FontWeight="Bold" FontSize="13"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Center">
                <Button Name="FirstPageBtn" Content="⏮ First" Width="70" Margin="2" FontSize="12"/>
                <Button Name="PrevPageBtn" Content="◀ Prev" Width="70" Margin="2" FontSize="12"/>
                <TextBlock Name="PageInfo" Text="Page 1 of 1" VerticalAlignment="Center" Margin="15,0" FontSize="13" FontWeight="SemiBold"/>
                <Button Name="NextPageBtn" Content="Next ▶" Width="70" Margin="2" FontSize="12"/>
                <Button Name="LastPageBtn" Content="Last ⏭" Width="70" Margin="2" FontSize="12"/>
            </StackPanel>
            <TextBlock Name="TotalDevices" Grid.Column="2" Text="Total: 0 devices" VerticalAlignment="Center" HorizontalAlignment="Right" FontSize="13"/>
        </Grid>

        <!-- Action Buttons -->
        <Grid Grid.Row="4" Margin="0,10,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <!-- Left side buttons -->
            <StackPanel Grid.Column="0" Orientation="Horizontal" HorizontalAlignment="Left">
                <Button Name="SelectAllPageBtn" Content="✓ Select All on Page" Width="150" Margin="0,0,8,0" FontSize="13" Padding="10,8"/>
                <Button Name="DeselectAllBtn" Content="✗ Deselect All" Width="120" Margin="0,0,8,0" FontSize="13" Padding="10,8"/>
            </StackPanel>

            <!-- Right side buttons -->
            <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right">
                <Button Name="ExitBtn" Content="Exit Tool" Width="100" Margin="0,0,8,0" FontSize="13" Padding="10,8">
                    <Button.Style>
                        <Style TargetType="Button">
                            <Setter Property="Background" Value="#C42B1C"/>
                            <Setter Property="Foreground" Value="White"/>
                            <Setter Property="BorderBrush" Value="#A52A2A"/>
                            <Setter Property="BorderThickness" Value="1"/>
                            <Setter Property="FontWeight" Value="SemiBold"/>
                            <Setter Property="Cursor" Value="Hand"/>
                            <Style.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="#D13438"/>
                                </Trigger>
                            </Style.Triggers>
                        </Style>
                    </Button.Style>
                </Button>
                <Button Name="CancelBtn" Content="Cancel" Width="100" Margin="0,0,8,0" FontSize="13" Padding="10,8"/>
                <Button Name="ConfirmBtn" Content="Run" Width="100" Margin="0" FontSize="14" Padding="12,10" IsEnabled="False">
                    <Button.Style>
                        <Style TargetType="Button">
                            <Setter Property="Background" Value="#0078D4"/>
                            <Setter Property="Foreground" Value="White"/>
                            <Setter Property="BorderBrush" Value="#005A9E"/>
                            <Setter Property="BorderThickness" Value="1"/>
                            <Setter Property="FontWeight" Value="Bold"/>
                            <Setter Property="Cursor" Value="Hand"/>
                            <Style.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="#1084D8"/>
                                </Trigger>
                                <Trigger Property="IsEnabled" Value="False">
                                    <Setter Property="Background" Value="#3E3E42"/>
                                    <Setter Property="Foreground" Value="#808080"/>
                                    <Setter Property="BorderBrush" Value="#3F3F46"/>
                                </Trigger>
                            </Style.Triggers>
                        </Style>
                    </Button.Style>
                </Button>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    # Get controls
    $searchBox = $window.FindName("SearchBox")
    $searchPlaceholder = $window.FindName("SearchPlaceholder")
    $deviceGrid = $window.FindName("DeviceGrid")
    $pageInfo = $window.FindName("PageInfo")
    $firstPageBtn = $window.FindName("FirstPageBtn")
    $prevPageBtn = $window.FindName("PrevPageBtn")
    $nextPageBtn = $window.FindName("NextPageBtn")
    $lastPageBtn = $window.FindName("LastPageBtn")
    $selectAllPageBtn = $window.FindName("SelectAllPageBtn")
    $deselectAllBtn = $window.FindName("DeselectAllBtn")
    $exitBtn = $window.FindName("ExitBtn")
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

    # Allow space key in search box
    $window.Add_PreviewKeyDown({
        param($src, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Space) {
            $focused = [System.Windows.Input.Keyboard]::FocusedElement
            if ($focused -eq $searchBox) {
                $caretIndex = $searchBox.CaretIndex
                $searchBox.Text = $searchBox.Text.Insert($caretIndex, " ")
                $searchBox.CaretIndex = $caretIndex + 1
                $e.Handled = $true
            }
        }
    })

    # Search box with live filtering and placeholder
    $searchBox.Add_TextChanged({
        $searchText = $searchBox.Text
        $searchPlaceholder.Visibility = if ($searchText) { "Collapsed" } else { "Visible" }
        Apply-Filter
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

    $exitBtn.Add_Click({
        $script:SelectedDevices = @()
        $script:exitRequested = $true
        $window.DialogResult = $false
        $window.Close()
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
        WindowStartupLocation="CenterScreen" Topmost="True"
        Background="#1E1E1E">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3E3E42"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#3E3E42"/>
                    <Setter Property="Foreground" Value="#808080"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="White"/>
        </Style>
        <Style TargetType="ProgressBar">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#0E639C"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="ListBoxItem">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="Transparent"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#2D2D30"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#094771"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>
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
            Write-Host "`nExiting." -ForegroundColor Gray
            exit 0
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
            exit 1
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
if (-not (Connect-ToGraph -TenantId $TenantId -UseDeviceCode:$UseDeviceCode)) {
    Write-Host "`nAuthentication failed. Exiting." -ForegroundColor Red
    exit 1
}

# Get and display scripts
Write-Host ""
Write-Host "Loading Remediation Scripts" -ForegroundColor Cyan

$scripts = Get-RemediationScripts

if ($scripts.Count -eq 0) {
    Write-Host "`nNo remediation scripts found in Intune." -ForegroundColor Yellow
    Write-Host "Disconnecting..." -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    exit 0
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
    exit 0
}

if (-not $selectedScript) {
    Write-Host "`nCancelled. Disconnecting from Microsoft Graph..." -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    Write-Host "Disconnected." -ForegroundColor Red
    exit 0
}

# Handle based on mode
if ($executionMode -eq 'MultiDevice') {
    # Multi-device mode with WPF GUI
    $allDevices = Get-AllManagedDevices

    if ($allDevices.Count -eq 0) {
        Write-Host "`nNo Windows devices found in Intune." -ForegroundColor Yellow
        Write-Host "Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        exit 0
    }

    $selectedDevices = Show-DeviceSelectionGui -AllDevices $allDevices

    if ($script:exitRequested) {
        Write-Host "`nExit requested. Disconnecting from Microsoft Graph..." -ForegroundColor Yellow
        Disconnect-MgGraph | Out-Null
        Write-Host "Disconnected. Goodbye!" -ForegroundColor Red
        exit 0
    }

    if (-not $selectedDevices -or $selectedDevices.Count -eq 0) {
        Write-Host "`nNo devices selected. Cancelled. Disconnecting..." -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        Write-Host "Disconnected." -ForegroundColor Red
        exit 0
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
        exit 0
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
        exit 1
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
        exit 0
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
    & $PSCommandPath
}
else {
    Write-Host ""
    Write-Host "Disconnecting from Microsoft Graph..." -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    Write-Host "Disconnected." -ForegroundColor Green
    Write-Host ""
}
#endregion

