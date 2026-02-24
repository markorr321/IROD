function Show-SaveFileDialog {
    <#
    .SYNOPSIS
        Shows a Windows Save File dialog for selecting export path.
    .PARAMETER DefaultFileName
        The default filename to use.
    .PARAMETER Title
        The dialog title.
    .PARAMETER Filter
        The file filter (e.g., "CSV Files (*.csv)|*.csv").
    .PARAMETER InitialDirectory
        The initial directory to open.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DefaultFileName = "export.csv",
        
        [Parameter(Mandatory = $false)]
        [string]$Title = "Save As",
        
        [Parameter(Mandatory = $false)]
        [string]$Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*",
        
        [Parameter(Mandatory = $false)]
        [string]$InitialDirectory = [Environment]::GetFolderPath('Desktop')
    )
    
    Add-Type -AssemblyName System.Windows.Forms
    
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Title = $Title
    $saveDialog.Filter = $Filter
    $saveDialog.FileName = $DefaultFileName
    $saveDialog.InitialDirectory = $InitialDirectory
    $saveDialog.OverwritePrompt = $true
    $saveDialog.AddExtension = $true
    $saveDialog.DefaultExt = "csv"
    
    $result = $saveDialog.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $saveDialog.FileName
    }
    
    return $null
}

function Show-OpenFileDialog {
    <#
    .SYNOPSIS
        Shows a Windows Open File dialog for selecting a file to import.
    .PARAMETER Title
        The dialog title.
    .PARAMETER Filter
        The file filter (e.g., "CSV Files (*.csv)|*.csv").
    .PARAMETER InitialDirectory
        The initial directory to open.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Title = "Open",
        
        [Parameter(Mandatory = $false)]
        [string]$Filter = "CSV Files (*.csv)|*.csv|Text Files (*.txt)|*.txt|All Files (*.*)|*.*",
        
        [Parameter(Mandatory = $false)]
        [string]$InitialDirectory = [Environment]::GetFolderPath('Desktop')
    )
    
    Add-Type -AssemblyName System.Windows.Forms
    
    $openDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openDialog.Title = $Title
    $openDialog.Filter = $Filter
    $openDialog.InitialDirectory = $InitialDirectory
    $openDialog.CheckFileExists = $true
    $openDialog.CheckPathExists = $true
    
    $result = $openDialog.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $openDialog.FileName
    }
    
    return $null
}
