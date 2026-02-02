function Invoke-Remediation {
    param(
        [string]$ScriptId,
        [string]$DeviceId
    )

    $uri = "$script:GraphBaseUrl/deviceManagement/managedDevices/$DeviceId/initiateOnDemandProactiveRemediation"
    $body = @{ scriptPolicyId = $ScriptId }

    Invoke-Graph -Uri $uri -Method POST -Body $body
}
