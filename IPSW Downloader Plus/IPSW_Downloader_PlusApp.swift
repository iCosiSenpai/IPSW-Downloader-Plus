//
//  IPSW_Downloader_PlusApp.swift
//  IPSW Downloader Plus
//

import SwiftUI
import UserNotifications
import AppKit

/// View radice che gestisce la visibilità dello sheet di benvenuto.
/// Usa uno @State locale per evitare che il binding a showWelcomeOnStartup
/// riapra lo sheet immediatamente dopo la chiusura.
struct RootView: View {
    let viewModel: IPSWViewModel
    let isAutoLaunch: Bool

    @ObservedObject private var settings = AppSettings.shared

    // Stato locale per la visibilità dello sheet — inizializzato da settings ma non bindato direttamente.
    // In questo modo la chiusura del sheet non viene "riaperta" dal publisher di settings.
    // In auto-launch mode il benvenuto viene sempre soppresso.
    @State private var isShowingWelcome: Bool
    @State private var hasFullDiskAccess: Bool

    init(viewModel: IPSWViewModel, isAutoLaunch: Bool) {
        self.viewModel = viewModel
        self.isAutoLaunch = isAutoLaunch
        _isShowingWelcome = State(initialValue: isAutoLaunch ? false : AppSettings.shared.showWelcomeOnStartup)
        _hasFullDiskAccess = State(initialValue: FullDiskAccessChecker.check())
    }

    var body: some View {
        Group {
            if hasFullDiskAccess || settings.isUsingCustomDownloadDirectory {
                ContentView(viewModel: viewModel)
            } else {
                FullDiskAccessGateView(hasFullDiskAccess: $hasFullDiskAccess)
            }
        }
        .task {
            // Request notification permission on first launch
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if isAutoLaunch {
                guard hasFullDiskAccess || settings.isUsingCustomDownloadDirectory else {
                    NSApplication.shared.terminate(nil)
                    return
                }
                await viewModel.runAutoLaunchUpdate()
            }
        }
        .sheet(isPresented: Binding(
            get: { (hasFullDiskAccess || settings.isUsingCustomDownloadDirectory) && isShowingWelcome },
            set: { isShowingWelcome = $0 }
        )) {
            WelcomeView()
                .background(WindowDraggableBackground())
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasFullDiskAccess = FullDiskAccessChecker.check()
        }
        // Il toggle "non mostrare più" NON chiude il benvenuto:
        // la finestra si chiude solo con il pulsante Chiudi.
    }
}

private struct FullDiskAccessGateView: View {
    @Binding var hasFullDiskAccess: Bool
    @ObservedObject private var settings = AppSettings.shared

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
                    hasFullDiskAccess = FullDiskAccessChecker.check()
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
