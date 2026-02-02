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
