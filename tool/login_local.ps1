param([Parameter(Mandatory = $true)][string]$ApiEnvFile, [switch]$SelectMedia, [switch]$VerifyMedia, [switch]$VerifyPlayback)
$ErrorActionPreference = 'Stop'
if (@($SelectMedia, $VerifyMedia, $VerifyPlayback).Where({ $_.IsPresent }).Count -gt 1) { throw 'Choose one operation: SelectMedia, VerifyMedia or VerifyPlayback.' }
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$previousTokenFile = $env:TG_CINE_RELAY_TOKEN_FILE
$env:TG_CINE_RELAY_TOKEN_FILE = Join-Path $repoRoot '.cache/deployment/relay-token.txt'
Push-Location $repoRoot
$nativeVerificationExitCode = 1
try {
    $operation = if ($VerifyPlayback) { '--verify-playback' } elseif ($VerifyMedia) { '--verify-media' } elseif ($SelectMedia) { '--select-media' } else { '--login' }
    & dart run tool/telegram_login.dart `
        (Join-Path $repoRoot '.cache/native/build-windows/Release/tdjson.dll') `
        (Join-Path $repoRoot '.cache/deployment/relay-bridge.json') `
        ([IO.Path]::GetFullPath($ApiEnvFile)) $operation
    $nativeVerificationExitCode = $LASTEXITCODE
    if ($nativeVerificationExitCode -ne 0) {
        Write-Host 'Local Telegram verification did not complete. Check config and connection; never send codes or passwords to chat.'
    }
} finally {
    Pop-Location
    $env:TG_CINE_RELAY_TOKEN_FILE = $previousTokenFile
}
if ($VerifyMedia -or $VerifyPlayback) { exit $nativeVerificationExitCode }
