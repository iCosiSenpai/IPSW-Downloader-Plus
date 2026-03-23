# Changelog

All notable changes to this project are documented in this file.

## [26.0] - 2026-03-23

### Added

- Theme system with automatic, light, and dark appearance modes plus selectable app themes.
- Dedicated theme behavior tests covering appearance mapping and theme color consistency.
- Faster dashboard shortcuts for downloading selections, pausing or resuming transfers, opening the download folder, and jumping to Settings.

### Changed

- Updated app version to `26.0`.
- Refined the main window layout with a clearer dashboard, stronger status badges, and a more structured downloads workspace.
- Reworked the welcome and initial setup flow with a more stable layout, larger sheets, and improved spacing for permission and destination steps.
- Expanded localized strings in English and Italian for the new theme and dashboard UI.

### Fixed

- Fixed appearance switching issues where the app could fail to return cleanly between light, dark, and automatic modes.
- Fixed multiple onboarding regressions, including clipped controls, setup dismissal issues after granting Full Disk Access, and stale permission state in the setup flow.
- Fixed managed download bulk cancellation so `Cancel all` now targets every cancellable task, not just the currently visible subset.
- Fixed Full Disk Access refresh behavior so the permission banner updates correctly after returning from System Settings.

## [1.2.1] - 2026-03-19

### Changed

- Updated app version to `1.2.1`.
- Updated README release information for GitHub release `v1.2.1`.
- Updated the scheduled auto-download flow so it targets the latest iOS release and only the supported iPhone models returned by the API.

## [1.2.0] - 2026-03-19

### Added

- Dedicated managed downloads section with its own selection model, so in-progress tasks remain visible even when the device sidebar selection changes.
- Bulk actions to pause or cancel the selected active downloads, plus quick controls to pause all or cancel all managed downloads.
- Local firmware inventory that scans the monitored IPSW folders at launch and shows already-downloaded firmware directly inside the app.
- Explicit paused download state in the model and UI, including resume actions for interrupted transfers.

### Changed

- Updated app version to `1.2.0`.
- Updated README release information for GitHub release `v1.2.0`.
- Refined the downloads view to separate managed downloads from ready, completed, failed, and local firmware lists.

### Fixed

- Fixed a queue progression bug where bulk downloads could appear stuck after the first concurrent slots completed or resolved to already-present firmware.
- Fixed the inability to control downloads after deselecting devices by decoupling active download management from sidebar device selection.
- Fixed the lack of pause and cancel controls for current downloads, including per-download and bulk actions.

## [1.1.0] - 2026-03-18

### Added

- New app icon in `AppIcon.appiconset`, suitable for standard, dark, and monochrome contexts.
- Activity log with recent events for device loading, downloads, retries, cancellations, and scheduled runs.
- Persisted app state for selected devices, task queue, activity history, and download resume data.
- Initial onboarding split into a dedicated welcome screen followed by a guided setup flow.
- Scheduled run reporting in Settings, including checked, downloaded, skipped, and failed counts.
- Test target and persistence/runtime logic coverage for restored state, retry policy, and Full Disk Access resolution.

### Changed

- Updated app version to `1.1.0`.
- Improved download scheduling so the concurrency limit now covers both metadata fetches and active transfers.
- Improved download robustness with retry handling for transient failures and resume support for interrupted downloads.
- Improved Full Disk Access evaluation by distinguishing `granted`, `denied`, and `undetermined`.
- Modernized LaunchAgent handling with `bootout`, `bootstrap`, `enable`, and status inspection.
- Refined Settings window UX and surfaced onboarding, GitHub, and donation links directly in the window footer.
- Updated README release information for GitHub release `v1.1.0`.

### Fixed

- Fixed silent failures when a device firmware lookup fails before a visible task is created.
- Fixed firmware date sorting so ascending and descending ordering use stable metadata and correct fallbacks.
- Fixed the duplicate sidebar toggle regression by keeping only the native macOS control.
- Fixed blocking folder-size calculation for custom destinations by moving the work off the main rendering path.
- Removed residual references to Pico Mitchell from localized strings and code comments.

## [1.0.0]

- Initial public release.
