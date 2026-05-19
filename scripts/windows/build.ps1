param(
  [switch]$RunAfterBuild,
  [switch]$RunAsAdmin
)

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

$pythonExe = $null
$pythonArgs = @()
if (Get-Command python.exe -ErrorAction SilentlyContinue) {
    $pythonExe = "python"
} elseif (Get-Command py.exe -ErrorAction SilentlyContinue) {
    $pythonExe = "py"
    $pythonArgs = @("-3.11")
} else {
    throw "Python 3.11 was not found. Install it with: winget install --id Python.Python.3.11 -e"
}

& $pythonExe @pythonArgs -m pip install -r requirements.txt
& $pythonExe @pythonArgs -m pip install pyinstaller
& $pythonExe @pythonArgs -m PyInstaller `
  --noconfirm `
  --clean `
  --windowed `
  --name "SNI-Spoofing" `
  --collect-submodules PySide6 `
  --hidden-import pydivert `
  --add-data "resources/windows;resources/windows" `
  main.py

$builtExe = Join-Path (Get-Location) "dist\SNI-Spoofing\SNI-Spoofing.exe"
if ($RunAfterBuild) {
  if (-not (Test-Path $builtExe)) {
    throw "Build finished but executable was not found at $builtExe"
  }
  if ($RunAsAdmin) {
    Start-Process -FilePath $builtExe -Verb RunAs
  } else {
    Start-Process -FilePath $builtExe
  }
}
