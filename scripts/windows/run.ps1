param(
    [string]$ConfigPath = $null
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($null -ne $ConfigPath -and $ConfigPath.Length -gt 0) {
    python main.py --config $ConfigPath
} else {
    python main.py
}
