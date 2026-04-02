//
//  WelcomeView.swift
//  IPSW Downloader Plus
//

import SwiftUI
import AppKit

struct WelcomeView: View {
    let selectedTheme: AppTheme
    @Binding var showWelcomeOnStartup: Bool
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemeCanvasBackground(theme: selectedTheme)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [selectedTheme.tintColor, selectedTheme.accentColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "welcome.title"))
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            Text(String(localized: "welcome.hero.body"))
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 10) {
                                Link(String(localized: "welcome.title.developer"), destination: AppLinks.github)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selectedTheme.tintColor)
                                Text(selectedTheme.localizedTitle)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectedTheme.tintColor.opacity(0.12), in: Capsule())
                                    .foregroundStyle(selectedTheme.tintColor)
                            }
                        }
                    }

                    HStack(spacing: 14) {
                        welcomeCard(
                            title: String(localized: "welcome.card.downloads.title"),
                            message: String(localized: "welcome.card.downloads.body"),
                            systemImage: "square.and.arrow.down.on.square.fill",
                            tint: .blue
                        )
                        welcomeCard(
                            title: String(localized: "welcome.card.setup.title"),
                            message: String(localized: "welcome.card.setup.body"),
                            systemImage: "slider.horizontal.3",
                            tint: .orange
                        )
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.secondary)
                        Text(String(localized: "welcome.flow.note"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(24)
                .themePanelBackground(theme: selectedTheme, colorScheme: colorScheme, cornerRadius: 20)
                .background(selectedTheme.heroGradient(for: colorScheme), in: RoundedRectangle(cornerRadius: 20))
                .padding(18)

                Divider()

                HStack(alignment: .center, spacing: 16) {
                    Toggle(isOn: $showWelcomeOnStartup) {
                        Text(String(localized: "welcome.cta.show_on_startup"))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .toggleStyle(.checkbox)

                    Spacer()

                    Button(String(localized: "welcome.cta.continue")) {
                        onContinue()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(minHeight: 60)
            }
        }
        .background(selectedTheme.windowBackgroundColor(for: colorScheme))
        .frame(width: 680, height: 500)
    }

    @ViewBuilder
    private func welcomeCard(title: String, message: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .themeMetricCardBackground(tint: tint, cornerRadius: 14)
    }
}

struct InitialSetupView: View {
    let selectedTheme: AppTheme
    @Binding var showWelcomeOnStartup: Bool
    @Binding var customDownloadDirectoryPath: String
    @Binding var fullDiskAccessStatus: FullDiskAccessStatus
    let chooseCustomDownloadDirectory: @MainActor () -> Void
    let resetCustomDownloadDirectory: () -> Void
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedStep = 0

    private let stepTitles = [
        "setup.step.permissions",
        "setup.step.folders",
        "setup.step.finish"
    ]

    var body: some View {
        ZStack {
            ThemeCanvasBackground(theme: selectedTheme)

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.system(size: 38))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [selectedTheme.tintColor, selectedTheme.accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "setup.title"))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text(String(localized: "setup.subtitle"))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                Divider()

                HStack(spacing: 8) {
                    ForEach(0..<stepTitles.count, id: \.self) { index in
                        setupStepChip(index: index, key: stepTitles[index])
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)

                Divider()

                Group {
                    switch selectedStep {
                    case 0:
                        permissionsStep
                    case 1:
                        foldersStep
                    default:
                        finishStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.vertical, 4)

                Divider()

                HStack {
                    Button(String(localized: "setup.open.settings")) {
                        SettingsPresenter.open()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if selectedStep > 0 {
                        Button(String(localized: "welcome.cta.back")) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(selectedStep == stepTitles.count - 1 ? String(localized: "setup.finish") : String(localized: "welcome.cta.next")) {
                        if selectedStep == stepTitles.count - 1 {
                            onFinish()
                        } else {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedStep += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .themePanelBackground(theme: selectedTheme, colorScheme: colorScheme, cornerRadius: 20)
            .padding(16)
        }
        .background(selectedTheme.windowBackgroundColor(for: colorScheme))
        .frame(width: 720, height: 620)
    }

    private var permissionsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                setupStatusBanner(
                    title: String(localized: "setup.permissions.banner"),
                    message: permissionSummary,
                    tint: permissionTint
                )

                Text(String(localized: "setup.permissions.body"))
                    .font(.body)
                    .foregroundStyle(.secondary)

                FDAStatusBanner(showGuide: true) { updatedStatus in
                    fullDiskAccessStatus = updatedStatus
                }

                HStack(spacing: 10) {
                    Button(String(localized: "welcome.fda.button")) {
                        FullDiskAccessChecker.openPrivacySettings()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(String(localized: "welcome.fda.recheck")) {
                        fullDiskAccessStatus = FullDiskAccessChecker.status()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(22)
        }
    }

    private var foldersStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                setupStatusBanner(
                    title: String(localized: "setup.folders.banner"),
                    message: isUsingCustomDownloadDirectory
                        ? customDownloadDirectoryDisplayPath
                        : String(localized: "setup.summary.destination_default"),
                    tint: isUsingCustomDownloadDirectory ? .orange : .blue
                )

                Text(String(localized: "setup.folders.body"))
                    .font(.body)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    folderCard(
                        title: String(localized: "welcome.folders.itunes.title"),
                        body: String(localized: "welcome.folders.itunes.desc"),
                        systemImage: "iphone"
                    )
                    folderCard(
                        title: String(localized: "welcome.folders.configurator.title"),
                        body: String(localized: "welcome.folders.configurator.desc"),
                        systemImage: "appletv"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "settings.general.folders.custom_title"))
                        .font(.headline)
                    Text(customDownloadDirectoryDisplayPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    HStack(spacing: 10) {
                        Button(String(localized: "settings.general.folders.choose")) {
                            chooseCustomDownloadDirectory()
                        }
                        .buttonStyle(.borderedProminent)

                        Button(String(localized: "settings.general.folders.reset")) {
                            resetCustomDownloadDirectory()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isUsingCustomDownloadDirectory)
                    }
                }
                .padding(14)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(22)
        }
    }

    private var finishStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label(String(localized: "setup.finish.title"), systemImage: "checkmark.seal.fill")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "setup.finish.body"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                summaryRow(
                    title: String(localized: "setup.summary.permission"),
                    value: permissionSummary
                )
                summaryRow(
                    title: String(localized: "setup.summary.destination"),
                    value: isUsingCustomDownloadDirectory
                        ? customDownloadDirectoryDisplayPath
                        : String(localized: "setup.summary.destination_default")
                )
                summaryRow(
                    title: String(localized: "setup.summary.welcome"),
                    value: showWelcomeOnStartup
                        ? String(localized: "setup.summary.enabled")
                        : String(localized: "setup.summary.disabled")
                )

                setupStatusBanner(
                    title: String(localized: "setup.finish.banner"),
                    message: String(localized: "setup.finish.ready"),
                    tint: .green
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
        }
    }

    private var permissionTint: Color {
        switch fullDiskAccessStatus {
        case .granted: return .green
        case .denied: return .orange
        case .undetermined: return .yellow
        }
    }

    @ViewBuilder
    private func setupStepChip(index: Int, key: String) -> some View {
        let isReached = index <= selectedStep
        let isCurrent = index == selectedStep
        Label(String(localized: String.LocalizationValue(key)), systemImage: isReached ? "checkmark.circle.fill" : "circle")
            .font(.caption.weight(isCurrent ? .semibold : .regular))
            .foregroundStyle(isReached ? Color.accentColor : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isCurrent ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func setupStatusBanner(title: String, message: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private var permissionSummary: String {
        switch fullDiskAccessStatus {
        case .granted: return String(localized: "welcome.fda.granted")
        case .denied: return String(localized: "setup.summary.permission_denied")
        case .undetermined: return String(localized: "setup.summary.permission_unknown")
        }
    }

    @ViewBuilder
    private func folderCard(title: String, body: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(selectedTheme.secondarySurfaceColor(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func summaryRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectedTheme.secondarySurfaceColor(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
    }

    private var isUsingCustomDownloadDirectory: Bool {
        !customDownloadDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var customDownloadDirectoryDisplayPath: String {
        AppSettings.storedCustomDownloadDirectoryURL()?.path
            ?? String(localized: "settings.general.folders.default_path")
    }
}

// MARK: - Full Disk Access Status Banner

struct FDAStatusBanner: View {
    var showGuide: Bool = false
    var onStatusChange: ((FullDiskAccessStatus) -> Void)? = nil

    @State private var status: FullDiskAccessStatus = FullDiskAccessChecker.status()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(String(localized: "welcome.fda.title"))
                        .fontWeight(.semibold)
                    Text(statusBadgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(iconColor)
                }

                Text(statusBodyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if showGuide, status != .granted {
                    VStack(alignment: .leading, spacing: 4) {
                        fdaStep("1", text: String(localized: "welcome.fda.step1"))
                        fdaStep("2", text: String(localized: "welcome.fda.step2"))
                        fdaStep("3", text: String(localized: "welcome.fda.step3"))
                    }
                    .padding(.top, 2)
                }

                if status != .granted {
                    Button(String(localized: "welcome.fda.button")) {
                        FullDiskAccessChecker.openPrivacySettings()
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            refreshStatus()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(String(localized: "welcome.fda.recheck")) {
                        refreshStatus()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(iconColor.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(iconColor.opacity(0.25), lineWidth: 0.5))
        .onAppear { refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                refreshStatus()
            }
        }
    }

    private func refreshStatus() {
        let updated = FullDiskAccessChecker.status()
        status = updated
        onStatusChange?(updated)
    }

    private var iconName: String {
        switch status {
        case .granted: return "lock.shield.fill"
        case .denied: return "lock.open.trianglebadge.exclamationmark"
        case .undetermined: return "questionmark.shield"
        }
    }

    private var iconColor: Color {
        switch status {
        case .granted: return .green
        case .denied: return .orange
        case .undetermined: return .yellow
        }
    }

    private var statusBadgeText: String {
        switch status {
        case .granted: return String(localized: "welcome.fda.granted")
        case .denied: return String(localized: "welcome.fda.denied")
        case .undetermined: return String(localized: "welcome.fda.unknown")
        }
    }

    private var statusBodyText: String {
        switch status {
        case .granted: return String(localized: "welcome.fda.granted.body")
        case .denied: return String(localized: "welcome.fda.body")
        case .undetermined: return String(localized: "welcome.fda.unknown.body")
        }
    }

    @ViewBuilder
    private func fdaStep(_ number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(number)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(Color.orange)
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
