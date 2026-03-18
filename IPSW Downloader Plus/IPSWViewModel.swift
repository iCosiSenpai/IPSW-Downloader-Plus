//
//  IPSWViewModel.swift
//  IPSW Downloader Plus
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class IPSWViewModel: ObservableObject {

    // MARK: - Published State

    @Published var devices: [IPSWDevice] = []
    @Published var selectedDeviceIDs: Set<String> = []
    @Published var downloadTasks: [String: DeviceDownloadTask] = [:]
    @Published var isLoadingDevices = false
    @Published var deviceLoadError: String? = nil
    @Published var searchText = ""

    // Riferimento alle impostazioni globali
    private let settings = AppSettings.shared

    // Mappa identifier -> IPSWDownloader attivo
    private var activeDownloaders: [String: IPSWDownloader] = [:]

    // MARK: - Selected Devices (ordered for DetailView)

    /// Dispositivi selezionati ordinati per nome, usato da DetailView e onDelete.
    var orderedSelectedDevices: [IPSWDevice] {
        Array(selectedDeviceIDs)
            .compactMap { id in devices.first(where: { $0.identifier == id }) }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Filtered Devices

    /// Applica ricerca testuale + filtro per product type + esclude device non gestiti/irrilevanti
    var filteredDevices: [IPSWDevice] {
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

    // MARK: - Load Devices

    func loadDevices() async {
        isLoadingDevices = true
        deviceLoadError = nil
        do {
            devices = try await IPSWAPIClient.shared.fetchDevices()
        } catch {
            deviceLoadError = error.localizedDescription
        }
        isLoadingDevices = false
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
            Task { await startDownload(for: device) }
        }
    }

    func startDownload(for device: IPSWDevice) async {
        do {
            let detailed = try await IPSWAPIClient.shared.fetchDevice(identifier: device.identifier)
            guard let firmware = detailed.firmwares?
                .filter({ $0.signed })
                .max(by: { $0.buildid < $1.buildid })
            else {
                markFailed(id: device.identifier,
                           error: String(localized: "error.no_signed_firmware"))
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
                    case .failure(let error):
                        self?.downloadTasks[identifier]?.state = .failed(error: error.localizedDescription)
                    }
                    self?.activeDownloaders.removeValue(forKey: identifier)
                }
            }

            try downloader.startDownload(firmware: firmware)

        } catch {
            markFailed(id: device.identifier, error: error.localizedDescription)
        }
    }

    func cancelDownload(for device: IPSWDevice) {
        activeDownloaders[device.identifier]?.cancel()
        activeDownloaders.removeValue(forKey: device.identifier)
        downloadTasks[device.identifier]?.state = .idle
    }

    /// Rimuove il dispositivo dalla lista selezionati e cancella l'eventuale download attivo.
    func removeDevice(_ device: IPSWDevice) {
        activeDownloaders[device.identifier]?.cancel()
        activeDownloaders.removeValue(forKey: device.identifier)
        downloadTasks.removeValue(forKey: device.identifier)
        selectedDeviceIDs.remove(device.identifier)
    }

    /// Rimuove i device per IndexSet (usato da List.onDelete).
    func removeDevices(at offsets: IndexSet) {
        let ordered = orderedSelectedDevices
        for index in offsets.reversed() {
            guard index < ordered.count else { continue }
            removeDevice(ordered[index])
        }
    }

    // MARK: - Auto-launch (avviato da LaunchAgent con --auto-launch)

    /// Chiamato all'avvio dell'app quando viene rilevato il flag --auto-launch.
    /// Scarica tutti i firmware abilitati per i dispositivi selezionati.
    func runAutoLaunchUpdate() async {
        await loadDevices()
        for device in filteredDevices where selectedDeviceIDs.contains(device.identifier) {
            await startDownload(for: device)
        }
    }

    // MARK: - Helpers

    private func markFailed(id: String, error: String) {
        downloadTasks[id]?.state = .failed(error: error)
    }

    func downloadState(for device: IPSWDevice) -> DownloadState {
        downloadTasks[device.identifier]?.state ?? .idle
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openDownloadFolder() {
        guard let dir = try? IPSWDownloader.ipswDownloadDirectory() else { return }
        NSWorkspace.shared.open(dir)
    }
}
