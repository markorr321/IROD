function Import-DevicesFromFile {
    <#
    .SYNOPSIS
        Imports device names from a CSV or text file and matches them to Intune devices.
    .DESCRIPTION
        Reads device names from a file (CSV or TXT) and matches them against the provided
        list of Intune managed devices. Returns matched devices and reports on unmatched names.
    .PARAMETER FilePath
        Path to the CSV or TXT file containing device names.
    .PARAMETER AllDevices
        Array of all Intune managed devices to match against.
    #>
    param(
        [string]$FilePath,
        [array]$AllDevices
    )

    if (-not (Test-Path $FilePath)) {
        Write-Host "  ERROR: File not found: $FilePath" -ForegroundColor Red
        return $null
    }

    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $importedNames = @()

    try {
        if ($extension -eq '.csv') {
            # Try to import as CSV - look for DeviceName or Name column
            $csvData = Import-Csv -Path $FilePath
            
            if ($csvData | Get-Member -Name 'DeviceName' -MemberType NoteProperty) {
                $importedNames = @($csvData | Where-Object { $_.DeviceName } | ForEach-Object { $_.DeviceName.Trim() })
            }
            elseif ($csvData | Get-Member -Name 'Name' -MemberType NoteProperty) {
                $importedNames = @($csvData | Where-Object { $_.Name } | ForEach-Object { $_.Name.Trim() })
            }
            elseif ($csvData | Get-Member -Name 'ComputerName' -MemberType NoteProperty) {
                $importedNames = @($csvData | Where-Object { $_.ComputerName } | ForEach-Object { $_.ComputerName.Trim() })
            }
            elseif ($csvData | Get-Member -Name 'Device' -MemberType NoteProperty) {
                $importedNames = @($csvData | Where-Object { $_.Device } | ForEach-Object { $_.Device.Trim() })
            }
            else {
                # Try first column
                $firstColumn = ($csvData | Get-Member -MemberType NoteProperty | Select-Object -First 1).Name
                if ($firstColumn) {
                    $importedNames = @($csvData | Where-Object { $_.$firstColumn } | ForEach-Object { $_.$firstColumn.Trim() })
                }
            }
        }
        else {
            # Treat as plain text - one device name per line
            $importedNames = @(Get-Content -Path $FilePath | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })
        }
    }
    catch {
        Write-Host "  ERROR: Failed to read file: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }

    # Remove duplicates and empty entries
    $importedNames = @($importedNames | Where-Object { $_ } | Select-Object -Unique)

    if ($importedNames.Count -eq 0) {
        Write-Host "  ERROR: No device names found in file." -ForegroundColor Red
        Write-Host "  For CSV files, use column: DeviceName, Name, ComputerName, or Device" -ForegroundColor Gray
        Write-Host "  For TXT files, use one device name per line" -ForegroundColor Gray
        return $null
    }

    Write-Host "  Found $($importedNames.Count) device name(s) in file" -ForegroundColor Cyan

    # Create lookup table for fast matching (case-insensitive)
    $deviceLookup = @{}
    foreach ($device in $AllDevices) {
        $deviceLookup[$device.deviceName.ToLower()] = $device
    }

    # Match imported names to Intune devices
    $matchedDevices = @()
    $notFoundNames = @()

    foreach ($name in $importedNames) {
        $lowerName = $name.ToLower()
        if ($deviceLookup.ContainsKey($lowerName)) {
            $device = $deviceLookup[$lowerName]
            $matchedDevices += [PSCustomObject]@{
                Id = $device.id
                DeviceName = $device.deviceName
                UserPrincipalName = $device.userPrincipalName
            }
        }
        else {
            $notFoundNames += $name
        }
    }

    # Report results
    Write-Host ""
    Write-Host "  Import Results:" -ForegroundColor Cyan
    Write-Host "    Matched:   " -NoNewline -ForegroundColor Gray
    Write-Host "$($matchedDevices.Count)" -ForegroundColor Green
    Write-Host "    Not Found: " -NoNewline -ForegroundColor Gray
    
    if ($notFoundNames.Count -eq 0) {
        Write-Host "0" -ForegroundColor Green
    }
    else {
        Write-Host "$($notFoundNames.Count)" -ForegroundColor Yellow
    }

    # Show not found devices (up to 10)
    if ($notFoundNames.Count -gt 0) {
        Write-Host ""
        Write-Host "  Devices not found in Intune:" -ForegroundColor Yellow
        $showCount = [Math]::Min($notFoundNames.Count, 10)
        for ($i = 0; $i -lt $showCount; $i++) {
            Write-Host "    - $($notFoundNames[$i])" -ForegroundColor DarkYellow
        }
        if ($notFoundNames.Count -gt 10) {
            Write-Host "    ... and $($notFoundNames.Count - 10) more" -ForegroundColor DarkYellow
        }
    }

    if ($matchedDevices.Count -eq 0) {
        Write-Host ""
        Write-Host "  No matching devices found. Cannot proceed." -ForegroundColor Red
        return $null
    }

    return $matchedDevices
}
