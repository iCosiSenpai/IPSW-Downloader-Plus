//
//  SettingsView.swift
//  IPSW Downloader Plus
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "26.0.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "2"
        return String(format: String(localized: "settings.footer.version"), version, build)
    }

    var body: some View {
        ZStack {
            ThemeCanvasBackground(theme: settings.selectedTheme)

            VStack(spacing: 0) {
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

                Divider()

                HStack(spacing: 10) {
                    Text(appVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(String(localized: "settings.general.startup.open_welcome")) {
                        NotificationCenter.default.post(name: .showWelcomeFlow, object: nil)
                    }
                    .buttonStyle(.link)

                    Button(String(localized: "settings.general.startup.open_setup")) {
                        NotificationCenter.default.post(name: .showInitialSetupFlow, object: nil)
                    }
                    .buttonStyle(.link)

                    Link(String(localized: "settings.footer.github"), destination: AppLinks.github)
                        .buttonStyle(.link)

                    Link(String(localized: "settings.footer.support"), destination: AppLinks.support)
                        .buttonStyle(.link)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .themePanelBackground(theme: settings.selectedTheme, colorScheme: colorScheme, cornerRadius: 18)
            .padding(14)
        }
        .background(settings.selectedTheme.windowBackgroundColor(for: colorScheme))
        .frame(width: 720, height: 560)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsFormContent {
            SettingsGroup(title: String(localized: "settings.appearance.title")) {
                AppearanceSettingsSection(settings: settings)
            }

            SettingsGroup(title: String(localized: "settings.general.startup.title")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(String(localized: "settings.general.startup.show_welcome"), isOn: $settings.showWelcomeOnStartup)

                    Text(
                        settings.hasCompletedInitialSetup
                            ? String(localized: "settings.general.startup.setup_completed")
                            : String(localized: "settings.general.startup.setup_pending")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

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

            FDAStatusBanner(showGuide: true)
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

private struct AppearanceSettingsSection: View {
    @ObservedObject var settings: AppSettings

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "settings.appearance.mode.title"))
                    .font(.subheadline.weight(.semibold))

                Picker("", selection: $settings.appearanceMode) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(String(localized: "settings.appearance.mode.footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "settings.appearance.theme.title"))
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            settings.selectedTheme = theme
                        } label: {
                            ThemePreviewCard(theme: theme, isSelected: settings.selectedTheme == theme)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(String(localized: "settings.appearance.theme.footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Download Tab

private struct DownloadSettingsTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsFormContent {
            SettingsGroup(title: String(localized: "settings.download.integrity.title")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(String(localized: "settings.download.integrity.toggle"), isOn: $settings.verifyChecksumAfterDownload)
                    Text(String(localized: "settings.download.integrity.footer"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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

            SettingsGroup(title: String(localized: "settings.download.notify.title")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(String(localized: "settings.download.notify.toggle"), isOn: $settings.notifyOnDownloadComplete)
                    Text(String(localized: "settings.download.notify.footer"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsGroup(title: String(localized: "settings.download.folder_size.title")) {
                FolderSizeView()
            }
        }
    }
}

private struct FolderStats: Equatable {
    var bytes: Int64 = 0
    var fileCount: Int = 0

    var formattedSize: String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return "\(bytes) B"
    }
}

private struct FolderSizeView: View {
    @State private var itunesStats = FolderStats()
    @State private var configuratorStats = FolderStats()
    @State private var customStats = FolderStats()
    @State private var isLoading = true
    @ObservedObject private var settings = AppSettings.shared

    private var maxBytes: Int64 {
        max(itunesStats.bytes, configuratorStats.bytes,
            settings.isUsingCustomDownloadDirectory ? customStats.bytes : 0,
            1)
    }

    var body: some View {
        VStack(spacing: 10) {
            if settings.isUsingCustomDownloadDirectory {
                folderRow(
                    title: String(localized: "settings.general.folders.custom_title"),
                    stats: customStats, icon: "folder.fill", tint: .purple
                )
            }
            folderRow(
                title: "iTunes Software Updates",
                stats: itunesStats, icon: "music.note", tint: .blue
            )
            folderRow(
                title: "Configurator Firmware",
                stats: configuratorStats, icon: "wrench.and.screwdriver", tint: .orange
            )
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .task { await loadStats() }
        .onChange(of: settings.customDownloadDirectoryPath) { _, _ in
            Task { await loadStats() }
        }
    }

    @MainActor
    private func loadStats() async {
        isLoading = true
        let custom = await Task.detached(priority: .utility) { [url = settings.customDownloadDirectoryURL] in
            Self.folderStatsSync(url)
        }.value
        let itunes = await Task.detached(priority: .utility) {
            Self.folderStatsSync(try? DeviceCategory.iTunes(productType: "iPhone").destinationDirectory())
        }.value
        let config = await Task.detached(priority: .utility) {
            Self.folderStatsSync(try? DeviceCategory.configurator.destinationDirectory())
        }.value
        customStats = settings.isUsingCustomDownloadDirectory ? custom : FolderStats()
        itunesStats = itunes
        configuratorStats = config
        isLoading = false
    }

    private nonisolated static func folderStatsSync(_ directory: URL?) -> FolderStats {
        guard let dir = directory else { return FolderStats() }
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey],
                                              options: [.skipsHiddenFiles]) else { return FolderStats() }
        var stats = FolderStats()
        for case let url as URL in enumerator {
            if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                stats.bytes += Int64(size)
                stats.fileCount += 1
            }
        }
        return stats
    }

    @ViewBuilder
    private func folderRow(title: String, stats: FolderStats, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 16)
                Text(title)
                    .lineLimit(1)
                Spacer()
                Text(stats.formattedSize)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(String(format: String(localized: "settings.download.folder_size.files"), stats.fileCount))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint.gradient)
                        .frame(width: max(0, geo.size.width * CGFloat(stats.bytes) / CGFloat(maxBytes)))
                }
            }
            .frame(height: 6)
            .animation(.easeInOut(duration: 0.4), value: stats)
        }
    }
}

// MARK: - Schedule Tab

private struct ScheduleSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @State private var showClearReportConfirmation = false

    var body: some View {
        SettingsFormContent {
            SettingsGroup(title: String(localized: "settings.schedule.autolaunch.title")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(String(localized: "settings.schedule.autolaunch.toggle"), isOn: $settings.autoLaunchEnabled)
                        .disabled(settings.isSchedulingOperationInProgress)
                    Text(String(localized: "settings.schedule.autolaunch.footer"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if settings.autoLaunchEnabled {
                SettingsGroup(title: String(localized: "settings.schedule.agent.title")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: settings.launchAgentLoaded ? "checkmark.circle.fill" : "bolt.horizontal.circle")
                                .foregroundStyle(settings.launchAgentLoaded ? .green : .secondary)
                            Text(settings.launchAgentStatusDescription)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Text(String(localized: "settings.schedule.agent.footer"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let report = settings.lastAutoLaunchReport,
                   let summary = settings.lastAutoLaunchReportDescription {
                    SettingsGroup(title: String(localized: "settings.schedule.report.title")) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: report.completionKind.systemImage)
                                    .foregroundStyle(report.hadFailures ? .orange : .green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(summary)
                                        .font(.callout)
                                    Text(
                                        String(
                                            format: String(localized: "settings.schedule.report.last_run"),
                                            report.finishedAt.formatted(date: .abbreviated, time: .shortened)
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }

                            HStack(spacing: 8) {
                                ReportBadge(title: String(localized: "settings.schedule.report.checked"), value: report.checkedCount, tint: .blue)
                                ReportBadge(title: String(localized: "settings.schedule.report.downloaded"), value: report.downloadedCount, tint: .green)
                                ReportBadge(title: String(localized: "settings.schedule.report.skipped"), value: report.skippedCount, tint: .secondary)
                                ReportBadge(title: String(localized: "settings.schedule.report.failed"), value: report.failedCount, tint: .orange)
                            }

                            Button(String(localized: "settings.schedule.report.clear")) {
                                showClearReportConfirmation = true
                            }
                            .buttonStyle(.bordered)
                            .confirmationDialog(
                                String(localized: "confirm.clear_report.title"),
                                isPresented: $showClearReportConfirmation,
                                titleVisibility: .visible
                            ) {
                                Button(String(localized: "confirm.clear_report.action"), role: .destructive) {
                                    settings.clearAutoLaunchReport()
                                }
                            } message: {
                                Text(String(localized: "confirm.clear_report.message"))
                            }
                        }
                    }
                }

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
                        .disabled(settings.isSchedulingOperationInProgress)
                        Stepper(value: $settings.autoLaunchMinute, in: 0...59, step: 5) {
                            Text(String(format: String(localized: "settings.schedule.time.minute"),
                                        String(format: "%02d", settings.autoLaunchMinute)))
                                .monospacedDigit()
                                .frame(width: 70, alignment: .leading)
                        }
                        .disabled(settings.isSchedulingOperationInProgress)
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

                // Schedule summary
                HStack(spacing: 8) {
                    if settings.isSchedulingOperationInProgress {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.callout)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.scheduleDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if let nextRun = settings.nextScheduledRunDescription {
                            Text(nextRun)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
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
                                .disabled(settings.isSchedulingOperationInProgress)
                            }

                            Button(String(localized: "settings.schedule.wake.disable")) {
                                settings.disableWakeSchedule()
                            }
                            .buttonStyle(.bordered)
                            .disabled(!settings.wakeScheduleActive || settings.isSchedulingOperationInProgress)
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
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.3), lineWidth: 0.5))
        }
        .animation(.default, value: settings.autoLaunchEnabled)
    }
}

private struct ReportBadge: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .disabled(settings.isSchedulingOperationInProgress)
    }
}

// MARK: - Device Filter Tab

private struct DeviceFilterTab: View {
    @ObservedObject var settings: AppSettings
    @State private var deviceSearch = ""

    private var enabledCount: Int {
        let totalKeys = Set(AppSettings.allProductTypePrefixes.map(\.id))
        return totalKeys.subtracting(settings.excludedProductTypes).count
    }

    private var filteredTypes: [(id: String, label: String, symbol: String)] {
        if deviceSearch.isEmpty {
            return AppSettings.allProductTypePrefixes
        }
        return AppSettings.allProductTypePrefixes.filter {
            $0.label.localizedCaseInsensitiveContains(deviceSearch)
        }
    }

    var body: some View {
        SettingsFormContent {
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
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "settings.devices.search"), text: $deviceSearch)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.bottom, 8)

                    ForEach(Array(filteredTypes.enumerated()), id: \.element.id) { index, item in
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

                        if index < filteredTypes.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            Text(String(localized: "settings.devices.footer"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Reusable Wrappers

/// Wraps tab content in Form(.grouped) on macOS 26+, ScrollView+VStack on older.
private struct SettingsFormContent<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            Form {
                content
            }
            .formStyle(.grouped)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(18)
            }
        }
    }
}

/// On macOS 26+, renders as a native Section. On older, uses custom glass panel.
private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if #available(macOS 26.0, *) {
            Section {
                content
            } header: {
                Text(title)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                content
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
