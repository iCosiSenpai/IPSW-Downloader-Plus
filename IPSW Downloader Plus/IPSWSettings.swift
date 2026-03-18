//
//  IPSWSettings.swift
//  IPSW Downloader Plus
//

import Foundation
import Combine

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
        Weekday.italianShortSymbols[rawValue - 1]
    }

    // DateFormatter è costoso da creare ad ogni accesso, lo cacchiamo come static
    private static let italianShortSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.shortWeekdaySymbols.map { $0.capitalized }
    }()
}

// MARK: - AppSettings

/// Centralizza tutte le preferenze dell'app salvate in UserDefaults via @AppStorage.
/// Accessibile globalmente come singleton.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: Onboarding

    /// true = mostra la schermata di benvenuto ad ogni avvio (default: true)
    @Published var showWelcomeOnStartup: Bool {
        didSet { UserDefaults.standard.set(showWelcomeOnStartup, forKey: "showWelcomeOnStartup") }
    }

    // MARK: Delete Mode

    @Published var deleteMode: DeleteMode {
        didSet { UserDefaults.standard.set(deleteMode.rawValue, forKey: "deleteMode") }
    }

    // MARK: Auto-launch

    @Published var autoLaunchEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoLaunchEnabled, forKey: "autoLaunchEnabled")
            scheduleOrRemoveLaunchAgent()
        }
    }

    /// Ore (0-23) a cui avviare il check automatico
    @Published var autoLaunchHour: Int {
        didSet {
            UserDefaults.standard.set(autoLaunchHour, forKey: "autoLaunchHour")
            scheduleOrRemoveLaunchAgent()
        }
    }

    /// Minuti (0-59)
    @Published var autoLaunchMinute: Int {
        didSet {
            UserDefaults.standard.set(autoLaunchMinute, forKey: "autoLaunchMinute")
            scheduleOrRemoveLaunchAgent()
        }
    }

    /// Giorni della settimana selezionati (Set<Weekday.RawValue>)
    @Published var autoLaunchDays: Set<Int> {
        didSet {
            let arr = Array(autoLaunchDays)
            UserDefaults.standard.set(arr, forKey: "autoLaunchDays")
            scheduleOrRemoveLaunchAgent()
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
        deleteMode           = DeleteMode(rawValue: ud.string(forKey: "deleteMode") ?? "") ?? .permanent
        autoLaunchEnabled    = ud.bool(forKey: "autoLaunchEnabled")
        autoLaunchHour       = ud.object(forKey: "autoLaunchHour") as? Int ?? 3
        autoLaunchMinute     = ud.object(forKey: "autoLaunchMinute") as? Int ?? 0
        maxConcurrentDownloads     = ud.object(forKey: "maxConcurrentDownloads") as? Int ?? 3
        verifyChecksumAfterDownload = ud.object(forKey: "verifyChecksumAfterDownload") as? Bool ?? true
        notifyOnDownloadComplete    = ud.object(forKey: "notifyOnDownloadComplete") as? Bool ?? true

        let days = ud.array(forKey: "autoLaunchDays") as? [Int] ?? []
        autoLaunchDays = Set(days)

        let excluded = ud.array(forKey: "excludedProductTypes") as? [String] ?? []
        excludedProductTypes = Set(excluded)
    }

    // MARK: - LaunchAgent

    private var launchAgentPlistURL: URL? {
        guard let libraryURL = try? FileManager.default.url(
            for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        else { return nil }
        return libraryURL
            .appendingPathComponent("LaunchAgents")
            .appendingPathComponent("com.icosisenpai.ipsw-downloader-plus.plist")
    }

    func scheduleOrRemoveLaunchAgent() {
        guard let plistURL = launchAgentPlistURL else { return }

        if autoLaunchEnabled {
            installLaunchAgent(at: plistURL)
        } else {
            removeLaunchAgent(at: plistURL)
        }
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
            "Label": "com.icosisenpai.ipsw-downloader-plus",
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
            // Carica/aggiorna il LaunchAgent senza richiedere il reboot
            _ = try? Process.run(
                URL(fileURLWithPath: "/bin/launchctl"),
                arguments: ["load", "-w", plistURL.path]
            )
        } catch {
            // Logging silenzioso — non critico
        }
    }

    private func removeLaunchAgent(at plistURL: URL) {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            _ = try? Process.run(
                URL(fileURLWithPath: "/bin/launchctl"),
                arguments: ["unload", plistURL.path]
            )
            try? FileManager.default.removeItem(at: plistURL)
        }
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
}
