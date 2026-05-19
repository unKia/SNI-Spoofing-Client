Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path "resources/windows" | Out-Null

$bundledXrayPath = "resources/windows/xray.exe"
$xraySource = $null
$resolvedBundledXrayPath = [System.IO.Path]::GetFullPath($bundledXrayPath)

if (Test-Path $bundledXrayPath) {
    $xraySource = (Resolve-Path $bundledXrayPath).Path
    Write-Host "Using existing bundled xray.exe at $xraySource"
} elseif ($env:XRAY_EXECUTABLE) {
    $xraySource = $env:XRAY_EXECUTABLE
} else {
    $candidate = Get-Command xray.exe -ErrorAction SilentlyContinue
    if ($candidate) {
        $xraySource = $candidate.Source
    }
}

if ($xraySource -and ([System.IO.Path]::GetFullPath($xraySource) -ne $resolvedBundledXrayPath)) {
    Copy-Item -Force $xraySource $bundledXrayPath
    Write-Host "Bundled xray.exe from $xraySource"
} elseif (-not (Test-Path $bundledXrayPath)) {
    Write-Host "xray.exe was not found. Downloading the latest Windows build..."
    & (Join-Path $PSScriptRoot "fetch-xray.ps1") -Destination $bundledXrayPath
}

python -m pip install -r requirements.txt
python -m pip install pyinstaller
pyinstaller `
  --noconfirm `
  --clean `
  --windowed `
  --name "SNI-Spoofing" `
  --collect-submodules PySide6 `
  --hidden-import pydivert `
  --add-data "resources/windows;resources/windows" `
  main.py
