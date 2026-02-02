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
#>

[CmdletBinding()]
param(
    [string]$DeviceName,
    [switch]$MultiDevice,
    [string]$ClientId,
    [string]$TenantId
)

# Import the IROD module
Import-Module "$PSScriptRoot\IROD\IROD.psd1" -Force

# Call the main cmdlet with all parameters
Invoke-IntuneRemediation @PSBoundParameters
