$ErrorActionPreference = "Stop"

$backendPath = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $backendPath ".env"
$examplePath = Join-Path $backendPath ".env.example"

if (-not (Test-Path -LiteralPath $envPath)) {
    Copy-Item -LiteralPath $examplePath -Destination $envPath
    Write-Host "Created backend\.env from backend\.env.example."
    Write-Host "Fill in the required application secrets before starting Docker."
    exit 0
}

$lines = @(Get-Content -LiteralPath $envPath)
$changed = $false

if (-not ($lines -match "^HTTPS_ENABLED=")) {
    $lines += "HTTPS_ENABLED=true"
    $changed = $true
}

if (-not ($lines -match "^HTTPS_AUTO_GENERATE_DEV_CERT=")) {
    $lines += "HTTPS_AUTO_GENERATE_DEV_CERT=true"
    $changed = $true
}

if ($changed) {
    Set-Content -LiteralPath $envPath -Value $lines -Encoding UTF8
    Write-Host "Added missing local HTTPS settings to backend\.env."
} else {
    Write-Host "Local HTTPS settings are already present in backend\.env."
}
