//
//  SettingsView.swift
//  IPSW Downloader Plus
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings)
                .tabItem { Label(String(localized: "settings.tab.general"), systemImage: "gearshape") }

            DownloadSettingsTab(settings: settings)
                .tabItem { Label(String(localized: "settings.tab.download"), systemImage: "arrow.down.circle") }

            ScheduleSettingsTab(settings: settings)
                .tabItem { Label(String(localized: "settings.tab.schedule"), systemImage: "calendar.badge.clock") }

            DeviceFilterTab(settings: settings)
                .tabItem { Label(String(localized: "settings.tab.devices"), systemImage: "iphone") }
        }
        .frame(width: 560, height: 420)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Startup
                SettingsGroup(title: String(localized: "settings.general.startup.title")) {
                    Toggle(String(localized: "settings.general.startup.show_welcome"), isOn: $settings.showWelcomeOnStartup)
                }

                // Obsolete firmware
                SettingsGroup(title: String(localized: "settings.general.obsolete.title")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("", selection: $settings.deleteMode) {
                            ForEach(DeleteMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        Text(String(localized: "settings.general.obsolete.footer"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Destination folders
                SettingsGroup(title: String(localized: "settings.general.folders.title")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Button(String(localized: "settings.general.folders.itunes")) {
                                openFolder(DeviceCategory.iTunes(productType: "iPhone"))
                            }
                            Button(String(localized: "settings.general.folders.configurator")) {
                                openFolder(.configurator)
                            }
                        }
                        .controlSize(.regular)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "settings.general.folders.custom_title"))
                                .font(.subheadline.weight(.semibold))
                            Text(settings.customDownloadDirectoryDisplayPath)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            HStack(spacing: 10) {
                                Button(String(localized: "settings.general.folders.choose")) {
                                    settings.chooseCustomDownloadDirectory()
                                }
                                Button(String(localized: "settings.general.folders.reset")) {
                                    settings.resetCustomDownloadDirectory()
                                }
                                .disabled(!settings.isUsingCustomDownloadDirectory)
                                Button(String(localized: "settings.general.folders.open_custom")) {
                                    openCustomFolder()
                                }
                                .disabled(settings.customDownloadDirectoryURL == nil)
                            }

                            Text(String(localized: "settings.general.folders.custom_footer"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Full Disk Access — banner con stato dinamico e guida guidata
                FDAStatusBanner(showGuide: true)
            }
            .padding(20)
        }
    }

    private func openFolder(_ category: DeviceCategory) {
        if let dir = try? category.destinationDirectory() {
            NSWorkspace.shared.open(dir)
        }
    }

    private func openCustomFolder() {
        guard let url = settings.customDownloadDirectoryURL else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Download Tab

private struct DownloadSettingsTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Integrity
                SettingsGroup(title: String(localized: "settings.download.integrity.title")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(String(localized: "settings.download.integrity.toggle"), isOn: $settings.verifyChecksumAfterDownload)
                        Text(String(localized: "settings.download.integrity.footer"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Parallel downloads
                SettingsGroup(title: String(localized: "settings.download.parallel.title")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Stepper(value: $settings.maxConcurrentDownloads, in: 1...5) {
                                Text(String(format: String(localized: "settings.download.parallel.label"), settings.maxConcurrentDownloads))
                                    .monospacedDigit()
                            }
                        }
                        Text(String(localized: "settings.download.parallel.footer"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Notifications
                SettingsGroup(title: String(localized: "settings.download.notify.title")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(String(localized: "settings.download.notify.toggle"), isOn: $settings.notifyOnDownloadComplete)
                        Text(String(localized: "settings.download.notify.footer"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Folder size
                SettingsGroup(title: String(localized: "settings.download.folder_size.title")) {
                    FolderSizeView()
                }
            }
            .padding(20)
        }
    }
}

/// Shows current size of both IPSW folders.
private struct FolderSizeView: View {
    @State private var itunesSize: String = "…"
    @State private var configuratorSize: String = "…"
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 6) {
            if settings.isUsingCustomDownloadDirectory {
                sizeRow(title: String(localized: "settings.general.folders.custom_title"), value: customSize)
            }
            sizeRow(title: "iTunes Software Updates", value: itunesSize)
            sizeRow(title: "Configurator Firmware", value: configuratorSize)
        }
        .task { await loadSizes() }
        .onChange(of: settings.customDownloadDirectoryPath) { _, _ in
            Task { await loadSizes() }
        }
    }

    private var customSize: String {
        guard let url = settings.customDownloadDirectoryURL else { return "N/A" }
        return folderSizeSync(url)
    }

    @MainActor
    private func loadSizes() async {
        let itunes = await Task.detached(priority: .utility) {
            folderSizeSync(try? DeviceCategory.iTunes(productType: "iPhone").destinationDirectory())
        }.value
        let config = await Task.detached(priority: .utility) {
            folderSizeSync(try? DeviceCategory.configurator.destinationDirectory())
        }.value
        itunesSize = itunes
        configuratorSize = config
    }

    private nonisolated func folderSizeSync(_ directory: URL?) -> String {
        guard let dir = directory else { return "N/A" }
        return folderSizeSync(dir)
    }

    private nonisolated func folderSizeSync(_ dir: URL) -> String {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: dir,
                                              includingPropertiesForKeys: [.fileSizeKey],
                                              options: [.skipsHiddenFiles]) else { return "0 B" }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += Int64(size)
            }
        }
        return formatBytes(total)
    }

    private nonisolated func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return "\(bytes) B"
    }

    @ViewBuilder
    private func sizeRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Schedule Tab

private struct ScheduleSettingsTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                SettingsGroup(title: String(localized: "settings.schedule.autolaunch.title")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(String(localized: "settings.schedule.autolaunch.toggle"), isOn: $settings.autoLaunchEnabled)
                        Text(String(localized: "settings.schedule.autolaunch.footer"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if settings.autoLaunchEnabled {
                    SettingsGroup(title: String(localized: "settings.schedule.workflow.title")) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(localized: "settings.schedule.workflow.body"))
                                .font(.callout)
                            Text(String(localized: "settings.schedule.workflow.note"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    SettingsGroup(title: String(localized: "settings.schedule.time.title")) {
                        HStack(spacing: 16) {
                            Stepper(value: $settings.autoLaunchHour, in: 0...23) {
                                Text(String(format: String(localized: "settings.schedule.time.hour"),
                                            String(format: "%02d", settings.autoLaunchHour)))
                                    .monospacedDigit()
                                    .frame(width: 70, alignment: .leading)
                            }
                            Stepper(value: $settings.autoLaunchMinute, in: 0...59, step: 5) {
                                Text(String(format: String(localized: "settings.schedule.time.minute"),
                                            String(format: "%02d", settings.autoLaunchMinute)))
                                    .monospacedDigit()
                                    .frame(width: 70, alignment: .leading)
                            }
                        }
                    }

                    SettingsGroup(title: String(localized: "settings.schedule.days.title")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                ForEach(Weekday.allCases) { day in
                                    DayToggle(day: day, settings: settings)
                                }
                            }
                            Text(String(localized: "settings.schedule.days.footer"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Summary
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.callout)
                        Text(settings.scheduleDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                }

                if settings.autoLaunchEnabled || settings.wakeScheduleActive || settings.wakeScheduleError != nil {
                    SettingsGroup(title: String(localized: "settings.schedule.wake.title")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: settings.wakeScheduleActive
                                      ? "bolt.circle.fill" : "bolt.slash.circle")
                                    .foregroundStyle(settings.wakeScheduleActive ? .green : .secondary)
                                    .font(.callout)
                                Text(settings.wakeScheduleActive
                                     ? String(localized: "settings.schedule.wake.active")
                                     : String(localized: "settings.schedule.wake.inactive"))
                                    .font(.callout)
                            }
                            if let error = settings.wakeScheduleError {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            HStack(spacing: 10) {
                                if settings.autoLaunchEnabled {
                                    Button(settings.wakeScheduleActive
                                           ? String(localized: "settings.schedule.wake.update")
                                           : String(localized: "settings.schedule.wake.configure")) {
                                        settings.applyWakeSchedule()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }

                                Button(String(localized: "settings.schedule.wake.disable")) {
                                    settings.disableWakeSchedule()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!settings.wakeScheduleActive)
                            }
                            Text(String(localized: "settings.schedule.wake.footer"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Auto-login warning
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.body)
                        .frame(width: 20, alignment: .center)
                    Text(String(localized: "settings.schedule.login_warning"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
            }
            .padding(20)
            .animation(.default, value: settings.autoLaunchEnabled)
        }
    }
}

private struct DayToggle: View {
    let day: Weekday
    @ObservedObject var settings: AppSettings

    private var isOn: Bool { settings.autoLaunchDays.contains(day.rawValue) }

    var body: some View {
        Toggle(day.shortName, isOn: Binding(
            get: { isOn },
            set: { enabled in
                if enabled {
                    settings.autoLaunchDays.insert(day.rawValue)
                } else {
                    settings.autoLaunchDays.remove(day.rawValue)
                }
            }
        ))
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .tint(isOn ? .accentColor : nil)
    }
}

// MARK: - Device Filter Tab

private struct DeviceFilterTab: View {
    @ObservedObject var settings: AppSettings

    private var enabledCount: Int {
        let totalKeys = Set(AppSettings.allProductTypePrefixes.map(\.id))
        return totalKeys.subtracting(settings.excludedProductTypes).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                if !settings.hasAtLeastOneEnabledType {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(String(localized: "settings.devices.warning"))
                            .font(.headline)
                            .foregroundStyle(.red)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                SettingsGroup(title: String(localized: "settings.devices.types.title")) {
                    VStack(spacing: 0) {
                        ForEach(Array(AppSettings.allProductTypePrefixes.enumerated()), id: \.element.id) { index, item in
                            let isEnabled = settings.isProductTypeEnabled(item.id)
                            let isLastEnabled = isEnabled && enabledCount == 1

                            HStack {
                                Toggle(isOn: Binding(
                                    get: { isEnabled },
                                    set: { newValue in _ = settings.setProductType(item.id, enabled: newValue) }
                                )) {
                                    Label(item.label, systemImage: item.symbol)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .disabled(isLastEnabled)

                                if isLastEnabled {
                                    Text(String(localized: "settings.devices.minimum"))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 2)

                            if index < AppSettings.allProductTypePrefixes.count - 1 {
                                Divider()
                            }
                        }
                    }
                }

                Text(String(localized: "settings.devices.footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }
}

// MARK: - Reusable Group

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
}
