param([Parameter(Mandatory = $true)][string]$ApiEnvFile, [string]$Flutter = 'flutter', [switch]$UseExistingSession)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$configDirectory = Join-Path $repo '.cache/deployment'
$configFile = Join-Path $configDirectory 'flutter-telegram.json'
$sessionName = if ($UseExistingSession) { 'dev-account' } else { 'app-account' }
$configuration = @{
    library = Join-Path $repo '.cache/native/build-windows/Release/tdjson.dll'
    apiEnvFile = [IO.Path]::GetFullPath($ApiEnvFile)
    relayConfig = Join-Path $configDirectory 'relay-bridge.json'
    relayTokenFile = Join-Path $configDirectory 'relay-token.txt'
    sessionDirectory = Join-Path $repo ".cache/native/accounts/$sessionName"
    permissionsScript = Join-Path $PSScriptRoot 'support/private_directory.ps1'
}
foreach ($name in @('library', 'apiEnvFile', 'permissionsScript')) {
    if (-not (Test-Path -LiteralPath $configuration[$name] -PathType Leaf)) { throw "Missing local input: $name" }
}
[IO.Directory]::CreateDirectory($configDirectory) | Out-Null
[IO.File]::WriteAllText($configFile, ($configuration | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
Push-Location $repo
try {
    & $Flutter run -d windows --debug "--dart-define=TG_CINE_TELEGRAM_CONFIG=$configFile" --dart-define=TG_CINE_USE_DEFAULT_SERVICE=true
    if ($LASTEXITCODE -ne 0) { throw 'Flutter launch failed; local credentials were not printed.' }
} finally { Pop-Location }
