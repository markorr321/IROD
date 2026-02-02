function Connect-ToGraph {
    param(
        [string]$ClientId,
        [string]$TenantId
    )

    Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Green

    $connectParams = @{
        Scopes = @(
            "DeviceManagementConfiguration.Read.All",
            "DeviceManagementManagedDevices.Read.All",
            "DeviceManagementManagedDevices.PrivilegedOperations.All"
        )
        NoWelcome = $true
    }
    if ($ClientId) { $connectParams.ClientId = $ClientId }
    if ($TenantId) { $connectParams.TenantId = $TenantId }

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
