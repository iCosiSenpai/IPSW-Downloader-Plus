# IPSW Downloader Plus

macOS app to browse, select, and download Apple IPSW firmware into the correct local folders for Finder and Apple Configurator.

Repository: [iCosiSenpai/IPSW-Downloader-Plus](https://github.com/iCosiSenpai/IPSW-Downloader-Plus)

## Overview

IPSW Downloader Plus is a native SwiftUI app for macOS that helps keep local IPSW firmware archives up to date.

It can:

- fetch device and firmware data from `ipsw.me`
- organize downloads by device category
- save firmware in Apple's default folders or in a custom destination
- queue and manage multiple downloads
- verify SHA1 checksums
- monitor local firmware folders
- schedule automatic launches
- optionally configure Mac wake scheduling

## Features

- Device sidebar with search, filters, and sorting
- Batch download flow for selected devices
- Download center grouped by state
- Custom download folder support
- Full Disk Access guidance for default Apple folders
- Automatic cleanup of outdated firmware
- Local notifications for completed downloads
- English and Italian localization

## Requirements

- macOS
- Xcode
- Full Disk Access if you want to write directly to Apple's default firmware folders

## Build

1. Open `IPSW Downloader Plus.xcodeproj` in Xcode.
2. Select the `IPSW Downloader Plus` scheme.
3. Build and run.

## Default Download Locations

Depending on device type, the app uses:

- `~/Library/iTunes/... Software Updates`
- `~/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Firmware`

If a custom folder is configured, downloads are written there instead.

## Scheduling

The app supports two separate scheduling features:

- Automatic app launch via LaunchAgent
- Mac wake scheduling via `pmset`

They are intentionally separate in the UI:

- enabling automatic scheduling saves the app schedule
- Mac wake requires a separate admin-authorized action

## Source Of Firmware Data

- Device and firmware metadata: [ipsw.me](https://ipsw.me)
- Downloads are limited to official Apple CDN domains

## Release

Current release: [v1.0.0](https://github.com/iCosiSenpai/IPSW-Downloader-Plus/releases/tag/v1.0.0)

## Support

If you want to support development:

- PayPal: [paypal.me/AlessioCosi](https://paypal.me/AlessioCosi)

