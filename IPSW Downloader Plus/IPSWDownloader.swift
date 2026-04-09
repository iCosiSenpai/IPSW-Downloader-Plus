//
//  IPSWDownloader.swift
//  IPSW Downloader Plus
//

import Foundation
import CryptoKit

// MARK: - Device Category

/// Categorizza un device identifier per determinare la cartella di destinazione corretta.
enum DeviceCategory {
    /// iPhone, iPad, iPod touch → ~/Library/iTunes/{ProductType} Software Updates
    case iTunes(productType: String)
    /// Apple TV, HomePod, Apple Silicon Mac, T2 iBridge
    /// → ~/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Firmware
    case configurator

    static func from(identifier: String) -> DeviceCategory {
        let lower = identifier.lowercased()
        if lower.hasPrefix("iphone") {
            return .iTunes(productType: "iPhone")
        } else if lower.hasPrefix("ipad") {
            return .iTunes(productType: "iPad")
        } else if lower.hasPrefix("ipod") {
            return .iTunes(productType: "iPod")
        } else {
            // AppleTV, AudioAccessory (HomePod), RealityDevice (Vision Pro),
            // iBridge (T2 Mac), VirtualMac, MacBook*, etc.
            return .configurator
        }
    }

    nonisolated func destinationDirectory() throws -> URL {
        let fm = FileManager.default

        if let customRoot = AppSettings.storedCustomDownloadDirectoryURL() {
            let dir = customRoot.appendingPathComponent(customSubdirectoryName, isDirectory: true)
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            return dir
        }

        guard FullDiskAccessChecker.check() else {
            throw IPSWError.fullDiskAccessRequired
        }

        // Usa homeDirectoryForCurrentUser per ottenere sempre ~/Library reale,
        // evitando che la sandbox reindirizzi a ~/Library/Containers/…/Data/Library.
        let libraryURL = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        let dir: URL
        switch self {
        case .iTunes(let productType):
            dir = libraryURL
                .appendingPathComponent("iTunes")
                .appendingPathComponent("\(productType) Software Updates")
        case .configurator:
            dir = libraryURL
                .appendingPathComponent("Group Containers")
                .appendingPathComponent("K36BKF7T3D.group.com.apple.configurator")
                .appendingPathComponent("Library")
                .appendingPathComponent("Caches")
                .appendingPathComponent("Firmware")
        }
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    nonisolated private var customSubdirectoryName: String {
        switch self {
        case .iTunes(let productType):
            return "\(productType) Software Updates"
        case .configurator:
            return "Configurator Firmware"
        }
    }

    static func monitoredDirectories() -> [URL] {
        let categories: [DeviceCategory] = [
            .iTunes(productType: "iPhone"),
            .iTunes(productType: "iPad"),
            .iTunes(productType: "iPod"),
            .configurator
        ]

        return categories.compactMap { try? $0.destinationDirectory() }
    }
}

// MARK: - Trusted Domain Validation

/// Accetta solo URL sui CDN ufficiali Apple, come fa IPSW Updater.
private let trustedIPSWDomains: Set<String> = [
    "appldnld.apple.com",
    "secure-appldnld.apple.com",
    "updates.cdn-apple.com"
]

func isValidIPSWURL(_ url: URL) -> Bool {
    guard let host = url.host else { return false }
    return trustedIPSWDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
}

// MARK: - API Client Protocol

protocol IPSWAPIService: Sendable {
    func fetchDevices() async throws -> [IPSWDevice]
    func fetchDevice(identifier: String) async throws -> IPSWDevice
    func fetchLatestIOSVersion() async throws -> String
    func fetchSignedDeviceIdentifiers(for version: String) async throws -> Set<String>
}

// MARK: - API Client

final class IPSWAPIClient: IPSWAPIService, @unchecked Sendable {
    static let shared = IPSWAPIClient()

    private let baseURL = "https://api.ipsw.me/v4"
    private let session: URLSession
    private let iOSReleaseVersionPattern = try? NSRegularExpression(pattern: #"(?:iOS|iPadOS)\s+(\d+(?:\.\d+)*)"#)

    /// In-flight deduplication for fetchDevice calls
    private let deduplicationQueue = DispatchQueue(label: "com.lupiatech.ipsw.api.dedup")
    private var inFlightDeviceFetches: [String: Task<IPSWDevice, Error>] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30

        // 20 MB memory / 100 MB disk cache for API responses
        let cache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024
        )
        config.urlCache = cache
        config.requestCachePolicy = .useProtocolCachePolicy

        self.session = URLSession(configuration: config)
    }

    func fetchDevices() async throws -> [IPSWDevice] {
        let url = try endpointURL(path: "/devices")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode([IPSWDevice].self, from: data)
    }

    func fetchDevice(identifier: String) async throws -> IPSWDevice {
        // Deduplicate concurrent requests for the same device
        let existingTask: Task<IPSWDevice, Error>? = deduplicationQueue.sync {
            inFlightDeviceFetches[identifier]
        }
        if let existingTask {
            return try await existingTask.value
        }
        let task = Task<IPSWDevice, Error> { [self] in
            defer {
                deduplicationQueue.sync { _ = inFlightDeviceFetches.removeValue(forKey: identifier) }
            }
            let encoded = identifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? identifier
            let url = try endpointURL(path: "/device/\(encoded)", queryItems: [URLQueryItem(name: "type", value: "ipsw")])
            let (data, response) = try await session.data(from: url)
            try validateResponse(response)
            return try JSONDecoder().decode(IPSWDevice.self, from: data)
        }
        deduplicationQueue.sync { inFlightDeviceFetches[identifier] = task }
        return try await task.value
    }

    /// Restituisce la versione iOS/iPadOS più recente rilasciata (non OTA, non beta).
    /// Usa /v4/releases, estrae il numero di versione con regex e sceglie la major più alta.
    /// Il campo `name` ha formato "iOS 26.3.1 (23D8133)" — il build ID viene scartato.
    func fetchLatestIOSVersion() async throws -> String {
        let url = try endpointURL(path: "/releases")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        let groups = try JSONDecoder().decode([IPSWReleaseGroup].self, from: data)

        // Regex: cattura il numero di versione (es. "26.3.1") dal campo name
        // Formato atteso: "iOS 26.3.1 (23D8133)" oppure "iPadOS 26.0"
        guard let pattern = iOSReleaseVersionPattern else {
            throw IPSWError.invalidResponse
        }

        var bestVersion: String? = nil

        for group in groups {
            for release in group.releases {
                let t = release.type ?? ""
                let n = release.name
                guard (t == "iOS" || t == "iPadOS"),
                      !n.localizedCaseInsensitiveContains("OTA"),
                      !n.localizedCaseInsensitiveContains("beta"),
                      !n.localizedCaseInsensitiveContains("RC") else { continue }

                let range = NSRange(n.startIndex..., in: n)
                guard let match = pattern.firstMatch(in: n, range: range),
                      let vRange = Range(match.range(at: 1), in: n) else { continue }

                let version = String(n[vRange])
                if let currentBest = bestVersion {
                    if version.compare(currentBest, options: .numeric) == .orderedDescending {
                        bestVersion = version
                    }
                } else {
                    bestVersion = version
                }
            }
        }

        guard let result = bestVersion else { throw IPSWError.noSignedFirmware }
        return result
    }

    /// Restituisce gli identifier di tutti i device che hanno un firmware firmato per la versione data.
    /// Usa /v4/ipsw/{version}.
    func fetchSignedDeviceIdentifiers(for version: String) async throws -> Set<String> {
        let encoded = version.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? version
        let url = try endpointURL(path: "/ipsw/\(encoded)")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        let firmwares = try JSONDecoder().decode([IPSWFirmware].self, from: data)
        let signed = firmwares.filter(\.signed).map(\.identifier)
        return Set(signed)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw IPSWError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw IPSWError.httpError(statusCode: http.statusCode)
        }
    }

    private func endpointURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw IPSWError.invalidURL
        }
        components.path += path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw IPSWError.invalidURL
        }
        return url
    }
}

// MARK: - Downloader

final class IPSWDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    var onProgress: ((DownloadProgressDetails) -> Void)?
    var onVerifying: (() -> Void)?      // chiamato prima del calcolo SHA1
    var onCompletion: ((Result<URL, Error>) -> Void)?

    private var downloadTask: URLSessionDownloadTask?
    private var targetFirmware: IPSWFirmware?
    private var shouldVerifyChecksum = true
    private var lastProgressTimestamp: Date?
    private var lastProgressBytesWritten: Int64 = 0
    private var lastEmittedProgressTimestamp: Date?
    private var lastEmittedProgressFraction: Double = 0
    private var pendingResumeDataHandler: ((Data?) -> Void)?
    private let minProgressEmitInterval: TimeInterval = 0.20
    private let minProgressEmitDelta: Double = 0.003

    private lazy var downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 3600 * 6
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// Avvia il download verificando l'URL e saltando se il file valido esiste già.
    func startDownload(firmware: IPSWFirmware, verifyChecksum: Bool = true, resumeData: Data? = nil) throws {
        guard let url = firmware.downloadURL else {
            throw IPSWError.invalidURL
        }

        // Valida che l'URL provenga da un dominio Apple ufficiale
        guard isValidIPSWURL(url) else {
            throw IPSWError.untrustedURL(url.absoluteString)
        }

        let category = DeviceCategory.from(identifier: firmware.identifier)
        let destinationDir = try category.destinationDirectory()
        let fileName = url.lastPathComponent.isEmpty
            ? "\(firmware.identifier)_\(firmware.buildid).ipsw"
            : url.lastPathComponent
        let destinationFile = destinationDir.appendingPathComponent(fileName)

        // Se il file esiste già con la dimensione corretta, skip download
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            if let expected = firmware.filesize,
               let attrs = try? FileManager.default.attributesOfItem(atPath: destinationFile.path),
               let actual = attrs[.size] as? Int64,
               actual == expected {
                onCompletion?(.success(destinationFile))
                return
            }
            // Dimensione errata: rimuovi e riscarica
            try? FileManager.default.removeItem(at: destinationFile)
        }

        targetFirmware = firmware
        shouldVerifyChecksum = verifyChecksum
        lastProgressTimestamp = nil
        lastProgressBytesWritten = 0
        lastEmittedProgressTimestamp = nil
        lastEmittedProgressFraction = 0
        if let resumeData {
            downloadTask = downloadSession.downloadTask(withResumeData: resumeData)
        } else {
            downloadTask = downloadSession.downloadTask(with: url)
        }
        downloadTask?.resume()
    }

    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        targetFirmware = nil
        lastProgressTimestamp = nil
        lastProgressBytesWritten = 0
        lastEmittedProgressTimestamp = nil
        lastEmittedProgressFraction = 0
    }

    func cancelProducingResumeData(_ completion: @escaping (Data?) -> Void) {
        guard let downloadTask else {
            completion(nil)
            return
        }
        pendingResumeDataHandler = completion
        downloadTask.cancel(byProducingResumeData: { [weak self] resumeData in
            DispatchQueue.main.async {
                self?.pendingResumeDataHandler?(resumeData)
                self?.pendingResumeDataHandler = nil
                self?.downloadTask = nil
                self?.targetFirmware = nil
                self?.lastProgressTimestamp = nil
                self?.lastProgressBytesWritten = 0
                self?.lastEmittedProgressTimestamp = nil
                self?.lastEmittedProgressFraction = 0
            }
        })
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let now = Date()
        let bytesPerSecond: Double
        if let lastProgressTimestamp {
            let interval = now.timeIntervalSince(lastProgressTimestamp)
            if interval > 0 {
                bytesPerSecond = Double(totalBytesWritten - lastProgressBytesWritten) / interval
            } else {
                bytesPerSecond = 0
            }
        } else {
            bytesPerSecond = 0
        }
        self.lastProgressTimestamp = now
        self.lastProgressBytesWritten = totalBytesWritten

        // Throttle progress events to reduce expensive SwiftUI list updates on older Macs.
        let shouldEmit: Bool = {
            if progress >= 0.999 { return true }
            if abs(progress - lastEmittedProgressFraction) >= minProgressEmitDelta { return true }
            guard let lastEmittedProgressTimestamp else { return true }
            return now.timeIntervalSince(lastEmittedProgressTimestamp) >= minProgressEmitInterval
        }()

        guard shouldEmit else { return }
        lastEmittedProgressTimestamp = now
        lastEmittedProgressFraction = progress

        let details = DownloadProgressDetails(
            fractionCompleted: progress,
            bytesWritten: totalBytesWritten,
            totalBytesExpected: totalBytesExpectedToWrite,
            bytesPerSecond: max(0, bytesPerSecond)
        )
        DispatchQueue.main.async { [weak self] in
            self?.onProgress?(details)
        }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        do {
            guard let firmware = targetFirmware,
                  let sourceURL = downloadTask.originalRequest?.url else {
                throw IPSWError.invalidResponse
            }

            let category = DeviceCategory.from(identifier: firmware.identifier)
            let destinationDir = try category.destinationDirectory()
            let fileName = sourceURL.lastPathComponent.isEmpty ? "firmware.ipsw" : sourceURL.lastPathComponent
            let destinationFile = destinationDir.appendingPathComponent(fileName)

            // Notifica il ViewModel che stiamo verificando il checksum
            if shouldVerifyChecksum, (firmware.sha256sum ?? firmware.sha1) != nil {
                DispatchQueue.main.async { [weak self] in
                    self?.onVerifying?()
                }
            }

            // Verifica SHA-256 (preferito) o SHA1 come fallback
            if shouldVerifyChecksum, let expectedSHA256 = firmware.sha256sum {
                let actualSHA256 = try sha256(of: location)
                guard actualSHA256.lowercased() == expectedSHA256.lowercased() else {
                    throw IPSWError.checksumMismatch(expected: expectedSHA256, actual: actualSHA256)
                }
            } else if shouldVerifyChecksum, let expectedSHA1 = firmware.sha1 {
                let actualSHA1 = try sha1(of: location)
                guard actualSHA1.lowercased() == expectedSHA1.lowercased() else {
                    throw IPSWError.checksumMismatch(expected: expectedSHA1, actual: actualSHA1)
                }
            }

            // Sposta nella destinazione finale
            if FileManager.default.fileExists(atPath: destinationFile.path) {
                try FileManager.default.removeItem(at: destinationFile)
            }
            try FileManager.default.moveItem(at: location, to: destinationFile)

            // Rimuovi firmware obsoleti dello stesso dispositivo nella stessa cartella
            cleanOutdatedFirmware(in: destinationDir, keeping: fileName, deviceIdentifier: firmware.identifier)

            DispatchQueue.main.async { [weak self] in
                self?.onCompletion?(.success(destinationFile))
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onCompletion?(.failure(error))
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        DispatchQueue.main.async { [weak self] in
            self?.onCompletion?(.failure(error))
        }
    }

    // MARK: - SHA1 Checksum

    private func sha1(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = Insecure.SHA1()
        let bufferSize = 1024 * 1024  // 1 MB chunks
        while true {
            guard let data = try handle.read(upToCount: bufferSize), !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - SHA-256 Checksum

    private func sha256(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        let bufferSize = 1024 * 1024  // 1 MB chunks
        while true {
            guard let data = try handle.read(upToCount: bufferSize), !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Outdated Firmware Cleanup

    /// Rimuove i file .ipsw obsoleti dello stesso dispositivo nella stessa cartella.
    /// Il metodo di rimozione (definitivo o Cestino) dipende da AppSettings.deleteMode.
    private func cleanOutdatedFirmware(in directory: URL, keeping currentFileName: String, deviceIdentifier: String) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }

        let deleteMode = AppSettings.shared.deleteMode
        // Use precise matching: filename must start with "DeviceIdentifier_" (e.g. "iPhone16,2_")
        // This prevents "iPhone16,2" from matching "iPhone16,20_..." files
        let devicePrefix = deviceIdentifier + "_"

        for fileURL in contents {
            let name = fileURL.lastPathComponent
            guard name.hasSuffix(".ipsw"),
                  name != currentFileName,
                  name.hasPrefix(devicePrefix) else { continue }

            switch deleteMode {
            case .permanent:
                try? fm.removeItem(at: fileURL)
            case .trash:
                try? fm.trashItem(at: fileURL, resultingItemURL: nil)
            }
        }
    }

    // MARK: - Cartella di destinazione (compatibilità con ViewModel)

    static func ipswDownloadDirectory() throws -> URL {
        try DeviceCategory.iTunes(productType: "iPhone").destinationDirectory()
    }
}

// MARK: - Errors

enum IPSWError: LocalizedError {
    case invalidURL
    case untrustedURL(String)
    case invalidResponse
    case httpError(statusCode: Int)
    case noSignedFirmware
    case downloadDirectoryUnavailable
    case checksumMismatch(expected: String, actual: String)
    case fullDiskAccessRequired
    case networkTimeout
    case connectionLost
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "error.invalid_url")
        case .untrustedURL(let url):
            return String(localized: "error.untrusted_url \(url)")
        case .invalidResponse:
            return String(localized: "error.invalid_response")
        case .httpError(let code):
            return String(localized: "error.http \(code)")
        case .noSignedFirmware:
            return String(localized: "error.no_signed_firmware")
        case .downloadDirectoryUnavailable:
            return String(localized: "error.download_directory_unavailable")
        case .checksumMismatch(let expected, let actual):
            return String(localized: "error.checksum_mismatch \(expected) \(actual)")
        case .fullDiskAccessRequired:
            return String(localized: "error.full_disk_access_required")
        case .networkTimeout:
            return String(localized: "error.network_timeout")
        case .connectionLost:
            return String(localized: "error.connection_lost")
        case .rateLimited:
            return String(localized: "error.rate_limited")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkTimeout, .connectionLost:
            return String(localized: "error.recovery.check_connection")
        case .rateLimited:
            return String(localized: "error.recovery.wait_retry")
        case .fullDiskAccessRequired:
            return String(localized: "error.recovery.full_disk_access")
        case .checksumMismatch:
            return String(localized: "error.recovery.redownload")
        case .downloadDirectoryUnavailable:
            return String(localized: "error.recovery.check_directory")
        default:
            return nil
        }
    }
}
