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
    @Published var downloadTasks: [String: DeviceDownloadTask] = [:]
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

    // Riferimento alle impostazioni globali
    private let settings = AppSettings.shared

    // Mappa identifier -> IPSWDownloader attivo
    private var activeDownloaders: [String: IPSWDownloader] = [:]
    // Mappa identifier -> Task di download (annullabile per interrompere anche il fetch API iniziale)
    private var downloadTaskHandles: [String: Task<Void, Never>] = [:]
    private var pendingDownloadQueue: [String] = []
    private var metadataLoadTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private let directoryMonitor = LocalFirmwareDirectoryMonitor()

    init() {
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

            // Escludi device irrilevanti noti (da IPSW Updater di freegeek-pdx)
            if id == "ADP3,2" { return false }               // Apple Silicon Dev Transition Kit (bloccato a macOS 11.2.3)
            if lower.hasPrefix("virtualmac") { return false } // Apple Silicon VM — ridondante

            // Escludi tipi non gestiti dall'app (Apple Watch, AirPods, ecc.)
            // Se productTypeKey ritorna nil il device non appartiene a nessuna categoria
            // supportata → lo escludiamo silenziosamente
            guard let key = AppSettings.productTypeKey(for: id) else { return false }

            // Filtro product type dalle impostazioni
            if !settings.isProductTypeEnabled(key) { return false }

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

    // MARK: - Load Devices

    func loadDevices() async {
        isLoadingDevices = true
        deviceLoadError = nil
        do {
            devices = try await IPSWAPIClient.shared.fetchDevices()
            deviceSortMetadata.removeAll()
            metadataLoadTask?.cancel()
            metadataLoadTask = Task { [weak self] in
                await self?.loadSortMetadata(for: self?.devices ?? [])
            }
        } catch {
            deviceLoadError = error.localizedDescription
        }
        isLoadingDevices = false
        restartDirectoryMonitoring()
        refreshLocalFirmwareState()
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

    private func scheduleDownload(for device: IPSWDevice) {
        guard settings.isUsingCustomDownloadDirectory || FullDiskAccessChecker.check() else {
            var task = downloadTasks[device.identifier] ?? DeviceDownloadTask(
                id: device.identifier,
                device: device,
                firmware: IPSWFirmware.placeholder(for: device.identifier)
            )
            task.state = .failed(error: IPSWError.fullDiskAccessRequired.localizedDescription)
            downloadTasks[device.identifier] = task
            return
        }

        if let queuedIndex = pendingDownloadQueue.firstIndex(of: device.identifier) {
            pendingDownloadQueue.remove(at: queuedIndex)
        }

        // Cancella eventuale task precedente (inclusa la fase di fetch API)
        downloadTaskHandles[device.identifier]?.cancel()
        activeDownloaders[device.identifier]?.cancel()

        if activeDownloaders.count >= settings.maxConcurrentDownloads {
            var task = downloadTasks[device.identifier] ?? DeviceDownloadTask(
                id: device.identifier,
                device: device,
                firmware: IPSWFirmware.placeholder(for: device.identifier)
            )
            task.device = device
            task.state = .queued
            downloadTasks[device.identifier] = task
            pendingDownloadQueue.append(device.identifier)
            downloadTaskHandles.removeValue(forKey: device.identifier)
            activeDownloaders.removeValue(forKey: device.identifier)
            return
        }

        let handle = Task { [weak self] in
            guard let self else { return }
            await self.performDownload(for: device)
        }
        downloadTaskHandles[device.identifier] = handle
    }

    private func performDownload(for device: IPSWDevice) async {
        do {
            let detailed = try await IPSWAPIClient.shared.fetchDevice(identifier: device.identifier)

            // Controlla cancellazione dopo il fetch API (che può richiedere secondi)
            guard !Task.isCancelled else { return }

            guard let firmware = detailed.firmwares?.newestSignedFirmware()
            else {
                markFailed(id: device.identifier,
                           error: String(localized: "error.no_signed_firmware"))
                return
            }

            // Se il firmware è già presente su disco con la dimensione corretta, segnala completato
            if let existingURL = localFileURL(for: firmware), fileIsComplete(firmware: firmware, at: existingURL) {
                var task = DeviceDownloadTask(id: device.identifier, device: device, firmware: firmware)
                task.state = .completed(url: existingURL)
                downloadTasks[device.identifier] = task
                downloadTaskHandles.removeValue(forKey: device.identifier)
                return
            }

            var task = DeviceDownloadTask(id: device.identifier, device: device, firmware: firmware)
            task.state = .downloading(progress: 0)
            downloadTasks[device.identifier] = task

            let downloader = IPSWDownloader()
            activeDownloaders[device.identifier] = downloader

            let identifier = device.identifier

            downloader.onProgress = { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.downloadTasks[identifier]?.state = .downloading(progress: progress)
                }
            }

            downloader.onVerifying = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.downloadTasks[identifier]?.state = .verifying
                }
            }

            downloader.onCompletion = { [weak self] result in
                Task { @MainActor [weak self] in
                    switch result {
                    case .success(let url):
                        self?.downloadTasks[identifier]?.state = .completed(url: url)
                        self?.notifyDownloadCompletion(for: device, firmware: firmware)
                    case .failure(let error):
                        self?.downloadTasks[identifier]?.state = .failed(error: error.localizedDescription)
                    }
                    self?.activeDownloaders.removeValue(forKey: identifier)
                    self?.downloadTaskHandles.removeValue(forKey: identifier)
                    self?.startNextQueuedDownloadIfPossible()
                }
            }

            try downloader.startDownload(
                firmware: firmware,
                verifyChecksum: settings.verifyChecksumAfterDownload
            )

        } catch {
            if !Task.isCancelled {
                markFailed(id: device.identifier, error: error.localizedDescription)
                startNextQueuedDownloadIfPossible()
            }
        }
    }

    func cancelDownload(for device: IPSWDevice) {
        if let queuedIndex = pendingDownloadQueue.firstIndex(of: device.identifier) {
            pendingDownloadQueue.remove(at: queuedIndex)
        }
        // Annulla il Task intero (include fetch API + download URLSession)
        downloadTaskHandles[device.identifier]?.cancel()
        downloadTaskHandles.removeValue(forKey: device.identifier)
        activeDownloaders[device.identifier]?.cancel()
        activeDownloaders.removeValue(forKey: device.identifier)
        downloadTasks[device.identifier]?.state = .idle
        startNextQueuedDownloadIfPossible()
    }

    /// Rimuove il dispositivo dalla lista selezionati e cancella l'eventuale download attivo.
    func removeDevice(_ device: IPSWDevice) {
        if let queuedIndex = pendingDownloadQueue.firstIndex(of: device.identifier) {
            pendingDownloadQueue.remove(at: queuedIndex)
        }
        downloadTaskHandles[device.identifier]?.cancel()
        downloadTaskHandles.removeValue(forKey: device.identifier)
        activeDownloaders[device.identifier]?.cancel()
        activeDownloaders.removeValue(forKey: device.identifier)
        downloadTasks.removeValue(forKey: device.identifier)
        selectedDeviceIDs.remove(device.identifier)
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
    /// Controlla i firmware più recenti per tutti i dispositivi abilitati,
    /// scarica solo quelli non ancora presenti in locale, poi chiude l'app.
    func runAutoLaunchUpdate() async {
        await loadDevices()

        let devicesToCheck = filteredDevices

        for device in devicesToCheck {
            do {
                let detailed = try await IPSWAPIClient.shared.fetchDevice(identifier: device.identifier)
                guard let firmware = detailed.firmwares?.newestSignedFirmware()
                else {
                    print("[Auto-Launch] Nessun firmware firmato per: \(device.identifier)")
                    continue
                }

                if isAlreadyDownloaded(firmware: firmware) {
                    print("[Auto-Launch] Già aggiornato: \(device.identifier) (\(firmware.version))")
                } else {
                    print("[Auto-Launch] Nuova versione, download: \(device.identifier) (\(firmware.version))")
                    await startDownloadAndWait(for: device)
                }
            } catch {
                print("[Auto-Launch] Errore controllo \(device.identifier): \(error.localizedDescription)")
            }
        }

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
    private func startDownloadAndWait(for device: IPSWDevice) async {
        await withCheckedContinuation { continuation in
            Task {
                do {
                    let detailed = try await IPSWAPIClient.shared.fetchDevice(identifier: device.identifier)
                    guard let firmware = detailed.firmwares?.newestSignedFirmware()
                    else {
                        markFailed(id: device.identifier,
                                   error: String(localized: "error.no_signed_firmware"))
                        continuation.resume()
                        return
                    }

                    var task = DeviceDownloadTask(id: device.identifier, device: device, firmware: firmware)
                    task.state = .downloading(progress: 0)
                    downloadTasks[device.identifier] = task

                    let downloader = IPSWDownloader()
                    activeDownloaders[device.identifier] = downloader

                    let identifier = device.identifier

                    downloader.onProgress = { [weak self] progress in
                        Task { @MainActor [weak self] in
                            self?.downloadTasks[identifier]?.state = .downloading(progress: progress)
                        }
                    }

                    downloader.onVerifying = { [weak self] in
                        Task { @MainActor [weak self] in
                            self?.downloadTasks[identifier]?.state = .verifying
                        }
                    }

                    downloader.onCompletion = { [weak self] result in
                        Task { @MainActor [weak self] in
                            switch result {
                            case .success(let url):
                                self?.downloadTasks[identifier]?.state = .completed(url: url)
                                self?.notifyDownloadCompletion(for: device, firmware: firmware)
                            case .failure(let error):
                                self?.downloadTasks[identifier]?.state = .failed(error: error.localizedDescription)
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
                    markFailed(id: device.identifier, error: error.localizedDescription)
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Helpers

    private func markFailed(id: String, error: String) {
        downloadTasks[id]?.state = .failed(error: error)
    }

    private func startNextQueuedDownloadIfPossible() {
        guard activeDownloaders.count < settings.maxConcurrentDownloads else { return }

        while activeDownloaders.count < settings.maxConcurrentDownloads, !pendingDownloadQueue.isEmpty {
            let nextIdentifier = pendingDownloadQueue.removeFirst()
            guard let device = devices.first(where: { $0.identifier == nextIdentifier }) else {
                downloadTasks.removeValue(forKey: nextIdentifier)
                continue
            }

            let handle = Task { [weak self] in
                guard let self else { return }
                await self.performDownload(for: device)
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
        let latest = firmwares.max {
            ($0.releaseDateValue ?? .distantPast) < ($1.releaseDateValue ?? .distantPast)
        }
        let earliest = firmwares.min {
            ($0.releaseDateValue ?? .distantFuture) < ($1.releaseDateValue ?? .distantFuture)
        }

        return DeviceSortMetadata(
            latestFirmwareVersion: latest?.version,
            latestFirmwareReleaseDate: latest?.releaseDateValue,
            modelReleaseDate: earliest?.releaseDateValue
        )
    }

    private func compareDevices(_ lhs: IPSWDevice, _ rhs: IPSWDevice) -> Bool {
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
                deviceSortMetadata[lhs.identifier]?.latestFirmwareVersion,
                deviceSortMetadata[rhs.identifier]?.latestFirmwareVersion,
                fallbackLeft: lhs.name,
                fallbackRight: rhs.name,
                ascending: sortAscending
            )
        case .firmwareReleaseDate:
            return compareDates(
                deviceSortMetadata[lhs.identifier]?.latestFirmwareReleaseDate,
                deviceSortMetadata[rhs.identifier]?.latestFirmwareReleaseDate,
                fallbackLeft: lhs.name,
                fallbackRight: rhs.name,
                ascending: sortAscending
            )
        case .modelReleaseDate:
            return compareDates(
                deviceSortMetadata[lhs.identifier]?.modelReleaseDate,
                deviceSortMetadata[rhs.identifier]?.modelReleaseDate,
                fallbackLeft: lhs.name,
                fallbackRight: rhs.name,
                ascending: sortAscending
            )
        }
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
