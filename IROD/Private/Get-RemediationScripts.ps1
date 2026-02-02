function Get-RemediationScripts {
    Write-Host "`nFetching remediation scripts..." -ForegroundColor White

    $uri = "$script:GraphBaseUrl/deviceManagement/deviceHealthScripts"
    $response = Invoke-Graph -Uri $uri

    $scripts = @($response.value)

    while ($response.'@odata.nextLink') {
        $response = Invoke-Graph -Uri $response.'@odata.nextLink'
        $scripts += $response.value
    }

    return $scripts
}
