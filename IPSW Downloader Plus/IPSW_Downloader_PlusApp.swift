//
//  IPSW_Downloader_PlusApp.swift
//  IPSW Downloader Plus
//

import SwiftUI
import UserNotifications

/// View radice che gestisce la visibilità dello sheet di benvenuto.
/// Usa uno @State locale per evitare che il binding a showWelcomeOnStartup
/// riapra lo sheet immediatamente dopo la chiusura.
struct RootView: View {
    let viewModel: IPSWViewModel
    let isAutoLaunch: Bool

    @ObservedObject private var settings = AppSettings.shared

    // Stato locale per la visibilità dello sheet — inizializzato da settings ma non bindato direttamente.
    // In questo modo la chiusura del sheet non viene "riaperta" dal publisher di settings.
    @State private var isShowingWelcome = AppSettings.shared.showWelcomeOnStartup

    var body: some View {
        ContentView(viewModel: viewModel)
            .task {
                // Request notification permission on first launch
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                if isAutoLaunch {
                    await viewModel.runAutoLaunchUpdate()
                }
            }
            .sheet(isPresented: $isShowingWelcome) {
                WelcomeView()
            }
            .onChange(of: settings.showWelcomeOnStartup) { _, newValue in
                if !newValue {
                    isShowingWelcome = false
                }
            }
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

        // Finestra Impostazioni nativa macOS (⌘,)
        Settings {
            SettingsView()
        }
    }
}
