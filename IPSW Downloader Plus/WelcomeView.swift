//
//  WelcomeView.swift
//  IPSW Downloader Plus
//

import SwiftUI
import AppKit

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedTab = 0
    @State private var maxUnlockedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack(spacing: 14) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "welcome.title"))
                        .font(.title3.weight(.bold))
                    Link(String(localized: "welcome.title.developer"), destination: URL(string: "https://github.com/iCosiSenpai")!)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 4) {
                        Text("Powered by").font(.caption).foregroundStyle(.secondary)
                        Link("ipsw.me", destination: URL(string: "https://ipsw.me")!).font(.caption)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // MARK: Tab bar
            HStack(spacing: 0) {
                ForEach(Array(tabLabels.enumerated()), id: \.offset) { index, label in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedTab = index }
                    } label: {
                        Text(label)
                            .font(.caption.weight(selectedTab == index ? .semibold : .regular))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                            .background(
                                selectedTab == index
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .foregroundStyle(selectedTab == index ? Color.accentColor : Color.secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(index > maxUnlockedTab)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 6)

            Divider()

            // MARK: Content
            Group {
                switch selectedTab {
                case 0: overviewTab
                case 1: foldersTab
                case 2: securityTab
                default: overviewTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            // MARK: Footer
            HStack(spacing: 12) {
                Toggle(isOn: $settings.showWelcomeOnStartup) {
                    Text(String(localized: "welcome.cta.show_on_startup"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)

                Spacer()

                Button(String(localized: "welcome.cta.settings")) {
                    openWindow(id: "settings")
                }
                .buttonStyle(.bordered)

                if selectedTab > 0 {
                    Button(String(localized: "welcome.cta.back")) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if selectedTab < tabLabels.count - 1 {
                    Button(String(localized: "welcome.cta.next")) {
                        let nextTab = min(selectedTab + 1, tabLabels.count - 1)
                        maxUnlockedTab = max(maxUnlockedTab, nextTab)
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = nextTab
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button(String(localized: "welcome.cta.close")) {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 620, height: 500)
        .onAppear {
            maxUnlockedTab = max(maxUnlockedTab, selectedTab)
        }
    }

    private let tabLabels = ["Overview", "Folders", "Security"]

    // MARK: - Overview Tab

    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Text(String(localized: "welcome.description1"))
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "welcome.description2"))
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                // Full Disk Access status banner
                FDAStatusBanner()

                warningBox(
                    title: String(localized: "welcome.custom_folder.warning_title"),
                    message: settings.isUsingCustomDownloadDirectory
                        ? String(format: String(localized: "welcome.custom_folder.warning_active"), settings.customDownloadDirectoryDisplayPath)
                        : String(localized: "welcome.custom_folder.warning_body"),
                    color: .orange
                )

                // Scheduling note
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.body)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "welcome.schedule.title"))
                            .fontWeight(.semibold)
                            .font(.callout)
                        Text(String(localized: "welcome.schedule.warning"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(Color.yellow.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
            }
            .padding(20)
        }
    }

    // MARK: - Folders Tab

    private var foldersTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Label(String(localized: "welcome.folders.title"), systemImage: "folder.badge.gear")
                    .font(.headline)

                folderBlock(
                    symbol: "iphone",
                    title: String(localized: "welcome.folders.itunes.title"),
                    description: String(localized: "welcome.folders.itunes.desc"),
                    path: "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/iTunes",
                    category: .iTunes(productType: "iPhone")
                )

                folderBlock(
                    symbol: "appletv",
                    title: String(localized: "welcome.folders.configurator.title"),
                    description: String(localized: "welcome.folders.configurator.desc"),
                    path: "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Group Containers/K36BKF7T3D…/Firmware",
                    category: .configurator
                )

                Divider()

                Label(String(localized: "welcome.reorganize.title"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)

                Text(String(localized: "welcome.reorganize.body"))
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 5) {
                    bulletPoint(String(localized: "welcome.reorganize.bullet1"))
                    bulletPoint(String(localized: "welcome.reorganize.bullet2"))
                    bulletPoint(String(localized: "welcome.reorganize.bullet3"))
                    bulletPoint(String(localized: "welcome.reorganize.bullet4"))
                    bulletPoint(String(localized: "welcome.reorganize.bullet5"))
                }

                Divider()

                Label(String(localized: "welcome.excluded.title"), systemImage: "xmark.circle")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    bulletPoint(String(localized: "welcome.excluded.bullet1"))
                    bulletPoint(String(localized: "welcome.excluded.bullet2"))
                }

                warningBox(
                    title: String(localized: "welcome.custom_folder.warning_title"),
                    message: settings.isUsingCustomDownloadDirectory
                        ? String(format: String(localized: "welcome.custom_folder.warning_active"), settings.customDownloadDirectoryDisplayPath)
                        : String(localized: "welcome.custom_folder.warning_settings"),
                    color: .orange
                )
            }
            .padding(20)
        }
    }

    // MARK: - Security Tab

    private var securityTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Label(String(localized: "welcome.security.title"), systemImage: "checkmark.shield")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    bulletPoint(String(localized: "welcome.security.bullet1"))
                    bulletPoint(String(localized: "welcome.security.bullet2"))
                    bulletPoint(String(localized: "welcome.security.bullet3"))
                }

                warningBox(
                    title: String(localized: "welcome.security.fda_required.title"),
                    message: settings.isUsingCustomDownloadDirectory
                        ? String(format: String(localized: "welcome.security.fda_required.custom"), settings.customDownloadDirectoryDisplayPath)
                        : String(localized: "welcome.security.fda_required.body"),
                    color: .red
                )

                Divider()

                // FDA detailed guide
                FDAStatusBanner(showGuide: true)
            }
            .padding(20)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func bulletPoint(_ content: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.body.weight(.bold)).foregroundStyle(Color.accentColor)
            Text(content).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func folderBlock(symbol: String, title: String, description: String, path: String, category: DeviceCategory) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3).frame(width: 28)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.bold))
                Text(description).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(path)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Button(String(localized: "welcome.folders.show_in_finder")) {
                    if let dir = try? category.destinationDirectory() { NSWorkspace.shared.open(dir) }
                }
                .buttonStyle(.borderless).font(.caption)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func warningBox(title: String, message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Full Disk Access Status Banner

/// Mostra il banner FDA con stato (verde = concesso, arancione = mancante).
/// Con showGuide = true mostra anche i passi guidati.
struct FDAStatusBanner: View {
    var showGuide: Bool = false

    @State private var hasAccess: Bool = FullDiskAccessChecker.check()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: hasAccess ? "lock.shield.fill" : "lock.shield.fill")
                .foregroundStyle(hasAccess ? .green : .orange)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(String(localized: "welcome.fda.title"))
                        .fontWeight(.semibold)
                    if hasAccess {
                        Label(String(localized: "welcome.fda.granted"), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                if !hasAccess {
                    Text(String(localized: "welcome.fda.body"))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if showGuide {
                        VStack(alignment: .leading, spacing: 4) {
                            fdaStep("1", text: String(localized: "welcome.fda.step1"))
                            fdaStep("2", text: String(localized: "welcome.fda.step2"))
                            fdaStep("3", text: String(localized: "welcome.fda.step3"))
                        }
                        .padding(.top, 2)
                    }

                    Button(String(localized: "welcome.fda.button")) {
                        FullDiskAccessChecker.openPrivacySettings()
                        // Ricontrolla dopo un breve delay (l'utente potrebbe tornare all'app)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            hasAccess = FullDiskAccessChecker.check()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Text(String(localized: "welcome.fda.granted.body"))
                        .font(.caption).foregroundStyle(.secondary)
                }

                // Pulsante per ri-controllare manualmente
                if !hasAccess {
                    Button(String(localized: "welcome.fda.recheck")) {
                        hasAccess = FullDiskAccessChecker.check()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hasAccess ? Color.green.opacity(0.08) : Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
            hasAccess ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1))
        .onAppear { hasAccess = FullDiskAccessChecker.check() }
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
