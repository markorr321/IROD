# IROD PowerShell Module
# Intune Remediation On Demand

# Module-level variables
$script:GraphBaseUrl = "https://graph.microsoft.com/beta"
$script:AccessToken = $null
$script:PageSize = 50
$script:exitRequested = $false
$script:Version = (Import-PowerShellDataFile "$PSScriptRoot\IROD.psd1").ModuleVersion

# Load WPF assemblies (used by GUI functions)
Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue
Add-Type -AssemblyName WindowsBase -ErrorAction SilentlyContinue

# Dot-source Private functions
$privateFunctions = @(
    'Install-RequiredModules'
    'Connect-ToGraph'
    'Invoke-Graph'
    'Get-RemediationScripts'
    'Get-AllManagedDevices'
    'Get-DeviceByName'
    'Invoke-Remediation'
    'Sync-Device'
    'Show-GridSelector'
    'Show-DeviceSelectionGui'
    'Show-ProgressGui'
    'Test-IRODUpdate'
    'Show-UpdateNotification'
    'Get-IRODFavorites'
    'Get-IRODHistory'
    'Import-DevicesFromFile'
    'Show-IRODHelp'
    'Show-SaveFileDialog'
    'Get-IRODTheme'
)

foreach ($function in $privateFunctions) {
    $functionPath = Join-Path $PSScriptRoot "Private\$function.ps1"
    if (Test-Path $functionPath) {
        . $functionPath
    }
}

# Dot-source Public functions
$publicFunctions = @(
    'Invoke-IntuneRemediation'
    'Configure-IROD'
    'Clear-IRODConfig'
    'Get-IntuneRemediationResults'
)

foreach ($function in $publicFunctions) {
    $functionPath = Join-Path $PSScriptRoot "Public\$function.ps1"
    if (Test-Path $functionPath) {
        . $functionPath
    }
}

# Install required modules on module import
Install-RequiredModules

# Export only public functions
Export-ModuleMember -Function $publicFunctions
