function Get-AzureADGroups {
    <#
    .SYNOPSIS
        Retrieves Entra ID security groups that can contain devices.
    .DESCRIPTION
        Fetches groups from Microsoft Graph that are security-enabled,
        which can be used to target device remediations.
    #>
    param(
        [string]$SearchFilter
    )

    # Get security groups (these can contain devices)
    # Filter for security groups only, exclude Microsoft 365 groups
    $uri = "$script:GraphBaseUrl/groups?`$select=id,displayName,description,membershipRule,groupTypes,securityEnabled&`$filter=securityEnabled eq true&`$top=999&`$orderby=displayName"

    $response = Invoke-Graph -Uri $uri
    $groups = @($response.value)

    while ($response.'@odata.nextLink') {
        $response = Invoke-Graph -Uri $response.'@odata.nextLink'
        $groups += $response.value
    }

    # Add a friendly type indicator
    $groups | ForEach-Object {
        $groupType = if ($_.membershipRule) { "Dynamic" } else { "Assigned" }
        $_ | Add-Member -NotePropertyName "GroupType" -NotePropertyValue $groupType -Force
    }

    return $groups | Sort-Object displayName
}
