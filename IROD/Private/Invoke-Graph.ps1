function Invoke-Graph {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [object]$Body
    )

    $params = @{ Method = $Method; Uri = $Uri }
    if ($Body) { $params.Body = $Body | ConvertTo-Json -Depth 10 }

    return Invoke-MgGraphRequest @params
}
