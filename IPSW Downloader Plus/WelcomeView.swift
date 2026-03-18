//
//  WelcomeView.swift
//  IPSW Downloader Plus
//

import SwiftUI
import AppKit

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    private var itunesPath: String {
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/iTunes"
    }
    private var configuratorPath: String {
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Firmware"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: Header
                HStack(spacing: 14) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "welcome.title"))
                            .font(.title2.weight(.bold))
                        Link(String(localized: "welcome.title.developer"), destination: URL(string: "https://github.com/iCosiSenpai")!)
                            .font(.subheadline.weight(.bold))
                        HStack(spacing: 4) {
                            Text("Powered by")
                                .font(.caption).foregroundStyle(.secondary)
                            Link("ipsw.me", destination: URL(string: "https://ipsw.me")!)
                                .font(.caption)
                            Text("·")
                                .font(.caption).foregroundStyle(.secondary)
                            Link("IPSW Updater", destination: URL(string: "https://github.com/freegeek-pdx/IPSW-Updater")!)
                                .font(.caption)
                            Text(String(localized: "welcome.credits.by"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // MARK: Description
                welcomeText(String(localized: "welcome.description1"))
                welcomeText(String(localized: "welcome.description2"))

                // MARK: Full Disk Access warning
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "welcome.fda.title"))
                            .fontWeight(.semibold)
                        Text(String(localized: "welcome.fda.body"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(String(localized: "welcome.fda.button")) {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Divider()

                // MARK: Folders
                VStack(alignment: .leading, spacing: 10) {
                    Label(String(localized: "welcome.folders.title"), systemImage: "folder.badge.gear")
                        .font(.headline)

                    folderBlock(
                        symbol: "iphone",
                        title: String(localized: "welcome.folders.itunes.title"),
                        description: String(localized: "welcome.folders.itunes.desc"),
                        path: itunesPath,
                        category: .iTunes(productType: "iPhone")
                    )

                    folderBlock(
                        symbol: "appletv",
                        title: String(localized: "welcome.folders.configurator.title"),
                        description: String(localized: "welcome.folders.configurator.desc"),
                        path: configuratorPath,
                        category: .configurator
                    )
                }

                Divider()

                // MARK: Existing file management
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "welcome.reorganize.title"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline)

                    welcomeText(String(localized: "welcome.reorganize.body"))

                    VStack(alignment: .leading, spacing: 6) {
                        bulletPoint(String(localized: "welcome.reorganize.bullet1"))
                        bulletPoint(String(localized: "welcome.reorganize.bullet2"))
                        bulletPoint(String(localized: "welcome.reorganize.bullet3"))
                        bulletPoint(String(localized: "welcome.reorganize.bullet4"))
                        bulletPoint(String(localized: "welcome.reorganize.bullet5"))
                    }
                }

                Divider()

                // MARK: Excluded devices
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "welcome.excluded.title"), systemImage: "xmark.circle")
                        .font(.headline)

                    welcomeText(String(localized: "welcome.excluded.body"))

                    VStack(alignment: .leading, spacing: 4) {
                        bulletPoint(String(localized: "welcome.excluded.bullet1"))
                        bulletPoint(String(localized: "welcome.excluded.bullet2"))
                    }
                }

                Divider()

                // MARK: Automatic scheduling
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "welcome.schedule.title"), systemImage: "calendar.badge.exclamationmark")
                        .font(.headline)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .frame(width: 18)
                        Text(String(localized: "welcome.schedule.warning"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    welcomeText(String(localized: "welcome.schedule.body"))
                }

                Divider()

                // MARK: Security
                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: "welcome.security.title"), systemImage: "checkmark.shield")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        bulletPoint(String(localized: "welcome.security.bullet1"))
                        bulletPoint(String(localized: "welcome.security.bullet2"))
                        bulletPoint(String(localized: "welcome.security.bullet3"))
                    }
                }

                Divider()

                // MARK: CTA
                VStack(spacing: 12) {
                    Toggle(isOn: $settings.showWelcomeOnStartup) {
                        Text(String(localized: "welcome.cta.show_on_startup"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.checkbox)

                    HStack {
                        Spacer()
                        Button(String(localized: "welcome.cta.settings")) {
                            openSettings()
                        }
                        .buttonStyle(.bordered)

                        Button(String(localized: "welcome.cta.close")) {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(28)
        }
        .frame(width: 660, height: 620)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func welcomeText(_ content: String) -> some View {
        Text(content)
            .font(.body)
            .foregroundStyle(.primary.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func bulletPoint(_ content: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.body.weight(.bold))
                .foregroundStyle(Color.accentColor)
            Text(content).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func folderBlock(symbol: String, title: String, description: String, path: String, category: DeviceCategory) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.bold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Button(String(localized: "welcome.folders.show_in_finder")) {
                    if let dir = try? category.destinationDirectory() {
                        NSWorkspace.shared.open(dir)
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
