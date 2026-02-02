function Get-DeviceByName {
    param([string]$Name)

    Write-Host "Looking up device '$Name'..." -ForegroundColor Gray

    $uri = "$script:GraphBaseUrl/deviceManagement/managedDevices?`$filter=deviceName eq '$Name'"
    $response = Invoke-Graph -Uri $uri

    if ($response.value -and $response.value.Count -gt 0) {
        return $response.value[0]
    }
    return $null
}
