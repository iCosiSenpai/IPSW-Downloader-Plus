# IPSW Downloader Plus

macOS app to browse, select, and download Apple IPSW firmware into the correct local folders for Finder and Apple Configurator.

Repository: [iCosiSenpai/IPSW-Downloader-Plus](https://github.com/iCosiSenpai/IPSW-Downloader-Plus)

## Overview

IPSW Downloader Plus is a native SwiftUI app for macOS that helps keep local IPSW firmware archives up to date.

It can:

- fetch device and firmware data from `ipsw.me`
- organize downloads by device category
- save firmware in Apple's default folders or in a custom destination
- queue and manage multiple downloads with throttling
- retry transient failures and resume interrupted downloads
- verify SHA1 checksums
- monitor local firmware folders
- schedule automatic launches
- optionally configure Mac wake scheduling
- restore state, pending tasks, and activity history between launches

## Features

- Dashboard header with live metrics (devices, selected, active downloads)
- Device sidebar with search, filters, sorting, and quick-select templates
- Batch download flow for selected devices
- Download center grouped by state (active, paused, ready, completed, failed)
- Global progress bar with transfer speed and ETA
- Customizable themes with accent colors and gradients
- Persisted queue, activity log, and resumed downloads after relaunch
- Custom download folder support
- Full Disk Access guidance for default Apple folders
- Guided welcome and initial setup flow
- Automatic cleanup of outdated firmware
- LaunchAgent status and scheduled run reporting
- Local notifications for completed downloads
- English and Italian localization

## Requirements

- macOS Sonoma 14.0 or later
- Full Disk Access if you want to write directly to Apple's default firmware folders

## Build from Source

1. Install Xcode 16 or later.
2. Open `IPSW Downloader Plus.xcodeproj`.
3. Select the `IPSW Downloader Plus` scheme.
4. Build and run.

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

Current release: [v26.0.1](https://github.com/iCosiSenpai/IPSW-Downloader-Plus/releases/tag/v26.0.1)

DMG download: [IPSW Downloader Plus 26.0.1.dmg](https://github.com/iCosiSenpai/IPSW-Downloader-Plus/releases/download/v26.0.1/IPSW%20Downloader%20Plus%2026.0.1.dmg)

## Support

If you want to support development:

- PayPal: [paypal.me/AlessioCosi](https://paypal.me/AlessioCosi)
