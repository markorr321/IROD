Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function Show-ProgressGui {
    param(
        [array]$Devices,
        [string]$ScriptName,
        [string]$ScriptId
    )

    $useParallel = $Devices.Count -gt 50
    $concurrency = 10

    # Get theme colors
    $t = Get-IRODThemeColors

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Running Remediation" Height="450" Width="850"
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
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="$($t.ControlBackgroundHover)"/>
                    <Setter Property="Foreground" Value="$($t.TextPlaceholder)"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
        </Style>
        <Style TargetType="ProgressBar">
            <Setter Property="Background" Value="$($t.ControlBackground)"/>
            <Setter Property="Foreground" Value="$($t.AccentGreen)"/>
            <Setter Property="BorderBrush" Value="$($t.Border)"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="$($t.ListBackground)"/>
            <Setter Property="Foreground" Value="$($t.AccentGreen)"/>
            <Setter Property="BorderBrush" Value="$($t.Border)"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="ListBoxItem">
            <Setter Property="Foreground" Value="$($t.SuccessGreen)"/>
            <Setter Property="Background" Value="Transparent"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$($t.ListItemHover)"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="$($t.SelectedBackground)"/>
                    <Setter Property="Foreground" Value="$($t.SelectedText)"/>
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
            <TextBlock Name="ModeText" FontSize="11" Foreground="$($t.TextPlaceholder)" Margin="0,3,0,0"/>
        </StackPanel>

        <!-- Progress Bar -->
        <StackPanel Grid.Row="1" Margin="0,0,0,15">
            <ProgressBar Name="ProgressBar" Height="20" Minimum="0" Maximum="100" Value="0"/>
            <TextBlock Name="ProgressText" Text="0 / 0 devices processed"
                       HorizontalAlignment="Center" Margin="0,8,0,0"/>
        </StackPanel>

        <!-- Results List -->
        <ListBox Name="ResultsList" Grid.Row="2" FontFamily="Consolas" FontSize="14"
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
    $modeText = $window.FindName("ModeText")
    $progressBar = $window.FindName("ProgressBar")
    $progressText = $window.FindName("ProgressText")
    $resultsList = $window.FindName("ResultsList")
    $closeBtn = $window.FindName("CloseBtn")

    $scriptNameText.Text = "Script: $ScriptName"
    $progressBar.Maximum = $Devices.Count

    if ($useParallel) {
        $modeText.Text = "Parallel mode: $concurrency concurrent requests (devices > 50)"
    } else {
        $modeText.Text = "Sequential mode (devices <= 50)"
    }

    $closeBtn.Add_Click({
        $window.Close()
    })

    # Process devices
    $window.Add_ContentRendered({
        $total = $Devices.Count
        $completed = 0
        $succeeded = 0
        $failed = 0
        $failedDevices = @()

        if ($useParallel) {
            # Parallel execution using runspace pool
            $resultsList.Items.Add("[$(Get-Date -Format 'HH:mm:ss')] Starting parallel processing of $total devices...")
            $resultsList.ScrollIntoView($resultsList.Items[$resultsList.Items.Count - 1])
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)

            # Process in batches
            $batchSize = $concurrency
            $batches = [Math]::Ceiling($total / $batchSize)
            
            for ($batchNum = 0; $batchNum -lt $batches; $batchNum++) {
                $startIdx = $batchNum * $batchSize
                $endIdx = [Math]::Min($startIdx + $batchSize - 1, $total - 1)
                $batchDevices = $Devices[$startIdx..$endIdx]
                
                $resultsList.Items.Add("[$(Get-Date -Format 'HH:mm:ss')] Processing batch $($batchNum + 1)/$batches ($($batchDevices.Count) devices)...")
                $resultsList.ScrollIntoView($resultsList.Items[$resultsList.Items.Count - 1])
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)

                # Create runspace pool
                $runspacePool = [runspacefactory]::CreateRunspacePool(1, $concurrency)
                $runspacePool.Open()
                
                $runspaces = @()
                
                foreach ($device in $batchDevices) {
                    $scriptBlock = {
                        param($DeviceId, $DeviceName, $ScriptId, $GraphBaseUrl)
                        
                        try {
                            # Invoke remediation
                            $uri = "$GraphBaseUrl/deviceManagement/managedDevices/$DeviceId/initiateOnDemandProactiveRemediation"
                            $body = @{ scriptPolicyId = $ScriptId } | ConvertTo-Json -Depth 10
                            Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body | Out-Null
                            
                            # Sync device
                            $syncUri = "$GraphBaseUrl/deviceManagement/managedDevices/$DeviceId/syncDevice"
                            Invoke-MgGraphRequest -Method POST -Uri $syncUri | Out-Null
                            
                            return @{ Success = $true; DeviceName = $DeviceName; Error = $null }
                        }
                        catch {
                            return @{ Success = $false; DeviceName = $DeviceName; Error = $_.Exception.Message }
                        }
                    }
                    
                    $powershell = [powershell]::Create().AddScript($scriptBlock)
                    $powershell.AddArgument($device.Id)
                    $powershell.AddArgument($device.DeviceName)
                    $powershell.AddArgument($ScriptId)
                    $powershell.AddArgument($script:GraphBaseUrl)
                    $powershell.RunspacePool = $runspacePool
                    
                    $runspaces += @{
                        PowerShell = $powershell
                        Handle = $powershell.BeginInvoke()
                        DeviceName = $device.DeviceName
                    }
                }
                
                # Wait for batch to complete and collect results
                foreach ($rs in $runspaces) {
                    $result = $rs.PowerShell.EndInvoke($rs.Handle)
                    $rs.PowerShell.Dispose()
                    
                    $completed++
                    
                    if ($result.Success) {
                        $succeeded++
                    } else {
                        $failed++
                        $failedDevices += @{ Name = $result.DeviceName; Error = $result.Error }
                    }
                }
                
                $runspacePool.Close()
                $runspacePool.Dispose()
                
                # Update progress
                $progressBar.Value = $completed
                $progressText.Text = "$completed / $total devices processed (Succeeded: $succeeded | Failed: $failed)"
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
            }
            
            # Show summary
            $resultsList.Items.Add("")
            $resultsList.Items.Add("[$(Get-Date -Format 'HH:mm:ss')] COMPLETED: $succeeded succeeded, $failed failed out of $total devices")
            
            if ($failedDevices.Count -gt 0 -and $failedDevices.Count -le 20) {
                $resultsList.Items.Add("")
                $resultsList.Items.Add("Failed devices:")
                foreach ($fd in $failedDevices) {
                    $resultsList.Items.Add("  - $($fd.Name): $($fd.Error)")
                }
            } elseif ($failedDevices.Count -gt 20) {
                $resultsList.Items.Add("")
                $resultsList.Items.Add("$($failedDevices.Count) devices failed. First 20:")
                foreach ($fd in ($failedDevices | Select-Object -First 20)) {
                    $resultsList.Items.Add("  - $($fd.Name): $($fd.Error)")
                }
            }
            
            $resultsList.ScrollIntoView($resultsList.Items[$resultsList.Items.Count - 1])
        }
        else {
            # Sequential execution (original behavior)
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
            $resultsList.Items.Add("COMPLETED: $succeeded succeeded, $failed failed out of $total devices")
            $resultsList.ScrollIntoView($resultsList.Items[$resultsList.Items.Count - 1])
        }

        $closeBtn.IsEnabled = $true
        $closeBtn.Focus()
    })

    $window.ShowDialog() | Out-Null
}
