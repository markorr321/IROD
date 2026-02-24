function Get-IRODFavorites {
    <#
    .SYNOPSIS
        Gets the list of favorite remediation script IDs.
    #>
    $configPath = Join-Path $env:APPDATA "IROD"
    $favoritesFile = Join-Path $configPath "favorites.json"
    
    if (Test-Path $favoritesFile) {
        try {
            $content = Get-Content $favoritesFile -Raw | ConvertFrom-Json
            return @($content)
        }
        catch {
            return @()
        }
    }
    return @()
}

function Save-IRODFavorites {
    <#
    .SYNOPSIS
        Saves the list of favorite remediation script IDs.
    #>
    param(
        [string[]]$FavoriteIds
    )
    
    $configPath = Join-Path $env:APPDATA "IROD"
    $favoritesFile = Join-Path $configPath "favorites.json"
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $configPath)) {
        New-Item -Path $configPath -ItemType Directory -Force | Out-Null
    }
    
    $FavoriteIds | ConvertTo-Json | Set-Content $favoritesFile -Force
}

function Add-IRODFavorite {
    <#
    .SYNOPSIS
        Adds a script ID to favorites.
    #>
    param(
        [string]$ScriptId
    )
    
    $favorites = @(Get-IRODFavorites)
    if ($ScriptId -notin $favorites) {
        $favorites += $ScriptId
        Save-IRODFavorites -FavoriteIds $favorites
    }
}

function Remove-IRODFavorite {
    <#
    .SYNOPSIS
        Removes a script ID from favorites.
    #>
    param(
        [string]$ScriptId
    )
    
    $favorites = @(Get-IRODFavorites)
    $favorites = $favorites | Where-Object { $_ -ne $ScriptId }
    Save-IRODFavorites -FavoriteIds @($favorites)
}

function Test-IRODFavorite {
    <#
    .SYNOPSIS
        Tests if a script ID is a favorite.
    #>
    param(
        [string]$ScriptId
    )
    
    $favorites = Get-IRODFavorites
    return $ScriptId -in $favorites
}
