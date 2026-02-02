function Install-RequiredModules {
    $requiredModules = @('Microsoft.Graph.Authentication')

    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            Write-Host "Module '$module' not found. Installing..." -ForegroundColor Yellow
            try {
                Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
                Write-Host "Module '$module' installed successfully." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to install '$module': $_" -ForegroundColor Red
                Write-Host "Please run: Install-Module $module -Scope CurrentUser" -ForegroundColor Yellow
                exit 1
            }
        }
    }
}
