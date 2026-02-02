Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

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
