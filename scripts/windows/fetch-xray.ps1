param(
    [string]$Destination = ".\resources\windows\xray.exe"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$destinationPath = [System.IO.Path]::GetFullPath($Destination)
$destinationDir = Split-Path -Parent $destinationPath
New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null

$downloadUrl = "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-windows-64.zip"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sni-xray-" + [System.Guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempRoot "xray.zip"
$extractDir = Join-Path $tempRoot "extract"
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

    $downloadedBinary = Get-ChildItem -Path $extractDir -Recurse -Filter "xray.exe" | Select-Object -First 1
    if (-not $downloadedBinary) {
        throw "xray.exe was not found inside the downloaded archive."
    }

    Copy-Item -Force $downloadedBinary.FullName $destinationPath
    Write-Host "Downloaded xray.exe to $destinationPath"
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Recurse -Force $tempRoot
    }
}
