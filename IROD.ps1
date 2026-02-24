#Requires -Version 5.1
<#
.SYNOPSIS
    Backward compatibility wrapper for IROD module.

.DESCRIPTION
    This script provides backward compatibility by importing the IROD module
    and calling the Invoke-IntuneRemediation cmdlet. All parameters are passed through.

.NOTES
    For new usage, consider importing the IROD module directly:
    Import-Module .\IROD\IROD.psd1
    Invoke-IntuneRemediation
    Get-IntuneRemediationResults -CsvPath ".\results.csv"
#>

[CmdletBinding()]
param(
    [string]$DeviceName,
    [switch]$MultiDevice,
    [switch]$ExportResults,
    [string]$ClientId,
    [string]$TenantId,
    [switch]$GetResults,
    [string]$RemediationName,
    [string]$CsvPath
)

# Suppress WAP (Web Account Provider) warning from Microsoft.Graph.Authentication
$WarningPreference = 'SilentlyContinue'

# Import the IROD module
Import-Module "$PSScriptRoot\IROD\IROD.psd1" -Force

# Determine which function to call
if ($GetResults) {
    $resultParams = @{}
    if ($RemediationName) { $resultParams['RemediationName'] = $RemediationName }
    if ($CsvPath) { $resultParams['CsvPath'] = $CsvPath }
    else { $resultParams['CsvPath'] = ".\RemediationResults.csv" }
    Get-IntuneRemediationResults @resultParams
}
else {
    # Call the main remediation cmdlet with relevant parameters
    $invokeParams = @{}
    if ($DeviceName) { $invokeParams['DeviceName'] = $DeviceName }
    if ($MultiDevice) { $invokeParams['MultiDevice'] = $true }
    if ($ExportResults) { $invokeParams['ExportResults'] = $true }
    if ($ClientId) { $invokeParams['ClientId'] = $ClientId }
    if ($TenantId) { $invokeParams['TenantId'] = $TenantId }
    Invoke-IntuneRemediation @invokeParams
}
