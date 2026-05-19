# SNI-Spoofing Client

Desktop client for running SNI-based DPI bypass workflows with a production macOS app.

[![Version](https://img.shields.io/badge/version-1.2.2-2563eb.svg)](https://github.com/PK3NZO/SNI-Spoofing-Client/releases)
[![Platform](https://img.shields.io/badge/platform-macOS-111827.svg)](https://github.com/PK3NZO/SNI-Spoofing-Client/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0-16a34a.svg)](LICENSE)

## Preview

![SNI-Spoofing Client overview screenshot](docs/screenshots/app-overview-v1.2.2.jpeg)

![SNI-Spoofing Client workflow screenshot](docs/screenshots/app-workflow-v1.2.2.jpeg)

Live macOS screenshots of the current desktop client UI in `v1.2.2`.

## English

### Overview

SNI-Spoofing Client is a desktop project for advanced censorship-circumvention workflows that rely on SNI spoofing, local proxying, and packet-tunnel based routing.

Current public release target:

- macOS app
- Apple Silicon (`arm64`) build
- Intel (`x86_64`) build
- `VLESS`, `VMess`, `Trojan`, and `Shadowsocks` config parsing
- `Proxy` mode and `Tunnel` mode

Current public platform status:

- macOS:
  - production UI and workflow
  - `Proxy` mode
  - `Tunnel` mode
  - embedded Xray

### Downloads

Download the latest signed release assets from:

- [GitHub Releases](https://github.com/PK3NZO/SNI-Spoofing-Client/releases)

Expected macOS assets for `v1.2.2`:

- `SniSpoofingClient-macos-arm64-v1.2.2.dmg`
- `SniSpoofingClient-macos-x86_64-v1.2.2.dmg`
- `checksums-v1.2.2.txt`

### Features

- Native SwiftUI macOS app
- Clean bilingual UI: English + Persian
- Two connection modes:
  - `Proxy`
  - `Tunnel`
- Embedded Xray runtime per architecture
- Live connection workflow visibility
- Download / upload / total usage cards
- Validation hints for required inputs
- Config parsing for multiple protocols

### macOS Requirements

- macOS 13.3 or newer
- Administrator access for privileged networking actions
- Apple Silicon Mac for `arm64` release
- Intel Mac for `x86_64` release

### Installation

For end users:

1. Download the correct DMG for your Mac architecture.
2. Open the DMG.
3. Drag the app into `Applications`.
4. Launch the app.
5. Grant any required macOS permissions when prompted.

### Build From Source

```bash
cd macos-arm
./generate_xcode_project.sh
./build_debug.sh arm64
./build_debug.sh x86_64
```

Release build helpers:

```bash
cd macos-arm
./build_release.sh arm64
./build_release.sh x86_64
./package_release.sh arm64
./package_release.sh x86_64
./generate_checksums.sh
```

Detailed macOS signing, DMG, and notarization guidance:

- [macOS Release Guide](docs/macos-release-guide.md)

### Reporting Issues

If you hit a bug:

- open a GitHub issue with logs, screenshots, and reproduction steps
- include whether you used `Proxy` or `Tunnel`
- include platform and architecture

### Credits

- Original project direction and release ownership: `PK3NZO`
- Special shoutout: [patterniha/SNI-Spoofing](https://github.com/patterniha/SNI-Spoofing)

---

## فارسی

### معرفی

SNI-Spoofing Client یک پروژه دسکتاپ برای سناریوهای دور زدن DPI با تکیه بر SNI spoofing، لوکال پروکسی، و packet tunnel است.

هدف ریلیز عمومی فعلی:

- اپلیکیشن macOS
- نسخه جدا برای `arm64`
- نسخه جدا برای `x86_64`
- پشتیبانی از لینک‌های `VLESS`، `VMess`، `Trojan` و `Shadowsocks`
- دو حالت اتصال:
  - `Proxy`
  - `Tunnel`

وضعیت فعلی نسخه عمومی:

- macOS:
  - رابط کاربری و workflow اصلی
  - حالت `Proxy`
  - حالت `Tunnel`
  - Xray داخلی

### دانلود

جدیدترین نسخه‌ها از اینجا قابل دریافت هستند:

- [GitHub Releases](https://github.com/PK3NZO/SNI-Spoofing-Client/releases)

نام فایل‌های مورد انتظار برای `v1.2.2`:

- `SniSpoofingClient-macos-arm64-v1.2.2.dmg`
- `SniSpoofingClient-macos-x86_64-v1.2.2.dmg`
- `checksums-v1.2.2.txt`

### قابلیت‌ها

- اپلیکیشن native با SwiftUI
- رابط کاربری دو زبانه: فارسی و انگلیسی
- دو حالت اتصال:
  - `Proxy`
  - `Tunnel`
- Xray داخلی متناسب با معماری سیستم
- نمایش مرحله‌ای workflow اتصال
- نمایش زنده مصرف دانلود، آپلود و مجموع مصرف
- هایلایت ورودی‌های ناقص در زمان validation
- پشتیبانی از چند پروتکل مختلف

### نیازمندی‌ها

- macOS 13.3 به بالا
- دسترسی Administrator برای بعضی عملیات شبکه
- مک Apple Silicon برای نسخه `arm64`
- مک Intel برای نسخه `x86_64`

### نصب

برای کاربران نهایی:

1. فایل DMG مناسب معماری سیستم خود را دانلود کنید.
2. DMG را باز کنید.
3. اپ را به پوشه `Applications` بکشید.
4. برنامه را اجرا کنید.
5. اگر macOS مجوز خواست، آن‌ها را تایید کنید.

### بیلد از سورس

```bash
cd macos-arm
./generate_xcode_project.sh
./build_debug.sh arm64
./build_debug.sh x86_64
```

برای ریلیز:

```bash
cd macos-arm
./build_release.sh arm64
./build_release.sh x86_64
./package_release.sh arm64
./package_release.sh x86_64
./generate_checksums.sh
```

راهنمای کامل ساین، ساخت DMG و notarization:

- [راهنمای انتشار macOS](docs/macos-release-guide.md)

### گزارش باگ

اگر به مشکل خوردید:

- داخل GitHub issue باز کنید
- لاگ، اسکرین‌شات و مراحل بازتولید را بفرستید
- مشخص کنید از `Proxy` استفاده کرده‌اید یا `Tunnel`
- مشخص کنید پلتفرم و معماری شما چیست

### قدردانی

- انتشار و نگهداری پروژه: `PK3NZO`
- تشکر ویژه از: [patterniha/SNI-Spoofing](https://github.com/patterniha/SNI-Spoofing)
