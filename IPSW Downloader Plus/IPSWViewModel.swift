//
//  IPSWViewModel.swift
//  IPSW Downloader Plus
//

import Foundation
import Combine
import SwiftUI
import AppKit
import UserNotifications

@MainActor
final class IPSWViewModel: ObservableObject {

    // MARK: - Published State

    @Published var devices: [IPSWDevice] = []
    @Published var selectedDeviceIDs: Set<String> = []
    @Published var selectedManagedDownloadIDs: Set<String> = []
    @Published var downloadTasks: [String: DeviceDownloadTask] = [:]
    @Published private(set) var downloadedFirmware: [LocalFirmwareRecord] = []
    @Published var isLoadingDevices = false
    @Published var deviceLoadError: String? = nil
    @Published var searchText = ""
    @Published var sortOption: SidebarSortOption = .name {
        didSet {
            guard sortOption != oldValue else { return }
            sortAscending = sortOption.defaultAscending
        }
    }
    @Published var sortAscending = SidebarSortOption.name.defaultAscending
    @Published private(set) var deviceSortMetadata: [String: DeviceSortMetadata] = [:]
    @Published private(set) var activityLog: [ActivityLogEntry] = []
    @Published var activeDeviceTypeFilter: String? = nil

    // Riferimento alle impostazioni globali
    private let settings = AppSettings.shared

    // Mappa identifier -> IPSWDownloader attivo
    private var activeDownloaders: [String: IPSWDownloader] = [:]
    // Include sia il fetch API sia il download effettivo, così il throttling copre l'intero flusso.
    private var activeDownloadIdentifiers: Set<String> = []
    // Mappa identifier -> Task di download (annullabile per interrompere anche il fetch API iniziale)
    private var downloadTaskHandles: [String: Task<Void, Never>] = [:]
    private var pendingDownloadQueue: [String] = []
    private var resumeDataStore: [String: Data] = [:]
    private var metadataLoadTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private let directoryMonitor = LocalFirmwareDirectoryMonitor()
    private let maxDownloadRetryCount = 2
    private let activityLogLimit = 120
    private let persistenceDebounceInterval: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(600)
    private let statePersistenceURL: URL
    private var isRestoringPersistedState = false
    private var hasResumedPersistedDownloads = false

    init() {
        let appSupportDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("IPSW Downloader Plus", isDirectory: true)
        self.statePersistenceURL = appSupportDirectory.appendingPathComponent("state.json")

        restorePersistedState()

        settings.$customDownloadDirectoryPath
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.restartDirectoryMonitoring()
                self?.refreshLocalFirmwareState()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refreshLocalFirmwareState()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.persistState()
            }
            .store(in: &cancellables)

        Publishers.Merge3(
            $selectedDeviceIDs.map { _ in () },
            $downloadTasks.map { _ in () },
            $activityLog.map { _ in () }
        )
        .debounce(for: persistenceDebounceInterval, scheduler: DispatchQueue.main)
        .sink { [weak self] in
            self?.persistStateIfNeeded()
        }
        .store(in: &cancellables)

        $downloadTasks
            .map { _ in () }
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateDockBadge()
            }
            .store(in: &cancellables)

        restartDirectoryMonitoring()
    }

    // MARK: - Selected Devices (ordered for DetailView)

    /// Dispositivi selezionati ordinati per nome, usato da DetailView e onDelete.
    var orderedSelectedDevices: [IPSWDevice] {
        Array(selectedDeviceIDs)
            .compactMap { id in devices.first(where: { $0.identifier == id }) }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Filtered Devices

    /// Applica ricerca testuale + filtro per product type + esclude device non gestiti/irrilevanti
    private var visibleDevices: [IPSWDevice] {
        devices.filter { device in
            let id = device.identifier
            let lower = id.lowercased()

            // Escludi device irrilevanti noti
            if id == "ADP3,2" { return false }               // Apple Silicon Dev Transition Kit (bloccato a macOS 11.2.3)
            if lower.hasPrefix("virtualmac") { return false } // Apple Silicon VM — ridondante

            // Escludi tipi non gestiti dall'app (Apple Watch, AirPods, ecc.)
            // Se productTypeKey ritorna nil il device non appartiene a nessuna categoria
            // supportata → lo escludiamo silenziosamente
            guard let key = AppSettings.productTypeKey(for: id) else { return false }

            // Filtro product type dalle impostazioni
            if !settings.isProductTypeEnabled(key) { return false }

            // Filtro tipo dispositivo (chip sidebar)
            if let typeFilter = activeDeviceTypeFilter {
                guard AppSettings.productTypeKey(for: id) == typeFilter else { return false }
            }

            // Filtro testo di ricerca
            if searchText.isEmpty { return true }
            return device.name.localizedCaseInsensitiveContains(searchText) ||
                   device.identifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var filteredDevices: [IPSWDevice] {
        visibleDevices.sorted(by: compareDevices(_:_:))
    }

    var activeSortSummary: String {
        sortOption.localizedTitle
    }

    // MARK: - Device Type Filter Chips

    /// Available device type filters based on currently visible devices
    var availableDeviceTypeFilters: [(id: String, label: String, symbol: String, count: Int)] {
        var counts: [String: Int] = [:]
        for device in devices {
            guard let key = AppSettings.productTypeKey(for: device.identifier) else { continue }
            guard settings.isProductTypeEnabled(key) else { continue }
            counts[key, default: 0] += 1
        }
        return AppSettings.allProductTypePrefixes
            .compactMap { item in
                guard let count = counts[item.id], count > 0 else { return nil }
                return (id: item.id, label: item.label, symbol: item.symbol, count: count)
            }
    }

    // MARK: - Search Result Counter

    var deviceCountLabel: String {
        let filtered = filteredDevices.count
        let total = visibleDevices.count
        if !searchText.isEmpty && filtered != total {
            return String(format: String(localized: "sidebar.device_count.filtered"), filtered, total)
        }
        return String(format: String(localized: "sidebar.device_count"), filtered)
    }

    // MARK: - Global Download Progress

    var hasActiveDownloads: Bool {
        downloadTasks.values.contains { task in
            switch task.state {
            case .downloading, .queued, .verifying:
                return true
            default:
                return false
            }
        }
    }

    var globalProgressFraction: Double {
        let activeTasks = downloadTasks.values.filter { task in
            switch task.state {
            case .downloading, .queued, .verifying:
                return true
            default:
                return false
            }
        }
        guard !activeTasks.isEmpty else { return 0 }
        let total = activeTasks.reduce(0.0) { acc, task in
            if case .downloading(let progress) = task.state { return acc + progress }
            if case .verifying = task.state { return acc + 0.99 }
            return acc
        }
        return total / Double(activeTasks.count)
    }

    var globalProgressTitle: String {
        let count = downloadTasks.values.filter { task in
            switch task.state {
            case .downloading, .queued, .verifying:
                return true
            default:
                return false
            }
        }.count
        let percent = Int(globalProgressFraction * 100)
        return String(format: String(localized: "detail.global_progress"), count, percent)
    }

    // MARK: - Total Download Stats

    var totalBytesDownloaded: Int64 {
        downloadTasks.values.compactMap(\.progressDetails).reduce(0) { $0 + $1.bytesWritten }
    }

    var totalBytesExpected: Int64 {
        downloadTasks.values.compactMap(\.progressDetails).reduce(0) { $0 + $1.totalBytesExpected }
    }

    var totalDownloadSpeed: Double {
        downloadTasks.values.compactMap(\.progressDetails).reduce(0.0) { $0 + $1.bytesPerSecond }
    }

    var downloadStatsText: String {
        guard totalBytesExpected > 0 else { return "" }
        let downloaded = ByteCountFormatter.string(fromByteCount: totalBytesDownloaded, countStyle: .file)
        let expected = ByteCountFormatter.string(fromByteCount: totalBytesExpected, countStyle: .file)
        let speed = ByteCountFormatter.string(fromByteCount: Int64(totalDownloadSpeed), countStyle: .file)
        return "\(downloaded) / \(expected) — \(speed)/s"
    }

    var recentActivityEntries: [ActivityLogEntry] {
        Array(activityLog.prefix(30))
    }

    var managedDownloadDevices: [IPSWDevice] {
        downloadTasks.values
            .filter { task in
                switch task.state {
                case .queued, .paused, .downloading, .verifying:
                    return true
                default:
                    return false
                }
            }
            .map(\.device)
            .sorted { $0.name < $1.name }
    }

    // MARK: - Load Devices

    func loadDevices() async {
        isLoadingDevices = true
        deviceLoadError = nil
        do {
            devices = try await IPSWAPIClient.shared.fetchDevices()
            appendActivity(
                kind: .success,
                deviceIdentifier: nil,
                title: String(localized: "activity.devices_loaded.title"),
                message: String(format: String(localized: "activity.devices_loaded.message"), devices.count)
            )
            deviceSortMetadata.removeAll()
            metadataLoadTask?.cancel()
            metadataLoadTask = Task { [weak self] in
                await self?.loadSortMetadata(for: self?.devices ?? [])
            }
        } catch {
            deviceLoadError = error.localizedDescription
            appendActivity(
                kind: .error,
                deviceIdentifier: nil,
                title: String(localized: "activity.devices_failed.title"),
                message: error.localizedDescription
            )
        }
        isLoadingDevices = false
        restartDirectoryMonitoring()
        refreshLocalFirmwareState()
        resumePersistedDownloadsIfNeeded()
    }

    // MARK: - Selection

    /// Ultimo device cliccato — usato per il range con Shift+click
    private var lastClickedIndex: Int? = nil

    func toggleSelection(device: IPSWDevice) {
        if selectedDeviceIDs.contains(device.identifier) {
            selectedDeviceIDs.remove(device.identifier)
        } else {
            selectedDeviceIDs.insert(device.identifier)
        }
        lastClickedIndex = filteredDevices.firstIndex(where: { $0.identifier == device.identifier })
    }

    /// Gestisce il click con eventuale Shift per selezionare un range.
    func handleClick(on device: IPSWDevice, shiftHeld: Bool) {
        let list = filteredDevices
        guard let clickedIndex = list.firstIndex(where: { $0.identifier == device.identifier }) else {
            toggleSelection(device: device)
            return
        }

        if shiftHeld, let anchor = lastClickedIndex {
            // Seleziona l'intervallo tra anchor e clickedIndex (inclusi)
            let lo = min(anchor, clickedIndex)
            let hi = max(anchor, clickedIndex)
            let rangeIDs = list[lo...hi].map(\.identifier)
            // Se il device di destinazione era già selezionato, deseleziona il range
            let shouldSelect = !selectedDeviceIDs.contains(device.identifier)
            if shouldSelect {
                rangeIDs.forEach { selectedDeviceIDs.insert($0) }
            } else {
                rangeIDs.forEach { selectedDeviceIDs.remove($0) }
            }
        } else {
            toggleSelection(device: device)
        }
        lastClickedIndex = clickedIndex
    }

    func isSelected(_ device: IPSWDevice) -> Bool {
        selectedDeviceIDs.contains(device.identifier)
    }

    /// true se c'è almeno un device selezionato (anche fuori dai filtri attivi)
    var hasSelection: Bool { !selectedDeviceIDs.isEmpty }

    func selectAll() {
        selectedDeviceIDs = Set(filteredDevices.map(\.identifier))
    }

    func deselectAll() {
        selectedDeviceIDs.removeAll()
    }

    // MARK: - Templates

    /// Stato del template "Ultimi iOS/iPadOS" (usato dalla UI per mostrare il loading).
    @Published var isApplyingLatestIOSTemplate = false
    /// Messaggio di errore dell'ultimo template fallito (nil = ok).
    @Published var templateError: String? = nil

    /// Seleziona tutti i device iPhone e iPad che ricevono l'ultimo iOS/iPadOS firmato.
    /// Completamente API-driven e future-proof: chiama /v4/releases per la versione corrente,
    /// poi /v4/ipsw/{version} per gli identifier compatibili con firmware firmato.
    func applyTemplateLatestIOS() {
        Task {
            isApplyingLatestIOSTemplate = true
            templateError = nil
            defer { isApplyingLatestIOSTemplate = false }
            do {
                let version = try await IPSWAPIClient.shared.fetchLatestIOSVersion()
                let signedIDs = try await IPSWAPIClient.shared.fetchSignedDeviceIdentifiers(for: version)
                // Interseca con i device iPhone/iPad presenti nella lista locale
                let matching = devices.filter {
                    let lower = $0.identifier.lowercased()
                    return (lower.hasPrefix("iphone") || lower.hasPrefix("ipad")) &&
                           signedIDs.contains($0.identifier)
                }
                selectedDeviceIDs = Set(matching.map(\.identifier))
            } catch {
                templateError = String(format: String(localized: "template.error.latest_ios"), error.localizedDescription)
            }
        }
    }

    /// Identifier dei device iPhone/iPad vintage e obsoleti (fonte: support.apple.com/it-it/102772).
    /// Aggiornato a marzo 2026.
    static let vintageIdentifiers: Set<String> = [
        // iPhone vintage (worldwide)
        "iPhone8,1",  // iPhone 6s
        "iPhone8,2",  // iPhone 6s Plus
        "iPhone8,4",  // iPhone SE (1st gen)
        "iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4",  // iPhone 7 / 7 Plus
        "iPhone10,1", "iPhone10,2", "iPhone10,3", "iPhone10,4", "iPhone10,5", "iPhone10,6",  // iPhone 8 / 8 Plus / X
        "iPhone11,2", "iPhone11,4", "iPhone11,6",  // iPhone XS / XS Max
        "iPhone11,8",  // iPhone XR
        "iPhone12,3", "iPhone12,5",  // iPhone 11 Pro / 11 Pro Max
        "iPhone12,1",  // iPhone 11
        "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4",  // iPhone 12 mini / 12 / 12 Pro / 12 Pro Max
        // iPad vintage
        "iPad5,3", "iPad5,4",  // iPad Air 2
        "iPad6,7", "iPad6,8",  // iPad Pro 12.9" (1st gen)
        "iPad6,3", "iPad6,4",  // iPad Pro 9.7"
        "iPad7,1", "iPad7,2",  // iPad Pro 12.9" (2nd gen)
        "iPad7,3", "iPad7,4",  // iPad Pro 10.5"
        "iPad7,5", "iPad7,6",  // iPad (6th gen)
        "iPad7,11", "iPad7,12",  // iPad (7th gen)
        "iPad11,1", "iPad11,2",  // iPad mini (5th gen)
        "iPad11,3", "iPad11,4",  // iPad Air (3rd gen)
        "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4",   // iPad Pro 11" (1st gen)
        "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8",   // iPad Pro 12.9" (3rd gen)
    ]

    /// Seleziona i device iPhone e iPad vintage (support.apple.com/it-it/102772).
    /// Opera sull'intera lista devices (indipendentemente dai filtri UI o dalla ricerca attiva).
    func applyTemplateVintage() {
        let vintageDevices = devices.filter {
            let lower = $0.identifier.lowercased()
            return (lower.hasPrefix("iphone") || lower.hasPrefix("ipad")) &&
                   Self.vintageIdentifiers.contains($0.identifier)
        }
        selectedDeviceIDs = Set(vintageDevices.map(\.identifier))
    }

    // MARK: - Download Selected

    func downloadSelectedDevices() {
        for id in selectedDeviceIDs {
            guard let device = devices.first(where: { $0.identifier == id }) else { continue }
            scheduleDownload(for: device)
        }
    }

    func startDownload(for device: IPSWDevice) async {
        scheduleDownload(for: device)
    }

    func toggleManagedDownloadSelection(_ device: IPSWDevice) {
        if selectedManagedDownloadIDs.contains(device.identifier) {
            selectedManagedDownloadIDs.remove(device.identifier)
        } else {
            selectedManagedDownloadIDs.insert(device.identifier)
        }
    }

    func isManagedDownloadSelected(_ device: IPSWDevice) -> Bool {
        selectedManagedDownloadIDs.contains(device.identifier)
    }

    private func scheduleDownload(for device: IPSWDevice) {
        guard settings.isUsingCustomDownloadDirectory || FullDiskAccessChecker.check() else {
            var task = downloadTasks[device.identifier] ?? DeviceDownloadTask(
                id: device.identifier,
                device: device,
                firmware: IPSWFirmware.placeholder(for: device.identifier)
            )
            task.state = .failed(error: IPSWError.fullDiskAccessRequired.localizedDescription)
            task.lastErrorDescription = IPSWError.fullDiskAccessRequired.localizedDescription
            downloadTasks[device.identifier] = task
            appendActivity(
                kind: .error,
                deviceIdentifier: device.identifier,
                title: device.name,
                message: IPSWError.fullDiskAccessRequired.localizedDescription
            )
            return
        }

        var task = downloadTasks[device.identifier] ?? DeviceDownloadTask(
            id: device.identifier,
            device: device,
            firmware: IPSWFirmware.placeholder(for: device.identifier)
        )
        task.device = device
        task.state = .queued
        task.progressDetails = nil
        task.lastErrorDescription = nil
        downloadTasks[device.identifier] = task

        if let queuedIndex = pendingDownloadQueue.firstIndex(of: device.identifier) {
            pendingDownloadQueue.remove(at: queuedIndex)
        }

        // Cancella eventuale task precedente (inclusa la fase di fetch API)
        downloadTaskHandles[device.identifier]?.cancel()
        activeDownloaders[device.identifier]?.cancel()
        activeDownloadIdentifiers.remove(device.identifier)

        if activeDownloadIdentifiers.count >= settings.maxConcurrentDownloads {
            if !pendingDownloadQueue.contains(device.identifier) {
                pendingDownloadQueue.append(device.identifier)
            }
            appendActivity(
                kind: .info,
                deviceIdentifier: device.identifier,
                title: device.name,
                message: String(localized: "activity.download_queued")
            )
            downloadTaskHandles.removeValue(forKey: device.identifier)
            activeDownloaders.removeValue(forKey: device.identifier)
            return
        }

        activeDownloadIdentifiers.insert(device.identifier)
        let handle = Task { [weak self] in
            guard let self else { return }
            await self.performDownload(for: device, attempt: max(1, self.downloadTasks[device.identifier]?.attemptCount ?? 0))
        }
        downloadTaskHandles[device.identifier] = handle
    }

    private func performDownload(for device: IPSWDevice, attempt: Int = 1) async {
        do {
            updateTask(for: device.identifier) { task in
                task.device = device
                task.attemptCount = max(task.attemptCount, attempt)
                task.lastErrorDescription = nil
            }
            appendActivity(
                kind: .info,
                deviceIdentifier: device.identifier,
                title: device.name,
                message: String(format: String(localized: "activity.download_start"), attempt, maxDownloadRetryCount + 1)
            )
            let detailed = try await IPSWAPIClient.shared.fetchDevice(identifier: device.identifier)

            // Controlla cancellazione dopo il fetch API (che può richiedere secondi)
            guard !Task.isCancelled else { return }

            guard let firmware = detailed.firmwares?.newestSignedFirmware()
            else {
                resumeDataStore.removeValue(forKey: device.identifier)
                markFailed(id: device.identifier,
                           device: device,
                           error: String(localized: "error.no_signed_firmware"))
                appendActivity(
                    kind: .warning,
                    deviceIdentifier: device.identifier,
                    title: device.name,
                    message: String(localized: "error.no_signed_firmware")
                )
                finishActiveWork(for: device.identifier)
                startNextQueuedDownloadIfPossible()
                return
            }

            // Se il firmware è già presente su disco con la dimensione corretta, segnala completato
            if let existingURL = localFileURL(for: firmware), fileIsComplete(firmware: firmware, at: existingURL) {
                var task = DeviceDownloadTask(id: device.identifier, device: device, firmware: firmware)
                task.state = .completed(url: existingURL)
                task.attemptCount = attempt
                downloadTasks[device.identifier] = task
                appendActivity(
                    kind: .info,
                    deviceIdentifier: device.identifier,
                    title: device.name,
                    message: String(format: String(localized: "activity.download_already_present"), firmware.version, firmware.buildid)
                )
                finishActiveWork(for: device.identifier)
                startNextQueuedDownloadIfPossible()
                return
            }

            var task = DeviceDownloadTask(id: device.identifier, device: device, firmware: firmware)
            task.state = .downloading(progress: 0)
            task.attemptCount = attempt
            downloadTasks[device.identifier] = task

            let downloader = IPSWDownloader()
            activeDownloaders[device.identifier] = downloader

            let identifier = device.identifier
            let resumeData = resumeDataStore[identifier]

            if resumeData != nil {
                appendActivity(
                    kind: .info,
                    deviceIdentifier: identifier,
                    title: device.name,
                    message: String(localized: "activity.download_resuming")
                )
            }

            downloader.onProgress = { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.downloadTasks[identifier]?.state = .downloading(progress: progress.fractionCompleted)
                    self?.downloadTasks[identifier]?.progressDetails = progress
                }
            }

            downloader.onVerifying = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.downloadTasks[identifier]?.state = .verifying
                    self?.downloadTasks[identifier]?.progressDetails = nil
                }
            }

            downloader.onCompletion = { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch result {
                    case .success(let url):
                        self.resumeDataStore.removeValue(forKey: identifier)
                        self.downloadTasks[identifier]?.state = .completed(url: url)
                        self.downloadTasks[identifier]?.progressDetails = nil
                        self.downloadTasks[identifier]?.lastErrorDescription = nil
                        self.appendActivity(
                            kind: .success,
                            deviceIdentifier: identifier,
                            title: device.name,
                            message: String(format: String(localized: "activity.download_completed"), firmware.version, firmware.buildid)
                        )
                        self.notifyDownloadCompletion(for: device, firmware: firmware)
                    case .failure(let error):
                        if self.shouldRetry(error: error, attempt: attempt) {
                            self.scheduleRetry(for: device, firmware: firmware, attempt: attempt + 1, error: error)
                            return
                        }
                        self.resumeDataStore.removeValue(forKey: identifier)
                        self.downloadTasks[identifier]?.state = .failed(error: error.localizedDescription)
                        self.downloadTasks[identifier]?.progressDetails = nil
                        self.downloadTasks[identifier]?.lastErrorDescription = error.localizedDescription
                        self.appendActivity(
                            kind: .error,
                            deviceIdentifier: identifier,
                            title: device.name,
                            message: error.localizedDescription
                        )
                    }
                    self.finishActiveWork(for: identifier)
                    self.startNextQueuedDownloadIfPossible()
                }
            }

            try downloader.startDownload(
                firmware: firmware,
                verifyChecksum: settings.verifyChecksumAfterDownload,
                resumeData: resumeData
            )

        } catch {
            if !Task.isCancelled {
                if shouldRetry(error: error, attempt: attempt) {
                    scheduleRetry(for: device, firmware: downloadTasks[device.identifier]?.firmware, attempt: attempt + 1, error: error)
                } else {
                    resumeDataStore.removeValue(forKey: device.identifier)
                    markFailed(id: device.identifier, device: device, error: error.localizedDescription)
                    appendActivity(
                        kind: .error,
                        deviceIdentifier: device.identifier,
                        title: device.name,
                        message: error.localizedDescription
                    )
                    finishActiveWork(for: device.identifier)
                    startNextQueuedDownloadIfPossible()
                }
            } else {
                finishActiveWork(for: device.identifier)
            }
        }
    }

    func pauseDownload(for device: IPSWDevice) {
        if let queuedIndex = pendingDownloadQueue.firstIndex(of: device.identifier) {
            pendingDownloadQueue.remove(at: queuedIndex)
            downloadTasks[device.identifier]?.state = .paused
            downloadTasks[device.identifier]?.progressDetails = nil
            appendActivity(
                kind: .warning,
                deviceIdentifier: device.identifier,
                title: device.name,
                message: String(localized: "activity.download_paused")
            )
            return
        }
        if let downloader = activeDownloaders[device.identifier] {
            downloadTaskHandles[device.identifier]?.cancel()
            downloader.cancelProducingResumeData { [weak self] resumeData in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let resumeData, !resumeData.isEmpty {
                        self.resumeDataStore[device.identifier] = resumeData
                        self.downloadTasks[device.identifier]?.state = .paused
                        self.appendActivity(
                            kind: .warning,
                            deviceIdentifier: device.identifier,
                            title: device.name,
                            message: String(localized: "activity.download_paused")
                        )
                    } else {
                        self.resumeDataStore.removeValue(forKey: device.identifier)
                        self.downloadTasks[device.identifier]?.state = .failed(error: String(localized: "download.pause_unavailable"))
                        self.appendActivity(
                            kind: .error,
                            deviceIdentifier: device.identifier,
                            title: device.name,
                            message: String(localized: "download.pause_unavailable")
                        )
                    }
                    self.finishActiveWork(for: device.identifier)
                    self.downloadTasks[device.identifier]?.progressDetails = nil
                    self.startNextQueuedDownloadIfPossible()
                }
            }
            return
        }

        // Se siamo ancora nel fetch API, il massimo che possiamo fare e' mettere in pausa la richiesta logica.
        downloadTaskHandles[device.identifier]?.cancel()
        activeDownloaders[device.identifier]?.cancel()
        finishActiveWork(for: device.identifier)
        downloadTasks[device.identifier]?.state = .paused
        downloadTasks[device.identifier]?.progressDetails = nil
        appendActivity(
            kind: .warning,
            deviceIdentifier: device.identifier,
            title: device.name,
            message: String(localized: "activity.download_paused")
        )
        startNextQueuedDownloadIfPossible()
    }

    func resumeDownload(for device: IPSWDevice) {
        scheduleDownload(for: device)
    }

    func cancelDownload(for device: IPSWDevice) {
        if let queuedIndex = pendingDownloadQueue.firstIndex(of: device.identifier) {
            pendingDownloadQueue.remove(at: queuedIndex)
        }
        downloadTaskHandles[device.identifier]?.cancel()
        activeDownloaders[device.identifier]?.cancel()
        finishActiveWork(for: device.identifier)
        resumeDataStore.removeValue(forKey: device.identifier)
        downloadTasks[device.identifier]?.state = .idle
        downloadTasks[device.identifier]?.progressDetails = nil
        selectedManagedDownloadIDs.remove(device.identifier)
        appendActivity(
            kind: .warning,
            deviceIdentifier: device.identifier,
            title: device.name,
            message: String(localized: "activity.download_cancelled")
        )
        startNextQueuedDownloadIfPossible()
    }

    /// Rimuove il dispositivo dalla lista selezionati e cancella l'eventuale download attivo.
    func removeDevice(_ device: IPSWDevice) {
        if let queuedIndex = pendingDownloadQueue.firstIndex(of: device.identifier) {
            pendingDownloadQueue.remove(at: queuedIndex)
        }
        downloadTaskHandles[device.identifier]?.cancel()
        activeDownloaders[device.identifier]?.cancel()
        finishActiveWork(for: device.identifier)
        resumeDataStore.removeValue(forKey: device.identifier)
        downloadTasks.removeValue(forKey: device.identifier)
        selectedDeviceIDs.remove(device.identifier)
        appendActivity(
            kind: .info,
            deviceIdentifier: device.identifier,
            title: device.name,
            message: String(localized: "activity.download_removed")
        )
        startNextQueuedDownloadIfPossible()
    }

    /// Rimuove i device per IndexSet (usato da List.onDelete).
    func removeDevices(at offsets: IndexSet) {
        let ordered = orderedSelectedDevices
        for index in offsets.reversed() {
            guard index < ordered.count else { continue }
            removeDevice(ordered[index])
        }
    }

    func pauseSelectedManagedDownloads() {
        let devicesToPause = managedDownloadDevices.filter { selectedManagedDownloadIDs.contains($0.identifier) }
        for device in devicesToPause {
            pauseDownload(for: device)
        }
    }

    func cancelSelectedManagedDownloads() {
        let devicesToCancel = cancellableManagedDevices.filter { selectedManagedDownloadIDs.contains($0.identifier) }
        for device in devicesToCancel {
            cancelDownload(for: device)
        }
        selectedManagedDownloadIDs.subtract(devicesToCancel.map(\.identifier))
    }

    func pauseAllManagedDownloads() {
        for device in managedDownloadDevices {
            pauseDownload(for: device)
        }
        selectedManagedDownloadIDs.removeAll()
    }

    func cancelAllManagedDownloads() {
        for device in cancellableManagedDevices {
            cancelDownload(for: device)
        }
        selectedManagedDownloadIDs.removeAll()
    }

    func resumeAllPausedDownloads() {
        let paused = managedDownloadDevices.filter { device in
            if case .paused = downloadState(for: device) { return true }
            return false
        }
        for device in paused {
            resumeDownload(for: device)
        }
    }

    var hasPausedDownloads: Bool {
        managedDownloadDevices.contains { device in
            if case .paused = downloadState(for: device) { return true }
            return false
        }
    }

    var cancellableManagedDevices: [IPSWDevice] {
        downloadTasks.values
            .filter { task in
                switch task.state {
                case .queued, .paused, .downloading, .verifying:
                    return true
                default:
                    return false
                }
            }
            .map(\.device)
            .sorted { $0.name < $1.name }
    }

    func retryAllFailed() {
        let failed = orderedSelectedDevices.filter { device in
            if case .failed = downloadState(for: device) { return true }
            return false
        }
        for device in failed {
            scheduleDownload(for: device)
        }
    }

    var hasFailedDownloads: Bool {
        orderedSelectedDevices.contains { device in
            if case .failed = downloadState(for: device) { return true }
            return false
        }
    }

    var hasCompletedDownloads: Bool {
        orderedSelectedDevices.contains { device in
            if case .completed = downloadState(for: device) { return true }
            return false
        }
    }

    func clearCompletedDownloads() {
        let completed = orderedSelectedDevices.filter { device in
            if case .completed = downloadState(for: device) { return true }
            return false
        }
        for device in completed {
            downloadTasks.removeValue(forKey: device.identifier)
        }
        appendActivity(
            kind: .info,
            deviceIdentifier: nil,
            title: String(localized: "activity.cleared_completed.title"),
            message: String(format: String(localized: "activity.cleared_completed.message"), completed.count)
        )
    }

    func invertSelection() {
        let allVisible = Set(filteredDevices.map(\.identifier))
        let currentlySelected = selectedDeviceIDs.intersection(allVisible)
        let newSelection = allVisible.subtracting(currentlySelected)
        // Keep selections that are outside current filter
        let outsideFilter = selectedDeviceIDs.subtracting(allVisible)
        selectedDeviceIDs = newSelection.union(outsideFilter)
    }

    func clearActivityLog() {
        activityLog.removeAll()
    }

    /// Dock badge count: number of actively downloading items
    var dockBadgeCount: Int {
        downloadTasks.values.filter { task in
            switch task.state {
            case .downloading, .queued, .verifying: return true
            default: return false
            }
        }.count
    }

    func updateDockBadge() {
        let count = dockBadgeCount
        let app = NSApplication.shared
        if count > 0 {
            app.dockTile.badgeLabel = "\(count)"
        } else {
            app.dockTile.badgeLabel = nil
        }
    }

    /// Active download count for window subtitle
    var activeDownloadCount: Int {
        downloadTasks.values.filter { task in
            switch task.state {
            case .downloading, .queued, .verifying: return true
            default: return false
            }
        }.count
    }

    /// Estimated total download size for selected idle (ready) devices
    var estimatedTotalDownloadSize: String? {
        let readyTasks = orderedSelectedDevices.filter { device in
            if case .idle = downloadState(for: device) { return true }
            return false
        }
        guard !readyTasks.isEmpty else { return nil }
        // Sum up firmware sizes from known metadata
        var totalBytes: Int64 = 0
        var knownCount = 0
        for device in readyTasks {
            if let task = downloadTasks[device.identifier],
               let size = task.firmware.filesize {
                totalBytes += size
                knownCount += 1
            } else if let meta = deviceSortMetadata[device.identifier],
                      meta.latestFirmwareVersion != nil {
                // Rough estimate: typical IPSW is ~6 GB
                totalBytes += 6_000_000_000
            }
        }
        guard totalBytes > 0 else { return nil }
        let formatted = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        if knownCount == readyTasks.count {
            return String(format: String(localized: "detail.estimated_size"), formatted)
        }
        return String(format: String(localized: "detail.estimated_size.approx"), formatted)
    }

    /// Window subtitle showing active download status
    var windowSubtitle: String? {
        let count = activeDownloadCount
        guard count > 0 else { return nil }
        let percent = Int(globalProgressFraction * 100)
        return String(format: String(localized: "window.subtitle.downloading"), count, percent)
    }

    // MARK: - Local File Helpers

    /// Restituisce l'URL locale atteso per un firmware, senza verificare se esiste.
    private func localFileURL(for firmware: IPSWFirmware) -> URL? {
        guard let downloadURL = firmware.downloadURL else { return nil }
        let category = DeviceCategory.from(identifier: firmware.identifier)
        guard let dir = try? category.destinationDirectory() else { return nil }
        let fileName = downloadURL.lastPathComponent.isEmpty
            ? "\(firmware.identifier)_\(firmware.buildid).ipsw"
            : downloadURL.lastPathComponent
        return dir.appendingPathComponent(fileName)
    }

    /// Verifica se il file esiste su disco con la dimensione corretta (o senza filesize noto).
    private func fileIsComplete(firmware: IPSWFirmware, at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        if let expected = firmware.filesize,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let actual = attrs[.size] as? Int64 {
            return actual == expected
        }
        // File presente ma dimensione sconosciuta — consideriamo valido
        return true
    }

    // MARK: - Auto-launch (avviato da LaunchAgent con --auto-launch)

    /// Chiamato all'avvio dell'app quando viene rilevato il flag --auto-launch.
    /// Recupera l'ultima release iOS firmata, individua gli iPhone compatibili via API,
    /// scarica quella release solo per i modelli supportati e poi chiude l'app.
    func runAutoLaunchUpdate() async {
        let startedAt = Date()
        await loadDevices()

        var checkedCount = 0
        var downloadedCount = 0
        var skippedCount = 0
        var failedCount = 0

        do {
            let latestVersion = try await IPSWAPIClient.shared.fetchLatestIOSVersion()
            let signedIdentifiers = try await IPSWAPIClient.shared.fetchSignedDeviceIdentifiers(for: latestVersion)
            let devicesToCheck = filteredDevices.filter { device in
                device.identifier.lowercased().hasPrefix("iphone") &&
                signedIdentifiers.contains(device.identifier)
            }

            appendActivity(
                kind: .info,
                deviceIdentifier: nil,
                title: String(localized: "activity.auto_launch.start.title"),
                message: String(format: String(localized: "activity.auto_launch.start.message"), latestVersion, devicesToCheck.count)
            )

            for device in devicesToCheck {
                checkedCount += 1
                do {
                    let detailed = try await IPSWAPIClient.shared.fetchDevice(identifier: device.identifier)
                    guard let firmware = detailed.firmwares?.newestSignedFirmware(version: latestVersion)
                    else {
                        skippedCount += 1
                        appendActivity(
                            kind: .warning,
                            deviceIdentifier: device.identifier,
                            title: device.name,
                            message: String(format: String(localized: "activity.auto_launch.no_signed"), latestVersion)
                        )
                        continue
                    }

                    if isAlreadyDownloaded(firmware: firmware) {
                        skippedCount += 1
                        appendActivity(
                            kind: .info,
                            deviceIdentifier: device.identifier,
                            title: device.name,
                            message: String(format: String(localized: "activity.auto_launch.already_downloaded"), firmware.version, firmware.buildid)
                        )
                    } else {
                        appendActivity(
                            kind: .info,
                            deviceIdentifier: device.identifier,
                            title: device.name,
                            message: String(format: String(localized: "activity.auto_launch.download_started"), firmware.version, firmware.buildid)
                        )
                        await startDownloadAndWait(for: device, firmware: firmware)
                        if case .completed = downloadTasks[device.identifier]?.state {
                            downloadedCount += 1
                        } else {
                            failedCount += 1
                        }
                    }
                } catch {
                    failedCount += 1
                    appendActivity(
                        kind: .error,
                        deviceIdentifier: device.identifier,
                        title: device.name,
                        message: String(format: String(localized: "activity.auto_launch.failed"), error.localizedDescription)
                    )
                }
            }
        } catch {
            failedCount = 1
            appendActivity(
                kind: .error,
                deviceIdentifier: nil,
                title: String(localized: "activity.auto_launch.start.title"),
                message: String(format: String(localized: "activity.auto_launch.failed"), error.localizedDescription)
            )
        }

        let report = AutoLaunchReport(
            startedAt: startedAt,
            finishedAt: Date(),
            checkedCount: checkedCount,
            downloadedCount: downloadedCount,
            skippedCount: skippedCount,
            failedCount: failedCount
        )
        settings.recordAutoLaunchReport(report)
        appendActivity(
            kind: report.completionKind,
            deviceIdentifier: nil,
            title: String(localized: "activity.auto_launch.summary.title"),
            message: String(
                format: String(localized: "activity.auto_launch.summary.message"),
                report.checkedCount,
                report.downloadedCount,
                report.skippedCount,
                report.failedCount
            )
        )
        persistState()

        // Grace period per completare callback e notifiche, poi chiude l'app
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        NSApplication.shared.terminate(nil)
    }

    /// Verifica se il firmware è già scaricato localmente con la dimensione corretta.
    private func isAlreadyDownloaded(firmware: IPSWFirmware) -> Bool {
        guard let url = localFileURL(for: firmware) else { return false }
        return fileIsComplete(firmware: firmware, at: url)
    }

    /// Avvia il download di un dispositivo e attende il suo completamento (successo o fallimento).
    private func startDownloadAndWait(for device: IPSWDevice, firmware targetFirmware: IPSWFirmware? = nil) async {
        await withCheckedContinuation { continuation in
            Task {
                do {
                    let firmware: IPSWFirmware
                    if let targetFirmware {
                        firmware = targetFirmware
                    } else {
                        let detailed = try await IPSWAPIClient.shared.fetchDevice(identifier: device.identifier)
                        guard let resolvedFirmware = detailed.firmwares?.newestSignedFirmware()
                        else {
                            markFailed(id: device.identifier,
                                       error: String(localized: "error.no_signed_firmware"))
                            continuation.resume()
                            return
                        }
                        firmware = resolvedFirmware
                    }

                    var task = DeviceDownloadTask(id: device.identifier, device: device, firmware: firmware)
                    task.state = .downloading(progress: 0)
                    downloadTasks[device.identifier] = task

                    let downloader = IPSWDownloader()
                    activeDownloaders[device.identifier] = downloader

                    let identifier = device.identifier

                    downloader.onProgress = { [weak self] progress in
                        Task { @MainActor [weak self] in
                            self?.downloadTasks[identifier]?.state = .downloading(progress: progress.fractionCompleted)
                            self?.downloadTasks[identifier]?.progressDetails = progress
                        }
                    }

                    downloader.onVerifying = { [weak self] in
                        Task { @MainActor [weak self] in
                            self?.downloadTasks[identifier]?.state = .verifying
                            self?.downloadTasks[identifier]?.progressDetails = nil
                        }
                    }

                    downloader.onCompletion = { [weak self] result in
                        Task { @MainActor [weak self] in
                            switch result {
                            case .success(let url):
                                self?.downloadTasks[identifier]?.state = .completed(url: url)
                                self?.downloadTasks[identifier]?.progressDetails = nil
                                self?.notifyDownloadCompletion(for: device, firmware: firmware)
                            case .failure(let error):
                                self?.downloadTasks[identifier]?.state = .failed(error: error.localizedDescription)
                                self?.downloadTasks[identifier]?.lastErrorDescription = error.localizedDescription
                            }
                            self?.activeDownloaders.removeValue(forKey: identifier)
                            continuation.resume()
                        }
                    }

                    try downloader.startDownload(
                        firmware: firmware,
                        verifyChecksum: settings.verifyChecksumAfterDownload
                    )

                } catch {
                    markFailed(id: device.identifier, device: device, error: error.localizedDescription)
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Helpers

    private func persistStateIfNeeded() {
        guard !isRestoringPersistedState else { return }
        persistState()
    }

    private func persistState() {
        let snapshot = PersistedAppState(
            selectedDeviceIDs: selectedDeviceIDs,
            downloadTasks: downloadTasks,
            pendingDownloadQueue: pendingDownloadQueue,
            activityLog: activityLog,
            resumeDataStore: resumeDataStore
        )

        do {
            let directory = statePersistenceURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: statePersistenceURL, options: [.atomic])
        } catch {
            NSLog("Failed to persist IPSW Downloader Plus state: %@", error.localizedDescription)
        }
    }

    private func restorePersistedState() {
        guard FileManager.default.fileExists(atPath: statePersistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: statePersistenceURL)
            let snapshot = try JSONDecoder().decode(PersistedAppState.self, from: data)
            isRestoringPersistedState = true
            selectedDeviceIDs = snapshot.selectedDeviceIDs
            downloadTasks = Self.normalizedRestoredTasks(snapshot.downloadTasks)
            pendingDownloadQueue = snapshot.pendingDownloadQueue
            activityLog = snapshot.activityLog
            resumeDataStore = snapshot.resumeDataStore
            isRestoringPersistedState = false
        } catch {
            isRestoringPersistedState = false
            NSLog("Failed to restore IPSW Downloader Plus state: %@", error.localizedDescription)
        }
    }

    private func resumePersistedDownloadsIfNeeded() {
        guard !hasResumedPersistedDownloads else { return }
        hasResumedPersistedDownloads = true

        let resumableIdentifiers = downloadTasks.compactMap { identifier, task -> String? in
            switch task.state {
            case .queued, .downloading, .verifying:
                return identifier
            default:
                return nil
            }
        }

        for identifier in resumableIdentifiers {
            guard let persistedTask = downloadTasks[identifier] else { continue }
            let resolvedDevice = devices.first(where: { $0.identifier == identifier }) ?? persistedTask.device
            appendActivity(
                kind: .info,
                deviceIdentifier: identifier,
                title: resolvedDevice.name,
                message: String(localized: "activity.download_restored")
            )
            scheduleDownload(for: resolvedDevice)
        }
    }

    private func markFailed(id: String, device: IPSWDevice? = nil, error: String) {
        if downloadTasks[id] == nil, let device {
            downloadTasks[id] = DeviceDownloadTask(
                id: id,
                device: device,
                firmware: IPSWFirmware.placeholder(for: id),
                state: .failed(error: error)
            )
            downloadTasks[id]?.lastErrorDescription = error
            return
        }
        downloadTasks[id]?.state = .failed(error: error)
        downloadTasks[id]?.progressDetails = nil
        downloadTasks[id]?.lastErrorDescription = error
    }

    private func updateTask(for identifier: String, mutation: (inout DeviceDownloadTask) -> Void) {
        guard var task = downloadTasks[identifier] else { return }
        mutation(&task)
        downloadTasks[identifier] = task
    }

    private func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt <= maxDownloadRetryCount else { return false }
        return Self.shouldRetryDownload(error: error, attempt: attempt, maxRetryCount: maxDownloadRetryCount)
    }

    static func shouldRetryDownload(error: Error, attempt: Int, maxRetryCount: Int) -> Bool {
        guard attempt <= maxRetryCount else { return false }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let retryableCodes: Set<Int> = [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorResourceUnavailable
            ]
            return retryableCodes.contains(nsError.code)
        }
        if let ipswError = error as? IPSWError,
           case .httpError(let statusCode) = ipswError {
            return [408, 429, 500, 502, 503, 504].contains(statusCode)
        }
        return false
    }

    static func normalizedRestoredTasks(_ tasks: [String: DeviceDownloadTask]) -> [String: DeviceDownloadTask] {
        var normalized = tasks
        for identifier in normalized.keys {
            switch normalized[identifier]?.state {
            case .downloading, .verifying:
                normalized[identifier]?.state = .queued
                normalized[identifier]?.progressDetails = nil
            default:
                break
            }
        }
        return normalized
    }

    private func scheduleRetry(for device: IPSWDevice, firmware: IPSWFirmware?, attempt: Int, error: Error) {
        let delaySeconds = min(Double(attempt * 2), 8)
        updateTask(for: device.identifier) { task in
            task.state = .queued
            task.progressDetails = nil
            task.lastErrorDescription = error.localizedDescription
            task.attemptCount = attempt
            if let firmware {
                task.firmware = firmware
            }
        }
        appendActivity(
            kind: .warning,
            deviceIdentifier: device.identifier,
            title: device.name,
            message: String(format: String(localized: "activity.download_retry"), attempt, maxDownloadRetryCount + 1, Int(delaySeconds), error.localizedDescription)
        )
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard let self else { return }
            guard self.activeDownloadIdentifiers.contains(device.identifier) else { return }
            await self.performDownload(for: device, attempt: attempt)
        }
    }

    private func appendActivity(kind: ActivityLogKind, deviceIdentifier: String?, title: String, message: String) {
        activityLog.insert(
            ActivityLogEntry(
                timestamp: Date(),
                kind: kind,
                deviceIdentifier: deviceIdentifier,
                title: title,
                message: message
            ),
            at: 0
        )
        if activityLog.count > activityLogLimit {
            activityLog.removeLast(activityLog.count - activityLogLimit)
        }
    }

    private func finishActiveWork(for identifier: String) {
        activeDownloaders.removeValue(forKey: identifier)
        downloadTaskHandles.removeValue(forKey: identifier)
        activeDownloadIdentifiers.remove(identifier)
    }

    private func startNextQueuedDownloadIfPossible() {
        guard activeDownloadIdentifiers.count < settings.maxConcurrentDownloads else { return }

        while activeDownloadIdentifiers.count < settings.maxConcurrentDownloads, !pendingDownloadQueue.isEmpty {
            let nextIdentifier = pendingDownloadQueue.removeFirst()
            guard let device = devices.first(where: { $0.identifier == nextIdentifier }) else {
                downloadTasks.removeValue(forKey: nextIdentifier)
                continue
            }

            activeDownloadIdentifiers.insert(nextIdentifier)
            let handle = Task { [weak self] in
                guard let self else { return }
                let attempt = max(1, self.downloadTasks[nextIdentifier]?.attemptCount ?? 0)
                await self.performDownload(for: device, attempt: attempt)
            }
            downloadTaskHandles[nextIdentifier] = handle
        }
    }

    private func notifyDownloadCompletion(for device: IPSWDevice, firmware: IPSWFirmware) {
        guard settings.notifyOnDownloadComplete else { return }

        let content = UNMutableNotificationContent()
        content.title = device.name
        content.body = "\(device.osLabel) \(firmware.version) (\(firmware.buildid))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "download-complete-\(device.identifier)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func downloadState(for device: IPSWDevice) -> DownloadState {
        downloadTasks[device.identifier]?.state ?? .idle
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openDownloadFolder() {
        if let customRoot = settings.customDownloadDirectoryURL {
            NSWorkspace.shared.open(customRoot)
            return
        }
        guard FullDiskAccessChecker.check() else {
            FullDiskAccessChecker.openPrivacySettings()
            return
        }
        guard let dir = try? IPSWDownloader.ipswDownloadDirectory() else { return }
        NSWorkspace.shared.open(dir)
    }

    func refreshLocalFirmwareState() {
        for (identifier, task) in downloadTasks {
            let url: URL?
            switch task.state {
            case .completed(let completedURL):
                url = completedURL
            default:
                url = localFileURL(for: task.firmware)
            }

            guard let fileURL = url else { continue }

            if fileIsComplete(firmware: task.firmware, at: fileURL) {
                if case .completed = task.state {
                    continue
                }
                downloadTasks[identifier]?.state = .completed(url: fileURL)
            } else if case .completed = task.state {
                downloadTasks[identifier]?.state = .failed(error: String(localized: "download.local_file_missing"))
            }
        }

        downloadedFirmware = scanLocalFirmware()
    }

    private func restartDirectoryMonitoring() {
        let urls = DeviceCategory.monitoredDirectories()
        directoryMonitor.startMonitoring(urls: urls) { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshLocalFirmwareState()
            }
        }
    }

    private func loadSortMetadata(for devices: [IPSWDevice]) async {
        let chunkSize = 8
        var index = 0

        while index < devices.count {
            if Task.isCancelled { return }
            let chunk = Array(devices[index..<min(index + chunkSize, devices.count)])

            await withTaskGroup(of: (String, DeviceSortMetadata?).self) { group in
                for device in chunk {
                    group.addTask {
                        do {
                            let detailed = try await IPSWAPIClient.shared.fetchDevice(identifier: device.identifier)
                            let metadata = Self.extractMetadata(from: detailed)
                            return (device.identifier, metadata)
                        } catch {
                            return (device.identifier, nil)
                        }
                    }
                }

                for await (identifier, metadata) in group {
                    guard let metadata else { continue }
                    await MainActor.run {
                        self.deviceSortMetadata[identifier] = metadata
                    }
                }
            }

            index += chunkSize
        }
    }

    nonisolated private static func extractMetadata(from device: IPSWDevice) -> DeviceSortMetadata {
        let firmwares = device.firmwares ?? []
        let latestByPreference = firmwares.sorted { IPSWFirmware.preferred($0, over: $1) }.first
        let latestReleaseDate = firmwares.compactMap(\.releaseDateValue).max()
        let earliestReleaseDate = firmwares.compactMap(\.releaseDateValue).min()

        return DeviceSortMetadata(
            latestFirmwareVersion: latestByPreference?.version,
            latestFirmwareReleaseDate: latestReleaseDate,
            modelReleaseDate: earliestReleaseDate
        )
    }

    private func compareDevices(_ lhs: IPSWDevice, _ rhs: IPSWDevice) -> Bool {
        let leftMetadata = metadata(for: lhs)
        let rightMetadata = metadata(for: rhs)
        switch sortOption {
        case .name:
            return compareStrings(
                lhs.name,
                rhs.name,
                fallbackLeft: lhs.identifier,
                fallbackRight: rhs.identifier,
                ascending: sortAscending
            )
        case .deviceType:
            return compareStrings(
                lhs.deviceTypeLabel,
                rhs.deviceTypeLabel,
                fallbackLeft: lhs.name,
                fallbackRight: rhs.name,
                ascending: sortAscending
            )
        case .firmwareVersion:
            return compareVersions(
                leftMetadata.latestFirmwareVersion,
                rightMetadata.latestFirmwareVersion,
                fallbackLeft: lhs.name,
                fallbackRight: rhs.name,
                ascending: sortAscending
            )
        case .firmwareReleaseDate:
            return compareDates(
                leftMetadata.latestFirmwareReleaseDate,
                rightMetadata.latestFirmwareReleaseDate,
                fallbackLeft: lhs.name,
                fallbackRight: rhs.name,
                ascending: sortAscending
            )
        case .modelReleaseDate:
            return compareDates(
                leftMetadata.modelReleaseDate,
                rightMetadata.modelReleaseDate,
                fallbackLeft: lhs.name,
                fallbackRight: rhs.name,
                ascending: sortAscending
            )
        }
    }

    private func metadata(for device: IPSWDevice) -> DeviceSortMetadata {
        deviceSortMetadata[device.identifier] ?? Self.extractMetadata(from: device)
    }

    private func compareStrings(_ lhs: String?, _ rhs: String?, fallbackLeft: String, fallbackRight: String, ascending: Bool) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?):
            let result = left.localizedCaseInsensitiveCompare(right)
            if result == .orderedSame {
                return ascending
                    ? fallbackLeft.localizedCaseInsensitiveCompare(fallbackRight) == .orderedAscending
                    : fallbackLeft.localizedCaseInsensitiveCompare(fallbackRight) == .orderedDescending
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            let result = fallbackLeft.localizedCaseInsensitiveCompare(fallbackRight)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private func compareVersions(_ lhs: String?, _ rhs: String?, fallbackLeft: String, fallbackRight: String, ascending: Bool) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?):
            let result = left.compare(right, options: .numeric)
            if result == .orderedSame {
                let fallbackResult = fallbackLeft.localizedCaseInsensitiveCompare(fallbackRight)
                return ascending ? fallbackResult == .orderedAscending : fallbackResult == .orderedDescending
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            let result = fallbackLeft.localizedCaseInsensitiveCompare(fallbackRight)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private func compareDates(_ lhs: Date?, _ rhs: Date?, fallbackLeft: String, fallbackRight: String, ascending: Bool) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?):
            if left == right {
                let result = fallbackLeft.localizedCaseInsensitiveCompare(fallbackRight)
                return ascending ? result == .orderedAscending : result == .orderedDescending
            }
            if ascending {
                return left < right
            }
            return left > right
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            let result = fallbackLeft.localizedCaseInsensitiveCompare(fallbackRight)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private func scanLocalFirmware() -> [LocalFirmwareRecord] {
        let fileManager = FileManager.default
        let candidateDevices = devices
        var records: [LocalFirmwareRecord] = []

        for directory in DeviceCategory.monitoredDirectories() {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension.lowercased() == "ipsw" else { continue }
                guard
                    let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                    values.isRegularFile == true
                else {
                    continue
                }

                let fileName = fileURL.lastPathComponent
                let matchedDevice = candidateDevices.first { device in
                    fileName.localizedCaseInsensitiveContains(device.identifier)
                }

                records.append(
                    LocalFirmwareRecord(
                        id: fileURL.path,
                        fileName: fileName,
                        deviceIdentifier: matchedDevice?.identifier,
                        deviceName: matchedDevice?.name,
                        location: fileURL,
                        fileSize: Int64(values.fileSize ?? 0),
                        modifiedAt: values.contentModificationDate
                    )
                )
            }
        }

        return records.sorted { lhs, rhs in
            switch (lhs.modifiedAt, rhs.modifiedAt) {
            case let (left?, right?) where left != right:
                return left > right
            default:
                return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
            }
        }
    }
}

private final class LocalFirmwareDirectoryMonitor {
    private var fileDescriptors: [CInt] = []
    private var sources: [DispatchSourceFileSystemObject] = []

    deinit {
        stopMonitoring()
    }

    func startMonitoring(urls: [URL], onChange: @escaping @Sendable () -> Void) {
        stopMonitoring()

        for url in urls {
            let fileDescriptor = open(url.path, O_EVTONLY)
            guard fileDescriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .delete, .rename],
                queue: DispatchQueue.global(qos: .utility)
            )

            source.setEventHandler(handler: onChange)
            source.setCancelHandler {
                close(fileDescriptor)
            }

            fileDescriptors.append(fileDescriptor)
            sources.append(source)
            source.resume()
        }
    }

    func stopMonitoring() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
        fileDescriptors.removeAll()
    }
}
