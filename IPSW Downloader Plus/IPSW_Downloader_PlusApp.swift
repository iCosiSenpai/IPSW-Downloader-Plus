//
//  IPSW_Downloader_PlusApp.swift
//  IPSW Downloader Plus
//

import SwiftUI
import UserNotifications
import AppKit

extension Notification.Name {
    static let showWelcomeFlow = Notification.Name("showWelcomeFlow")
    static let showInitialSetupFlow = Notification.Name("showInitialSetupFlow")
}

/// View radice che gestisce l'onboarding iniziale e l'accesso alle cartelle protette.
struct RootView: View {
    let viewModel: IPSWViewModel
    let isAutoLaunch: Bool

    @ObservedObject private var settings = AppSettings.shared

    @State private var isShowingWelcome: Bool
    @State private var isShowingSetup: Bool
    @State private var fullDiskAccessStatus: FullDiskAccessStatus

    init(viewModel: IPSWViewModel, isAutoLaunch: Bool) {
        self.viewModel = viewModel
        self.isAutoLaunch = isAutoLaunch
        _isShowingWelcome = State(initialValue: isAutoLaunch ? false : AppSettings.shared.showWelcomeOnStartup)
        _isShowingSetup = State(initialValue: isAutoLaunch ? false : !AppSettings.shared.hasCompletedInitialSetup && !AppSettings.shared.showWelcomeOnStartup)
        _fullDiskAccessStatus = State(initialValue: FullDiskAccessChecker.status())
    }

    var body: some View {
        Group {
            if requiresFullDiskAccessGate {
                FullDiskAccessGateView(fullDiskAccessStatus: $fullDiskAccessStatus) {
                    isShowingSetup = true
                }
            } else {
                ContentView(viewModel: viewModel)
            }
        }
        .task {
            // Request notification permission on first launch
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if isAutoLaunch {
                guard fullDiskAccessStatus != .denied || settings.isUsingCustomDownloadDirectory else {
                    NSApplication.shared.terminate(nil)
                    return
                }
                await viewModel.runAutoLaunchUpdate()
            }
        }
        .sheet(isPresented: $isShowingWelcome, onDismiss: {
            if !isAutoLaunch && !settings.hasCompletedInitialSetup {
                isShowingSetup = true
            }
        }) {
            WelcomeView {
                isShowingWelcome = false
                if !settings.hasCompletedInitialSetup {
                    isShowingSetup = true
                }
            }
                .background(WindowDraggableBackground())
        }
        .sheet(isPresented: $isShowingSetup) {
            InitialSetupView(fullDiskAccessStatus: $fullDiskAccessStatus) {
                settings.hasCompletedInitialSetup = true
                isShowingSetup = false
            }
            .background(WindowDraggableBackground())
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            fullDiskAccessStatus = FullDiskAccessChecker.status()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showWelcomeFlow)) { _ in
            guard !isAutoLaunch else { return }
            isShowingSetup = false
            isShowingWelcome = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showInitialSetupFlow)) { _ in
            guard !isAutoLaunch else { return }
            fullDiskAccessStatus = FullDiskAccessChecker.status()
            isShowingWelcome = false
            isShowingSetup = true
        }
    }

    private var requiresFullDiskAccessGate: Bool {
        !isShowingWelcome &&
        !isShowingSetup &&
        !settings.isUsingCustomDownloadDirectory &&
        fullDiskAccessStatus == .denied
    }
}

private struct FullDiskAccessGateView: View {
    @Binding var fullDiskAccessStatus: FullDiskAccessStatus
    @ObservedObject private var settings = AppSettings.shared
    let openSetup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label(String(localized: "fda.required.title"), systemImage: "externaldrive.badge.exclamationmark")
                    .font(.title2.weight(.semibold))
                Text(String(localized: "fda.required.body"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FDAStatusBanner(showGuide: true)

            HStack {
                Button(String(localized: "fda.required.quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(String(localized: "welcome.fda.recheck")) {
                    fullDiskAccessStatus = FullDiskAccessChecker.status()
                }
                .buttonStyle(.bordered)

                Button(String(localized: "settings.general.folders.choose")) {
                    settings.chooseCustomDownloadDirectory()
                }
                .buttonStyle(.bordered)

                Button(String(localized: "welcome.fda.button")) {
                    FullDiskAccessChecker.openPrivacySettings()
                }
                .buttonStyle(.borderedProminent)

                Button(String(localized: "setup.open")) {
                    openSetup()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(28)
        .frame(minWidth: 720, minHeight: 420, alignment: .topLeading)
    }
}

/// Sfondo trasparente che rende la finestra dello sheet spostabile trascinando ovunque.
private struct WindowDraggableBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableHostView()
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class DraggableHostView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isMovableByWindowBackground = true
    }
}

@main
struct IPSW_Downloader_PlusApp: App {

    @StateObject private var viewModel = IPSWViewModel()

    /// true se l'app è stata avviata dal LaunchAgent con --auto-launch
    private let isAutoLaunch = CommandLine.arguments.contains("--auto-launch")

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel, isAutoLaunch: isAutoLaunch)
        }
        .commands {
            AppSettingsCommands()
        }

        Window(String(localized: "settings.window.title"), id: "settings") {
            SettingsView()
        }
        .defaultSize(width: 560, height: 420)
        .windowResizability(.contentSize)
    }
}

private struct AppSettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(String(localized: "settings.menu.open")) {
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
