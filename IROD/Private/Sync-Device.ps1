function Sync-Device {
    param([string]$DeviceId)

    $uri = "$script:GraphBaseUrl/deviceManagement/managedDevices/$DeviceId/syncDevice"
    Invoke-Graph -Uri $uri -Method POST
}
