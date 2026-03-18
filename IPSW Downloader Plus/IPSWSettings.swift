//
//  IPSWSettings.swift
//  IPSW Downloader Plus
//

import Foundation
import Combine
import AppKit
import Darwin

// MARK: - Delete Mode

enum DeleteMode: String, CaseIterable, Identifiable {
    case permanent = "permanent"
    case trash = "trash"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .permanent: return String(localized: "settings.delete.permanent")
        case .trash:     return String(localized: "settings.delete.trash")
        }
    }
}

// MARK: - Auto-launch Days

enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortName: String {
        Weekday.localizedShortSymbols[rawValue - 1]
    }

    private static let localizedShortSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        return formatter.shortWeekdaySymbols.map { $0.capitalized }
    }()
}

// MARK: - AppSettings

/// Centralizza tutte le preferenze dell'app salvate in UserDefaults via @AppStorage.
/// Accessibile globalmente come singleton.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()
    private let launchAgentLabel = "com.icosisenpai.ipsw-downloader-plus"
    private let autoLaunchReportKey = "lastAutoLaunchReport"

    // MARK: Onboarding

    /// true = mostra la schermata di benvenuto ad ogni avvio (default: true)
    @Published var showWelcomeOnStartup: Bool {
        didSet { UserDefaults.standard.set(showWelcomeOnStartup, forKey: "showWelcomeOnStartup") }
    }

    @Published var hasCompletedInitialSetup: Bool {
        didSet { UserDefaults.standard.set(hasCompletedInitialSetup, forKey: "hasCompletedInitialSetup") }
    }

    // MARK: Delete Mode

    @Published var deleteMode: DeleteMode {
        didSet { UserDefaults.standard.set(deleteMode.rawValue, forKey: "deleteMode") }
    }

    // MARK: Auto-launch

    @Published var autoLaunchEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoLaunchEnabled, forKey: "autoLaunchEnabled")
            updateSchedulingConfiguration()
        }
    }

    /// Ore (0-23) a cui avviare il check automatico
    @Published var autoLaunchHour: Int {
        didSet {
            UserDefaults.standard.set(autoLaunchHour, forKey: "autoLaunchHour")
            updateSchedulingConfiguration()
        }
    }

    /// Minuti (0-59)
    @Published var autoLaunchMinute: Int {
        didSet {
            UserDefaults.standard.set(autoLaunchMinute, forKey: "autoLaunchMinute")
            updateSchedulingConfiguration()
        }
    }

    /// Giorni della settimana selezionati (Set<Weekday.RawValue>)
    @Published var autoLaunchDays: Set<Int> {
        didSet {
            let arr = Array(autoLaunchDays)
            UserDefaults.standard.set(arr, forKey: "autoLaunchDays")
            updateSchedulingConfiguration()
        }
    }

    // MARK: Wake Schedule State

    /// true se `pmset repeat wakeorpoweron` è stato impostato con successo
    @Published var wakeScheduleActive: Bool = false

    /// Eventuale errore nell'impostare la sveglia pmset
    @Published var wakeScheduleError: String? = nil
    @Published private(set) var launchAgentInstalled: Bool = false
    @Published private(set) var launchAgentLoaded: Bool = false
    @Published private(set) var launchAgentError: String? = nil
    @Published private(set) var lastAutoLaunchReport: AutoLaunchReport? {
        didSet {
            persistAutoLaunchReport()
        }
    }

    // MARK: Download

    /// Numero massimo di download paralleli (1–5)
    @Published var maxConcurrentDownloads: Int {
        didSet { UserDefaults.standard.set(maxConcurrentDownloads, forKey: "maxConcurrentDownloads") }
    }

    /// Verifica checksum SHA1 dopo il download (più lento ma garantisce integrità)
    @Published var verifyChecksumAfterDownload: Bool {
        didSet { UserDefaults.standard.set(verifyChecksumAfterDownload, forKey: "verifyChecksumAfterDownload") }
    }

    /// Notifica macOS al termine di ogni download
    @Published var notifyOnDownloadComplete: Bool {
        didSet { UserDefaults.standard.set(notifyOnDownloadComplete, forKey: "notifyOnDownloadComplete") }
    }

    /// Cartella radice personalizzata per i firmware IPSW.
    /// Se vuota, l'app usa le cartelle di default di iTunes / Apple Configurator.
    @Published var customDownloadDirectoryPath: String {
        didSet { UserDefaults.standard.set(customDownloadDirectoryPath, forKey: "customDownloadDirectoryPath") }
    }

    // MARK: Product Type Filters

    /// Tipi di dispositivo da escludere dai download automatici
    @Published var excludedProductTypes: Set<String> {
        didSet {
            let arr = Array(excludedProductTypes)
            UserDefaults.standard.set(arr, forKey: "excludedProductTypes")
        }
    }

    /// Tutti i product type prefix supportati (id = chiave UserDefaults, label = nome UI)
    static let allProductTypePrefixes: [(id: String, label: String, symbol: String)] = [
        ("iPhone",          "iPhone",               "iphone"),
        ("iPad",            "iPad",                 "ipad"),
        ("iPod",            "iPod touch",           "ipodtouch"),
        ("AppleTV",         "Apple TV",             "appletv"),
        ("AudioAccessory",  "HomePod mini",         "homepod"),
        ("RealityDevice",   "Apple Vision",         "visionpro"),
        ("iBridge",         "T2 Mac (iBridge)",     "laptopcomputer"),
        ("AppleSiliconMac", "Apple Silicon Mac",    "macbook"),
    ]

    /// Restituisce la chiave del filtro per un identifier di dispositivo,
    /// usando la stessa logica di DeviceCategory per classificare correttamente ogni device.
    /// Restituisce nil per device non categorizzati (lasciati passare).
    static func productTypeKey(for identifier: String) -> String? {
        let lower = identifier.lowercased()
        if lower.hasPrefix("iphone")          { return "iPhone" }
        if lower.hasPrefix("ipad")            { return "iPad" }
        if lower.hasPrefix("ipod")            { return "iPod" }
        if lower.hasPrefix("appletv")         { return "AppleTV" }
        if lower.hasPrefix("audioaccessory")  { return "AudioAccessory" }
        if lower.hasPrefix("realitydevice")   { return "RealityDevice" }
        if lower.hasPrefix("ibridge")         { return "iBridge" }
        // Apple Silicon Mac: MacBook*, MacPro*, MacMini*, iMac*, Mac (es. Mac14,2)
        if lower.hasPrefix("macbook") || lower.hasPrefix("macpro") ||
           lower.hasPrefix("macmini") || lower.hasPrefix("imac") ||
           lower.hasPrefix("mac")             { return "AppleSiliconMac" }
        return nil
    }

    // MARK: Init

    private init() {
        let ud = UserDefaults.standard

        // Se la chiave non esiste ancora (primo avvio), il default è true
        showWelcomeOnStartup = ud.object(forKey: "showWelcomeOnStartup") as? Bool ?? true
        hasCompletedInitialSetup = ud.object(forKey: "hasCompletedInitialSetup") as? Bool ?? false
        deleteMode           = DeleteMode(rawValue: ud.string(forKey: "deleteMode") ?? "") ?? .permanent
        autoLaunchEnabled    = ud.bool(forKey: "autoLaunchEnabled")
        autoLaunchHour       = ud.object(forKey: "autoLaunchHour") as? Int ?? 3
        autoLaunchMinute     = ud.object(forKey: "autoLaunchMinute") as? Int ?? 0
        maxConcurrentDownloads     = ud.object(forKey: "maxConcurrentDownloads") as? Int ?? 3
        verifyChecksumAfterDownload = ud.object(forKey: "verifyChecksumAfterDownload") as? Bool ?? true
        notifyOnDownloadComplete    = ud.object(forKey: "notifyOnDownloadComplete") as? Bool ?? true
        customDownloadDirectoryPath = ud.string(forKey: "customDownloadDirectoryPath") ?? ""

        let days = ud.array(forKey: "autoLaunchDays") as? [Int] ?? []
        autoLaunchDays = Set(days)

        let excluded = ud.array(forKey: "excludedProductTypes") as? [String] ?? []
        excludedProductTypes = Set(excluded)
        if let data = ud.data(forKey: autoLaunchReportKey) {
            lastAutoLaunchReport = try? JSONDecoder().decode(AutoLaunchReport.self, from: data)
        } else {
            lastAutoLaunchReport = nil
        }

        // Legge lo stato attuale della sveglia pmset
        wakeScheduleActive = WakeScheduler.isWakeScheduleActive()
        refreshLaunchAgentStatus()
    }

    // MARK: - LaunchAgent

    private var launchAgentPlistURL: URL? {
        // homeDirectoryForCurrentUser bypassa la sandbox e punta alla ~/Library reale
        let libraryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        return libraryURL
            .appendingPathComponent("LaunchAgents")
            .appendingPathComponent("\(launchAgentLabel).plist")
    }

    private var launchAgentDomain: String {
        "gui/\(getuid())"
    }

    private var launchAgentServiceIdentifier: String {
        "\(launchAgentDomain)/\(launchAgentLabel)"
    }

    private func updateSchedulingConfiguration() {
        guard autoLaunchEnabled else {
            disableScheduling()
            return
        }

        installLaunchAgent()
        refreshLaunchAgentStatus()
        if wakeScheduleActive {
            wakeScheduleActive = false
            wakeScheduleError = String(localized: "settings.schedule.wake.needs_update")
        } else {
            wakeScheduleError = nil
        }
    }

    func applyWakeSchedule() {
        guard autoLaunchEnabled else {
            wakeScheduleActive = false
            wakeScheduleError = String(localized: "settings.schedule.wake.enable_first")
            return
        }

        installLaunchAgent()
        refreshLaunchAgentStatus()
        let error = WakeScheduler.scheduleWake(
            hour: autoLaunchHour,
            minute: autoLaunchMinute,
            days: autoLaunchDays
        )
        wakeScheduleError = error
        wakeScheduleActive = (error == nil)
    }

    func disableWakeSchedule() {
        let error = WakeScheduler.cancelWake()
        if let error {
            wakeScheduleError = error
            wakeScheduleActive = WakeScheduler.isWakeScheduleActive()
        } else {
            wakeScheduleActive = false
            wakeScheduleError = nil
        }
    }

    private func disableScheduling() {
        removeLaunchAgent()
        refreshLaunchAgentStatus()
        wakeScheduleActive = WakeScheduler.isWakeScheduleActive()
        if wakeScheduleActive {
            wakeScheduleError = String(localized: "settings.schedule.wake.disable_separately")
        } else {
            wakeScheduleError = nil
        }
    }

    private func installLaunchAgent() {
        guard let plistURL = launchAgentPlistURL else { return }
        installLaunchAgent(at: plistURL)
    }

    private func installLaunchAgent(at plistURL: URL) {
        guard let appPath = Bundle.main.executablePath else { return }

        // Costruisce CalendarInterval per ogni giorno selezionato
        var calendarIntervals: [[String: Any]] = []
        if autoLaunchDays.isEmpty {
            // Ogni giorno
            calendarIntervals = [["Hour": autoLaunchHour, "Minute": autoLaunchMinute]]
        } else {
            for day in autoLaunchDays.sorted() {
                calendarIntervals.append([
                    "Weekday": day,
                    "Hour": autoLaunchHour,
                    "Minute": autoLaunchMinute
                ])
            }
        }

        let plist: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [appPath, "--auto-launch"],
            "StartCalendarInterval": calendarIntervals,
            "RunAtLoad": false,
            "StandardOutPath": "/tmp/ipsw-downloader-plus.log",
            "StandardErrorPath": "/tmp/ipsw-downloader-plus-error.log"
        ]

        do {
            let dir = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL)
            let bootoutResult = runLaunchctl(arguments: ["bootout", launchAgentServiceIdentifier], ignoreFailure: true)
            let bootstrapResult = runLaunchctl(arguments: ["bootstrap", launchAgentDomain, plistURL.path], ignoreFailure: false)
            let enableResult = bootstrapResult == nil
                ? runLaunchctl(arguments: ["enable", launchAgentServiceIdentifier], ignoreFailure: false)
                : nil
            launchAgentError = bootstrapResult ?? enableResult ?? bootoutResult
        } catch {
            launchAgentError = error.localizedDescription
        }
        refreshLaunchAgentStatus()
    }

    private func removeLaunchAgent() {
        guard let plistURL = launchAgentPlistURL else { return }
        removeLaunchAgent(at: plistURL)
    }

    private func removeLaunchAgent(at plistURL: URL) {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            launchAgentError = runLaunchctl(arguments: ["bootout", launchAgentServiceIdentifier], ignoreFailure: true)
            try? FileManager.default.removeItem(at: plistURL)
        }
        refreshLaunchAgentStatus()
    }

    // MARK: - Helpers

    /// Restituisce true se il product type prefix è attivo (non escluso)
    func isProductTypeEnabled(_ prefix: String) -> Bool {
        !excludedProductTypes.contains(prefix)
    }

    /// Abilita/disabilita un product type.
    /// Restituisce false e non fa nulla se l'operazione lascerebbe zero categorie attive.
    @discardableResult
    func setProductType(_ prefix: String, enabled: Bool) -> Bool {
        if enabled {
            excludedProductTypes.remove(prefix)
            return true
        } else {
            // Conta le categorie attualmente attive
            let totalKeys = Set(AppSettings.allProductTypePrefixes.map(\.id))
            let wouldRemain = totalKeys.subtracting(excludedProductTypes).subtracting([prefix])
            guard !wouldRemain.isEmpty else { return false }   // Almeno 1 deve restare attiva
            excludedProductTypes.insert(prefix)
            return true
        }
    }

    /// true se tutte le categorie sono disabilitate (stato invalido, non dovrebbe accadere)
    var hasAtLeastOneEnabledType: Bool {
        let totalKeys = Set(AppSettings.allProductTypePrefixes.map(\.id))
        return !totalKeys.subtracting(excludedProductTypes).isEmpty
    }

    /// Human-readable description of the scheduled time
    var scheduleDescription: String {
        guard autoLaunchEnabled else { return String(localized: "schedule.disabled") }
        let time = String(format: "%02d:%02d", autoLaunchHour, autoLaunchMinute)
        if autoLaunchDays.isEmpty {
            return String(format: String(localized: "schedule.every_day"), time)
        }
        let names = autoLaunchDays.sorted()
            .compactMap { Weekday(rawValue: $0)?.shortName }
            .joined(separator: ", ")
        return String(format: String(localized: "schedule.days"), names, time)
    }

    var launchAgentStatusDescription: String {
        if let launchAgentError, !launchAgentError.isEmpty {
            return String(format: String(localized: "settings.schedule.agent.error"), launchAgentError)
        }
        if launchAgentLoaded {
            return String(localized: "settings.schedule.agent.loaded")
        }
        if launchAgentInstalled {
            return String(localized: "settings.schedule.agent.installed")
        }
        return String(localized: "settings.schedule.agent.missing")
    }

    var lastAutoLaunchReportDescription: String? {
        guard let report = lastAutoLaunchReport else { return nil }
        return String(
            format: String(localized: "settings.schedule.report.summary"),
            report.checkedCount,
            report.downloadedCount,
            report.skippedCount,
            report.failedCount
        )
    }

    func recordAutoLaunchReport(_ report: AutoLaunchReport) {
        lastAutoLaunchReport = report
    }

    func clearAutoLaunchReport() {
        lastAutoLaunchReport = nil
    }

    var isUsingCustomDownloadDirectory: Bool {
        !customDownloadDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var customDownloadDirectoryURL: URL? {
        Self.storedCustomDownloadDirectoryURL()
    }

    var customDownloadDirectoryDisplayPath: String {
        customDownloadDirectoryURL?.path(percentEncoded: false) ?? String(localized: "settings.general.folders.default_path")
    }

    @MainActor
    func chooseCustomDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "settings.general.folders.choose")
        panel.message = String(localized: "settings.general.folders.choose_message")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if let url = customDownloadDirectoryURL {
            panel.directoryURL = url
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }
        customDownloadDirectoryPath = url.standardizedFileURL.path
    }

    func resetCustomDownloadDirectory() {
        customDownloadDirectoryPath = ""
    }

    nonisolated static func storedCustomDownloadDirectoryURL() -> URL? {
        let rawPath = UserDefaults.standard.string(forKey: "customDownloadDirectoryPath") ?? ""
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed, isDirectory: true).standardizedFileURL
    }

    private func refreshLaunchAgentStatus() {
        guard let plistURL = launchAgentPlistURL else {
            launchAgentInstalled = false
            launchAgentLoaded = false
            return
        }

        launchAgentInstalled = FileManager.default.fileExists(atPath: plistURL.path)
        guard launchAgentInstalled else {
            launchAgentLoaded = false
            return
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", launchAgentServiceIdentifier]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            launchAgentLoaded = process.terminationStatus == 0
            if process.terminationStatus == 0 {
                if launchAgentError?.isEmpty ?? true {
                    launchAgentError = nil
                }
            }
        } catch {
            launchAgentLoaded = false
            launchAgentError = error.localizedDescription
        }
    }

    private func runLaunchctl(arguments: [String], ignoreFailure: Bool) -> String? {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus != 0 else { return nil }
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let message = (
                String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            ).flatMap { $0.isEmpty ? nil : $0 }
            ?? (
                String(data: outputData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            ).flatMap { $0.isEmpty ? nil : $0 }
            return ignoreFailure ? nil : (message?.isEmpty == false ? message : String(localized: "settings.schedule.agent.command_failed"))
        } catch {
            return ignoreFailure ? nil : error.localizedDescription
        }
    }

    private func persistAutoLaunchReport() {
        let defaults = UserDefaults.standard
        guard let report = lastAutoLaunchReport else {
            defaults.removeObject(forKey: autoLaunchReportKey)
            return
        }
        guard let data = try? JSONEncoder().encode(report) else { return }
        defaults.set(data, forKey: autoLaunchReportKey)
    }
}
