function Get-GroupById {
    <#
    .SYNOPSIS
        Retrieves an Entra ID group by its Object ID.
    .DESCRIPTION
        Fetches a single group from Microsoft Graph using the group's Object ID (GUID).
        Returns null if the group is not found.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$GroupId
    )

    try {
        $uri = "$script:GraphBaseUrl/groups/$GroupId`?`$select=id,displayName,description,membershipRule,groupTypes,securityEnabled"
        $group = Invoke-Graph -Uri $uri
        
        if ($group) {
            # Add GroupType indicator
            $groupType = if ($group.membershipRule) { "Dynamic" } else { "Assigned" }
            $group | Add-Member -NotePropertyName "GroupType" -NotePropertyValue $groupType -Force
            return $group
        }
    }
    catch {
        # Group not found or invalid ID
        return $null
    }
    
    return $null
}
