function Get-AllManagedDevices {
    # Only get Windows devices since remediation scripts only apply to Windows
    # Include azureADDeviceId for group-based device matching
    $uri = "$script:GraphBaseUrl/deviceManagement/managedDevices?`$select=id,deviceName,userPrincipalName,operatingSystem,complianceState,lastSyncDateTime,azureADDeviceId&`$filter=operatingSystem eq 'Windows'"

    $response = Invoke-Graph -Uri $uri
    $devices = @($response.value)

    while ($response.'@odata.nextLink') {
        $response = Invoke-Graph -Uri $response.'@odata.nextLink'
        $devices += $response.value
    }

    return $devices | Sort-Object deviceName
}
