Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function Show-DeviceSelectionGui {
    param([array]$AllDevices)

    $script:SelectedDevices = @()
    $script:AllDevicesSelected = $false
    $script:CurrentPage = 1
    $script:AllDeviceObjects = @()
    $script:FilteredDeviceObjects = @()

    # Get theme colors
    $t = Get-IRODThemeColors

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Select Devices for Remediation" Height="600" Width="900"
        WindowStartupLocation="CenterScreen" Topmost="True"
        Background="$($t.WindowBackground)">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="$($t.ButtonBackground)"/>
            <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
            <Setter Property="BorderBrush" Value="$($t.Border)"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$($t.ButtonHover)"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="$($t.ControlBackground)"/>
            <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
            <Setter Property="BorderBrush" Value="$($t.Border)"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CaretBrush" Value="$($t.TextPrimary)"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
        </Style>
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="$($t.ListBackground)"/>
            <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
            <Setter Property="BorderBrush" Value="$($t.Border)"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="RowBackground" Value="$($t.ControlBackground)"/>
            <Setter Property="AlternatingRowBackground" Value="$($t.ControlBackgroundAlt)"/>
            <Setter Property="GridLinesVisibility" Value="None"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="$($t.HeaderBackground)"/>
            <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
            <Setter Property="BorderBrush" Value="$($t.Border)"/>
            <Setter Property="BorderThickness" Value="0,0,1,1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
        <Style TargetType="DataGridCell">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="$($t.SelectedBackground)"/>
                    <Setter Property="Foreground" Value="$($t.SelectedText)"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="DataGridRow">
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$($t.ListItemHover)"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="$($t.SelectedBackground)"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
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
                       Margin="5,5,0,0" Foreground="$($t.TextPlaceholder)" IsHitTestVisible="False"
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
                <Button Name="SelectAllDevicesBtn" Content="✓ Select ALL Devices" Width="160" Margin="0,0,8,0" FontSize="13" Padding="10,8">
                    <Button.Style>
                        <Style TargetType="Button">
                            <Setter Property="Background" Value="#2E8B57"/>
                            <Setter Property="Foreground" Value="White"/>
                            <Setter Property="BorderBrush" Value="#3E9B67"/>
                            <Setter Property="BorderThickness" Value="1"/>
                            <Setter Property="Cursor" Value="Hand"/>
                            <Style.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="#3E9B67"/>
                                </Trigger>
                            </Style.Triggers>
                        </Style>
                    </Button.Style>
                </Button>
                <Button Name="SelectAllPageBtn" Content="✓ Select Page" Width="120" Margin="0,0,8,0" FontSize="13" Padding="10,8"/>
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
    $selectAllDevicesBtn = $window.FindName("SelectAllDevicesBtn")
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

    $selectAllDevicesBtn.Add_Click({
        # Select ALL filtered devices across all pages
        $script:AllDevicesSelected = $true
        foreach ($item in $script:FilteredDeviceObjects) {
            $item.IsSelected = $true
        }
        $deviceGrid.Items.Refresh()
        Update-SelectionCount
    })

    $selectAllPageBtn.Add_Click({
        foreach ($item in $deviceGrid.ItemsSource) {
            $item.IsSelected = $true
        }
        $deviceGrid.Items.Refresh()
        Update-SelectionCount
    })

    $deselectAllBtn.Add_Click({
        $script:AllDevicesSelected = $false
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
