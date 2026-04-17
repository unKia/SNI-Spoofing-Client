Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

python -m pip install -r requirements.txt
python -m pip install pyinstaller
pyinstaller `
  --noconfirm `
  --clean `
  --windowed `
  --name "SNI-Spoofing" `
  --collect-submodules PySide6 `
  --hidden-import pydivert `
  main.py
