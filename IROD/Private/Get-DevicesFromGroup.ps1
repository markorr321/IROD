function Get-DevicesFromGroup {
    <#
    .SYNOPSIS
        Retrieves Windows devices that are members of an Entra ID group.
    .DESCRIPTION
        Uses transitive members to include devices from nested groups.
        Filters to only return device objects, then matches them against
        Intune managed devices.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$GroupId,
        
        [Parameter(Mandatory)]
        [array]$AllManagedDevices
    )

    # Get transitive members (includes nested groups) filtered to devices only
    $uri = "$script:GraphBaseUrl/groups/$GroupId/transitiveMembers/microsoft.graph.device?`$select=id,displayName,deviceId&`$top=999"

    $response = Invoke-Graph -Uri $uri
    $groupDevices = @($response.value)

    while ($response.'@odata.nextLink') {
        $response = Invoke-Graph -Uri $response.'@odata.nextLink'
        $groupDevices += $response.value
    }

    if ($groupDevices.Count -eq 0) {
        return @()
    }

    # Build a hashtable of Entra ID device IDs for fast lookup
    $azureDeviceIds = @{}
    foreach ($device in $groupDevices) {
        # The deviceId property is the Entra ID device ID that matches azureADDeviceId in Intune
        if ($device.deviceId) {
            $azureDeviceIds[$device.deviceId] = $device.displayName
        }
    }

    # Match against Intune managed devices
    # Intune devices have azureADDeviceId property that corresponds to Entra ID deviceId
    $matchedDevices = @()
    foreach ($managedDevice in $AllManagedDevices) {
        if ($managedDevice.azureADDeviceId -and $azureDeviceIds.ContainsKey($managedDevice.azureADDeviceId)) {
            $matchedDevices += [PSCustomObject]@{
                Id                = $managedDevice.id
                DeviceName        = $managedDevice.deviceName
                UserPrincipalName = $managedDevice.userPrincipalName
                ComplianceState   = $managedDevice.complianceState
                LastSyncDateTime  = $managedDevice.lastSyncDateTime
            }
        }
    }

    return $matchedDevices | Sort-Object DeviceName
}
