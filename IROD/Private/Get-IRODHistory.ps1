function Get-IRODHistory {
    <#
    .SYNOPSIS
        Gets the remediation history log.
    #>
    param(
        [int]$Limit = 0
    )
    
    $historyFile = Join-Path $env:windir "Temp\IROD_history.json"
    
    if (Test-Path $historyFile) {
        try {
            $content = Get-Content $historyFile -Raw | ConvertFrom-Json
            $history = @($content)
            
            if ($Limit -gt 0 -and $history.Count -gt $Limit) {
                return $history | Select-Object -Last $Limit
            }
            return $history
        }
        catch {
            return @()
        }
    }
    return @()
}

function Add-IRODHistoryEntry {
    <#
    .SYNOPSIS
        Adds an entry to the remediation history log.
    #>
    param(
        [string]$ScriptId,
        [string]$ScriptName,
        [string[]]$DeviceNames,
        [int]$DeviceCount,
        [string]$ExecutedBy
    )
    
    $historyFile = Join-Path $env:windir "Temp\IROD_history.json"
    
    # Get existing history
    $history = @(Get-IRODHistory)
    
    # Create new entry
    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ScriptId = $ScriptId
        ScriptName = $ScriptName
        DeviceCount = $DeviceCount
        DeviceNames = $DeviceNames
        ExecutedBy = $ExecutedBy
    }
    
    # Add to history
    $history += $entry
    
    # Remove entries older than 30 days
    $cutoffDate = (Get-Date).AddDays(-30)
    $history = @($history | Where-Object { 
        try { [datetime]::ParseExact($_.Timestamp, "yyyy-MM-dd HH:mm:ss", $null) -gt $cutoffDate } 
        catch { $true } 
    })
    
    # Save
    $history | ConvertTo-Json -Depth 3 | Set-Content $historyFile -Force
}

function Clear-IRODHistory {
    <#
    .SYNOPSIS
        Clears the remediation history log.
    #>
    $historyFile = Join-Path $env:windir "Temp\IROD_history.json"
    
    if (Test-Path $historyFile) {
        Remove-Item $historyFile -Force
    }
}

function Export-IRODHistory {
    <#
    .SYNOPSIS
        Exports the remediation history to a CSV file.
    #>
    param(
        [string]$Path
    )
    
    $history = Get-IRODHistory
    
    if ($history.Count -eq 0) {
        Write-Host "No history to export." -ForegroundColor Yellow
        return $false
    }
    
    # If path ends with \ or / (directory), append default filename
    if ($Path.EndsWith('\') -or $Path.EndsWith('/')) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $Path = Join-Path $Path "IROD_History_$timestamp.csv"
    }
    
    # Flatten DeviceNames array to comma-separated string for CSV
    $exportData = $history | ForEach-Object {
        [PSCustomObject]@{
            Timestamp = $_.Timestamp
            ScriptName = $_.ScriptName
            ScriptId = $_.ScriptId
            DeviceCount = $_.DeviceCount
            DeviceNames = ($_.DeviceNames -join ", ")
            ExecutedBy = $_.ExecutedBy
        }
    }
    
    $exportData | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host "  Exported to: $Path" -ForegroundColor Green
    return $true
}

function Show-IRODHistory {
    <#
    .SYNOPSIS
        Displays the remediation history in a formatted table.
    #>
    param(
        [int]$Limit = 20
    )
    
    $history = Get-IRODHistory -Limit $Limit
    
    if ($history.Count -eq 0) {
        Write-Host "No remediation history found." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "Remediation History (Last $($history.Count) entries)" -ForegroundColor Cyan
    Write-Host ""
    
    # Display in reverse order (most recent first)
    $reversed = @($history)
    [array]::Reverse($reversed)
    
    foreach ($entry in $reversed) {
        Write-Host "  $($entry.Timestamp)" -ForegroundColor Gray -NoNewline
        Write-Host "  |  " -ForegroundColor DarkGray -NoNewline
        Write-Host "$($entry.ScriptName)" -ForegroundColor White -NoNewline
        Write-Host "  |  " -ForegroundColor DarkGray -NoNewline
        Write-Host "$($entry.DeviceCount) device$(if($entry.DeviceCount -ne 1){'s'})" -ForegroundColor Green -NoNewline
        Write-Host "  |  " -ForegroundColor DarkGray -NoNewline
        Write-Host "$($entry.ExecutedBy)" -ForegroundColor DarkCyan
    }
    Write-Host ""
}
