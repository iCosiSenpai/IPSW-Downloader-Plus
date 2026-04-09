<div align="center">

# IPSW Downloader Plus

**Native macOS app to browse, download, and manage Apple IPSW firmware** — keeps your local archives up to date with one click.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/iCosiSenpai/IPSW-Downloader-Plus?include_prereleases&label=Release)](https://github.com/iCosiSenpai/IPSW-Downloader-Plus/releases)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift&logoColor=white)](https://swift.org)
[![Tests](https://img.shields.io/badge/Tests-40%2F40-brightgreen?logo=checkmarx&logoColor=white)](#testing)

<br>

[![PayPal](https://img.shields.io/badge/PayPal-Donate-blue?logo=paypal&logoColor=white)](https://paypal.me/AlessioCosi)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-Support-yellow?logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/icosisenpai)

</div>

---

## Features

| | |
|---|---|
| **Device Browser** | Sidebar with search, filters, sorting, quick-select templates, and device type chips |
| **Batch Downloads** | Queue multiple devices, throttled concurrent downloads with progress, ETA, and transfer speed |
| **Smart Storage** | Auto-saves to Apple's default iTunes / Configurator folders, or a custom directory |
| **Integrity Checks** | SHA-256 (preferred) and SHA-1 checksum verification after download |
| **Resume & Retry** | Interrupted downloads resume automatically; transient failures retry with exponential backoff |
| **Firmware Updates** | Detects when newer firmware is available for locally downloaded versions |
| **Auto Cleanup** | Removes outdated firmware files on startup |
| **Scheduling** | LaunchAgent for automatic app launch + optional Mac wake via `pmset` |
| **State Persistence** | Restores queue, activity log, resume data, and selections between launches |
| **Dashboard** | Live metrics — active downloads, global progress bar, transfer stats, status chips |
| **Themes** | Customizable themes with accent colors, gradients, light/dark/auto appearance |
| **Liquid Glass** | Native macOS 26 Liquid Glass effects with graceful fallback on macOS 14–15 |
| **Accessibility** | VoiceOver labels, hints, and values on all interactive elements |
| **Localization** | English and Italian |
| **Notifications** | Local notifications for completed downloads |

## Requirements

- **macOS Sonoma 14.0** or later
- **Full Disk Access** (optional) — required only to write to Apple's default firmware folders

## Installation

### Download

Grab the latest release from the [Releases page](https://github.com/iCosiSenpai/IPSW-Downloader-Plus/releases).

### Build from Source

1. Install **Xcode 16** or later
2. Open `IPSW Downloader Plus.xcodeproj`
3. Select the **IPSW Downloader Plus** scheme
4. Build and run (`⌘R`)

## Download Locations

| Device Type | Default Path |
|---|---|
| iPhone, iPad, iPod | `~/Library/iTunes/{Product} Software Updates` |
| Apple TV, HomePod, Mac | `~/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Firmware` |

If a custom folder is configured in Settings, all downloads go there instead.

## Scheduling

The app supports two independent scheduling features:

- **Automatic launch** — LaunchAgent-based, runs the app on a schedule
- **Mac wake** — `pmset`-based, wakes the Mac before the scheduled launch (requires admin)

They are intentionally separate so you can use one without the other.

## Firmware Data

- Device and firmware metadata from [ipsw.me](https://ipsw.me)
- Downloads restricted to official Apple CDN domains (`updates.cdn-apple.com`, `appldnld.apple.com`, `secure-appldnld.apple.com`)

## Testing

The project includes 40 unit tests using Swift Testing:

```bash
# Run all tests
./scripts/build-test-archive.sh

# Build + archive only (skip tests)
./scripts/build-test-archive.sh --skip-test
```

Test suites cover: ViewModel API (mock injection), device categories, firmware selection & preference, SHA-256/SHA-1 decoding, download progress formatting, error descriptions, URL trust validation, theme behavior, persisted state round-trips, retry policy, scheduling, and Full Disk Access resolution.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/build-test-archive.sh` | Test → Archive → Export to `Releases/` → Verify architectures |
| `scripts/sign-and-notarize-app.sh` | Code sign + notarize + staple a `.app` bundle |
| `scripts/sign-and-notarize-releases.sh` | Wrapper that signs `Releases/IPSW Downloader Plus.app` |

## Security

See [SECURITY.md](SECURITY.md) for the security policy and responsible disclosure process.

## License

MIT License — Copyright (c) 2026 iCosiSenpai. See [LICENSE](LICENSE).

---

<div align="center">

[![PayPal](https://img.shields.io/badge/PayPal-Donate-blue?logo=paypal&logoColor=white)](https://paypal.me/AlessioCosi)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-Support-yellow?logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/icosisenpai)

</div>
