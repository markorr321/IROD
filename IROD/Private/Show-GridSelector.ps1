function Show-GridSelector {
    param (
        [Parameter(Mandatory)]
        [array]$Items,
        [string]$Title = "Select Item",
        [array]$Columns,
        [switch]$MultiSelect,
        [switch]$ShowPreview,
        [switch]$ShowFavorites,
        [string]$TooltipProperty
    )

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    # Get theme colors
    $t = Get-IRODThemeColors

    # If favorites enabled, add IsFavorite property and sort
    if ($ShowFavorites) {
        $favorites = Get-IRODFavorites
        $Items = $Items | ForEach-Object {
            $isFav = $_.id -in $favorites
            $_ | Add-Member -NotePropertyName "IsFavorite" -NotePropertyValue $isFav -PassThru -Force |
                 Add-Member -NotePropertyName "FavoriteDisplay" -NotePropertyValue $(if ($isFav) { "★" } else { "☆" }) -PassThru -Force
        }
        # Sort: favorites first, then alphabetically
        $Items = $Items | Sort-Object @{Expression={-[int]$_.IsFavorite}}, displayName
    }

    $script:selectorItems = [System.Collections.ArrayList]::new($Items)
    $script:filteredItems = [System.Collections.ArrayList]::new($Items)
    $script:exitRequested = $false

    # Build column XAML - add favorite column if enabled
    $columnXaml = ""
    if ($ShowFavorites) {
        $columnXaml += @"
<GridViewColumn Header="★" Width="45">
    <GridViewColumn.CellTemplate>
        <DataTemplate>
            <TextBlock Text="{Binding FavoriteDisplay}" FontSize="16" Foreground="$($t.AccentGreen)" 
                       Cursor="Hand" ToolTip="Click to toggle favorite">
                <TextBlock.Style>
                    <Style TargetType="TextBlock">
                        <Style.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Foreground" Value="$($t.AccentGreenHover)"/>
                            </Trigger>
                        </Style.Triggers>
                    </Style>
                </TextBlock.Style>
            </TextBlock>
        </DataTemplate>
    </GridViewColumn.CellTemplate>
</GridViewColumn>
"@
    }
    foreach ($col in $Columns) {
        $columnXaml += "<GridViewColumn Header=`"$($col.Header)`" Width=`"$($col.Width)`" DisplayMemberBinding=`"{Binding $($col.Property)}`"/>`n"
    }

    $selectionMode = if ($MultiSelect) { "Extended" } else { "Single" }
    
    # Build tooltip setter if property provided
    $tooltipSetter = ""
    if ($TooltipProperty) {
        $tooltipSetter = @"
                    <Setter Property="ToolTipService.ShowDuration" Value="30000"/>
                    <Setter Property="ToolTipService.Placement" Value="Right"/>
                    <Setter Property="ToolTip">
                        <Setter.Value>
                            <ToolTip MaxWidth="500" Background="$($t.TooltipBackground)" BorderBrush="$($t.TooltipBorder)" Padding="10">
                                <TextBlock Text="{Binding $TooltipProperty}" TextWrapping="Wrap" Foreground="$($t.TextPrimary)" FontSize="12"/>
                            </ToolTip>
                        </Setter.Value>
                    </Setter>
"@
    }

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="600" Width="1050" WindowStartupLocation="CenterScreen" Topmost="True"
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
    </Window.Resources>
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBox Name="SearchBox" Grid.Row="0" Margin="0,0,0,15" Padding="8" FontSize="14"/>
        <TextBlock Grid.Row="0" Margin="10,8,0,0" Foreground="$($t.TextPlaceholder)" IsHitTestVisible="False" Name="SearchPlaceholder" FontSize="14">Search...</TextBlock>

        <ListView Name="ItemList" Grid.Row="1" SelectionMode="$selectionMode"
                  Background="$($t.ListBackground)" Foreground="$($t.TextPrimary)" BorderBrush="$($t.Border)" BorderThickness="1">
            <ListView.Resources>
                <Style TargetType="GridViewColumnHeader">
                    <Setter Property="Background" Value="$($t.HeaderBackground)"/>
                    <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
                    <Setter Property="BorderBrush" Value="$($t.Border)"/>
                    <Setter Property="BorderThickness" Value="0,0,1,1"/>
                    <Setter Property="Padding" Value="8,6"/>
                    <Setter Property="FontWeight" Value="SemiBold"/>
                </Style>
                <Style TargetType="ListViewItem">
                    <Setter Property="Background" Value="Transparent"/>
                    <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
                    <Setter Property="Padding" Value="8,4"/>
$tooltipSetter
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
            </ListView.Resources>
            <ListView.View>
                <GridView>
                    $columnXaml
                </GridView>
            </ListView.View>
        </ListView>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
            <Button Name="FavoriteBtn" Content="★ Favorite" Width="90" Margin="0,0,10,0" Visibility="Collapsed">
                <Button.Style>
                    <Style TargetType="Button">
                        <Setter Property="Background" Value="$($t.AccentGreen)"/>
                        <Setter Property="Foreground" Value="White"/>
                        <Setter Property="BorderBrush" Value="$($t.AccentGreenHover)"/>
                        <Setter Property="BorderThickness" Value="1"/>
                        <Setter Property="Padding" Value="12,6"/>
                        <Setter Property="FontSize" Value="13"/>
                        <Setter Property="Cursor" Value="Hand"/>
                        <Style.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="$($t.AccentGreenHover)"/>
                            </Trigger>
                        </Style.Triggers>
                    </Style>
                </Button.Style>
            </Button>
            <Button Name="PreviewBtn" Content="Preview" Width="90" Margin="0,0,10,0" Visibility="Collapsed">
                <Button.Style>
                    <Style TargetType="Button">
                        <Setter Property="Background" Value="#4A4A4D"/>
                        <Setter Property="Foreground" Value="White"/>
                        <Setter Property="BorderBrush" Value="#5A5A5D"/>
                        <Setter Property="BorderThickness" Value="1"/>
                        <Setter Property="Padding" Value="12,6"/>
                        <Setter Property="FontSize" Value="13"/>
                        <Setter Property="Cursor" Value="Hand"/>
                        <Style.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#5A5A5D"/>
                            </Trigger>
                        </Style.Triggers>
                    </Style>
                </Button.Style>
            </Button>
            <Button Name="ExitBtn" Content="Exit Tool" Width="90" Margin="0,0,10,0">
                <Button.Style>
                    <Style TargetType="Button">
                        <Setter Property="Background" Value="$($t.WarningRed)"/>
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
    $favoriteBtn = $window.FindName("FavoriteBtn")
    $previewBtn = $window.FindName("PreviewBtn")
    $exitBtn = $window.FindName("ExitBtn")
    $okBtn = $window.FindName("OkBtn")
    $cancelBtn = $window.FindName("CancelBtn")

    # Show preview button if requested
    if ($ShowPreview) {
        $previewBtn.Visibility = "Visible"
    }

    # Show favorite button if requested
    if ($ShowFavorites) {
        $favoriteBtn.Visibility = "Visible"
    }

    $listView.ItemsSource = $script:filteredItems

    # Handle star clicks for favorites
    if ($ShowFavorites) {
        $listView.Add_PreviewMouseLeftButtonDown({
            param($sender, $e)
            $source = $e.OriginalSource
            
            # Check if clicked on a TextBlock that's a star
            if ($source -is [System.Windows.Controls.TextBlock]) {
                $text = $source.Text
                if ($text -eq "★" -or $text -eq "☆") {
                    # Find the data item
                    $listViewItem = [System.Windows.Media.VisualTreeHelper]::GetParent($source)
                    while ($listViewItem -and $listViewItem -isnot [System.Windows.Controls.ListViewItem]) {
                        $listViewItem = [System.Windows.Media.VisualTreeHelper]::GetParent($listViewItem)
                    }
                    
                    if ($listViewItem) {
                        $item = $listViewItem.DataContext
                        if ($item -and $item.id) {
                            $scriptId = $item.id
                            
                            if ($item.IsFavorite) {
                                Remove-IRODFavorite -ScriptId $scriptId
                                $item.IsFavorite = $false
                                $item.FavoriteDisplay = "☆"
                            }
                            else {
                                Add-IRODFavorite -ScriptId $scriptId
                                $item.IsFavorite = $true
                                $item.FavoriteDisplay = "★"
                            }
                            
                            # Re-sort items
                            $searchText = $searchBox.Text.ToLower()
                            $script:filteredItems.Clear()
                            
                            $sortedItems = $script:selectorItems | Sort-Object @{Expression={-[int]$_.IsFavorite}}, displayName
                            $script:selectorItems.Clear()
                            foreach ($sortedItem in $sortedItems) {
                                $null = $script:selectorItems.Add($sortedItem)
                            }
                            
                            foreach ($sItem in $script:selectorItems) {
                                $match = [string]::IsNullOrEmpty($searchText)
                                if (-not $match) {
                                    foreach ($col in $Columns) {
                                        $val = $sItem.($col.Property)
                                        if ($val -and $val.ToString().ToLower().Contains($searchText)) {
                                            $match = $true
                                            break
                                        }
                                    }
                                }
                                if ($match) {
                                    $null = $script:filteredItems.Add($sItem)
                                }
                            }
                            $listView.Items.Refresh()
                            
                            $e.Handled = $true
                        }
                    }
                }
            }
        })
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

    # Favorite button click handler
    $favoriteBtn.Add_Click({
        $selectedItem = $listView.SelectedItem
        if (-not $selectedItem) {
            [System.Windows.MessageBox]::Show("Please select a script to toggle favorite.", "No Selection", "OK", "Warning")
            return
        }

        $scriptId = $selectedItem.id
        if ($selectedItem.IsFavorite) {
            # Remove from favorites
            Remove-IRODFavorite -ScriptId $scriptId
            $selectedItem.IsFavorite = $false
            $selectedItem.FavoriteDisplay = "☆"
        }
        else {
            # Add to favorites
            Add-IRODFavorite -ScriptId $scriptId
            $selectedItem.IsFavorite = $true
            $selectedItem.FavoriteDisplay = "★"
        }

        # Re-sort and refresh the list
        $searchText = $searchBox.Text.ToLower()
        $script:filteredItems.Clear()
        
        # Get all items sorted with favorites first
        $sortedItems = $script:selectorItems | Sort-Object @{Expression={-[int]$_.IsFavorite}}, displayName
        $script:selectorItems.Clear()
        foreach ($item in $sortedItems) {
            $null = $script:selectorItems.Add($item)
        }
        
        foreach ($item in $script:selectorItems) {
            $match = [string]::IsNullOrEmpty($searchText)
            if (-not $match) {
                foreach ($col in $Columns) {
                    $val = $item.($col.Property)
                    if ($val -and $val.ToString().ToLower().Contains($searchText)) {
                        $match = $true
                        break
                    }
                }
            }
            if ($match) {
                $null = $script:filteredItems.Add($item)
            }
        }
        $listView.Items.Refresh()
        
        # Re-select the item
        $listView.SelectedItem = $selectedItem
    })

    # Preview button click handler
    $previewBtn.Add_Click({
        $selectedItem = $listView.SelectedItem
        if (-not $selectedItem) {
            [System.Windows.MessageBox]::Show("Please select a script to preview.", "No Selection", "OK", "Warning")
            return
        }

        try {
            # Fetch full script details
            $scriptId = $selectedItem.id
            $uri = "$script:GraphBaseUrl/deviceManagement/deviceHealthScripts/$scriptId"
            $scriptDetails = Invoke-Graph -Uri $uri

            # Decode base64 content
            $detectionScript = if ($scriptDetails.detectionScriptContent) {
                [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($scriptDetails.detectionScriptContent))
            } else { "(No detection script)" }

            $remediationScript = if ($scriptDetails.remediationScriptContent) {
                [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($scriptDetails.remediationScriptContent))
            } else { "(No remediation script)" }

            # Create preview window
            $previewXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Script Preview" Height="700" Width="1000"
        WindowStartupLocation="CenterScreen" Background="#1E1E1E">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Name="ScriptTitle" FontSize="16" FontWeight="Bold" Foreground="White" Margin="0,0,0,15"/>
        <TextBlock Grid.Row="1" Text="Detection Script" FontSize="14" FontWeight="Bold" Foreground="#569CD6" Margin="0,0,0,8"/>
        <TextBox Grid.Row="2" Name="DetectionBox" IsReadOnly="True" TextWrapping="NoWrap" AcceptsReturn="True"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                 FontFamily="Consolas" FontSize="12" Background="#252526" Foreground="#D4D4D4"
                 BorderBrush="#3F3F46" Padding="10"/>

        <TextBlock Grid.Row="3" Text="Remediation Script" FontSize="14" FontWeight="Bold" Foreground="#4EC9B0" Margin="0,15,0,8"/>
        <TextBox Grid.Row="4" Name="RemediationBox" IsReadOnly="True" TextWrapping="NoWrap" AcceptsReturn="True"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                 FontFamily="Consolas" FontSize="12" Background="#252526" Foreground="#D4D4D4"
                 BorderBrush="#3F3F46" Padding="10"/>

        <Button Grid.Row="5" Content="Close" Width="100" Height="30" HorizontalAlignment="Right" Margin="0,15,0,0"
                Background="#2D2D30" Foreground="White" BorderBrush="#3F3F46" IsCancel="True"/>
    </Grid>
</Window>
"@

            $previewReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($previewXaml))
            $previewWindow = [System.Windows.Markup.XamlReader]::Load($previewReader)
            
            # Set content programmatically to avoid XML escaping issues
            $previewWindow.Title = "Script Preview - $($selectedItem.displayName)"
            $previewWindow.FindName("ScriptTitle").Text = $selectedItem.displayName
            $previewWindow.FindName("DetectionBox").Text = $detectionScript
            $previewWindow.FindName("RemediationBox").Text = $remediationScript
            
            $previewWindow.Owner = $window
            $null = $previewWindow.ShowDialog()
        }
        catch {
            [System.Windows.MessageBox]::Show("Failed to load script preview: $_", "Error", "OK", "Error")
        }
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
