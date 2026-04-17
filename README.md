# SNI-Spoofing
Bypass DPI with IP/TCP-Header manipulation

## status

- backend e Windows alan ba `pydivert/WinDivert` kar mikone
- port e `macOS arm64` shoru shode va scaffold e `Network Extension` dar [macos-arm/README.md](/Users/pouriarc/Projects/sni/SNI-Spoofing/macos-arm/README.md:1) gharar gerefte
- baraye mac bayad backend e native e `PacketTunnelProvider` takmil beshe
- desktop shell-e jadid baraye Windows-first ba UI-e shared dar hal-e rang-andazi ast

## backend ha

- `windows-pydivert`: backend e feli
- `macos-network-extension`: scaffold e avaliye, hanooz be logic e spoofing وصل نشده
- `desktop`: shell e Qt baraye UI-e one-design / multi-platform

agar `BACKEND` dar `config.json` set نشه, code khodesh ruye Windows backend e WinDivert va ruye mac backend e Network Extension ro entekhab mikone.

baraye run-e UI-e jadid dar Windows:

```bash
python main.py
```

baraye debug/headless:

```bash
python main.py --headless
```

baraye run/build Windows shortcut ham dar [scripts/windows/README.md](/Users/pouriarc/Projects/sni/SNI-Spoofing/scripts/windows/README.md:1) hast.

config-e پیش‌فرض baraye هر user dar location e writable ذخیره می‌شود:

- Windows: `%LOCALAPPDATA%\\SNI-Spoofing\\config.json`
- macOS: `~/Library/Application Support/SNI-Spoofing/config.json`
- Linux: `~/.config/SNI-Spoofing/config.json`

dar `config.json` mituni `LOG_LEVEL` ro ham baraye helper/mac set koni:

- `debug`
- `info`
- `error`

حمایت کنید کارهای بزرگی در دست انجام هست:

USDT (BEP20): 0x76a768B53Ca77B43086946315f0BDF21156bF424

USDT (TRC20): TU5gKvKqcXPn8itp1DouBCwcqGHMemBm8o




https://t.me/projectXhttp

https://t.me/patterniha
