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

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private(set) var windowController: NSWindowController?

    func open() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = windowController?.window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsRootView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: "settings.menu.open")
        window.setContentSize(NSSize(width: 720, height: 560))
        window.minSize = NSSize(width: 720, height: 560)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        window.setFrameAutosaveName("IPSWDownloaderPlusSettings")

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
    }

    func windowWillClose(_ notification: Notification) {
        windowController = nil
    }
}

private struct SettingsRootView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SettingsView()
            .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
            .tint(settings.selectedTheme.tintColor)
    }
}

enum SettingsPresenter {
    @MainActor
    private static let controller = SettingsWindowController()

    @MainActor
    static func open() {
        controller.open()
    }
}

/// View radice che gestisce l'onboarding iniziale e l'accesso alle cartelle protette.
struct RootView: View {
    let viewModel: IPSWViewModel
    let isAutoLaunch: Bool

    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var isShowingWelcome: Bool
    @State private var isShowingSetup: Bool
    @State private var fullDiskAccessStatus: FullDiskAccessStatus
    @State private var shouldPresentSetupAfterWelcome: Bool

    init(viewModel: IPSWViewModel, isAutoLaunch: Bool) {
        self.viewModel = viewModel
        self.isAutoLaunch = isAutoLaunch
        let shouldOpenWelcome = isAutoLaunch ? false : AppSettings.shared.showWelcomeOnStartup
        let shouldOpenSetupDirectly = isAutoLaunch ? false : !AppSettings.shared.hasCompletedInitialSetup && !AppSettings.shared.showWelcomeOnStartup
        _isShowingWelcome = State(initialValue: isAutoLaunch ? false : AppSettings.shared.showWelcomeOnStartup)
        _isShowingSetup = State(initialValue: shouldOpenSetupDirectly)
        _fullDiskAccessStatus = State(initialValue: FullDiskAccessChecker.status())
        _shouldPresentSetupAfterWelcome = State(initialValue: shouldOpenWelcome && !AppSettings.shared.hasCompletedInitialSetup)
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
        .background(settings.selectedTheme.windowBackgroundColor(for: colorScheme))
        .task {
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
            if !isAutoLaunch && shouldPresentSetupAfterWelcome && !settings.hasCompletedInitialSetup {
                isShowingSetup = true
            }
        }) {
            WelcomeView(
                selectedTheme: settings.selectedTheme,
                showWelcomeOnStartup: $settings.showWelcomeOnStartup
            ) {
                isShowingWelcome = false
                if shouldPresentSetupAfterWelcome && !settings.hasCompletedInitialSetup {
                    isShowingSetup = true
                }
            }
            .modifier(SheetDragBackgroundIfAvailable())
        }
        .sheet(isPresented: $isShowingSetup) {
            InitialSetupView(
                selectedTheme: settings.selectedTheme,
                showWelcomeOnStartup: $settings.showWelcomeOnStartup,
                customDownloadDirectoryPath: $settings.customDownloadDirectoryPath,
                fullDiskAccessStatus: $fullDiskAccessStatus,
                chooseCustomDownloadDirectory: settings.chooseCustomDownloadDirectory,
                resetCustomDownloadDirectory: settings.resetCustomDownloadDirectory
            ) {
                settings.hasCompletedInitialSetup = true
                isShowingSetup = false
            }
            .modifier(SheetDragBackgroundIfAvailable())
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            fullDiskAccessStatus = FullDiskAccessChecker.status()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showWelcomeFlow)) { _ in
            guard !isAutoLaunch else { return }
            shouldPresentSetupAfterWelcome = false
            isShowingSetup = false
            isShowingWelcome = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showInitialSetupFlow)) { _ in
            guard !isAutoLaunch else { return }
            fullDiskAccessStatus = FullDiskAccessChecker.status()
            shouldPresentSetupAfterWelcome = false
            isShowingWelcome = false
            isShowingSetup = true
        }
    }

    private var requiresFullDiskAccessGate: Bool {
        settings.hasCompletedInitialSetup &&
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
                    .foregroundColor(.secondary)
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

private struct SheetDragBackgroundIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if AppCompatibility.usesLegacySwiftUIWorkarounds {
            content
        } else {
            content.background(WindowDraggableBackground())
        }
    }
}

@main
struct IPSW_Downloader_PlusApp: App {

    @StateObject private var viewModel = IPSWViewModel()
    @ObservedObject private var settings = AppSettings.shared

    /// true se l'app è stata avviata dal LaunchAgent con --auto-launch
    private let isAutoLaunch = CommandLine.arguments.contains("--auto-launch")

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel, isAutoLaunch: isAutoLaunch)
                .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
                .tint(settings.selectedTheme.tintColor)
        }
        .commands {
            AppSettingsCommands()
            AppDownloadCommands(viewModel: viewModel)
        }
    }
}

private struct AppSettingsCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(String(localized: "settings.menu.open")) {
                SettingsPresenter.open()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

struct AppDownloadCommands: Commands {
    @ObservedObject var viewModel: IPSWViewModel

    var body: some Commands {
        CommandMenu(String(localized: "menu.downloads")) {
            Button(String(localized: "menu.download_selected")) {
                viewModel.downloadSelectedDevices()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(viewModel.selectedDeviceIDs.isEmpty)

            Button(String(localized: "menu.pause_all")) {
                viewModel.pauseAllManagedDownloads()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(!viewModel.hasActiveDownloads)

            Button(String(localized: "menu.resume_all")) {
                viewModel.resumeAllPausedDownloads()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!viewModel.hasPausedDownloads)

            Button(String(localized: "menu.retry_failed")) {
                viewModel.retryAllFailed()
            }
            .disabled(!viewModel.hasFailedDownloads)

            Button(String(localized: "menu.open_folder")) {
                viewModel.openDownloadFolder()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button(String(localized: "menu.select_all")) {
                viewModel.selectAll()
            }
            .keyboardShortcut("a", modifiers: .command)

            Button(String(localized: "menu.deselect_all")) {
                viewModel.deselectAll()
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button(String(localized: "menu.invert_selection")) {
                viewModel.invertSelection()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }
    }
}
