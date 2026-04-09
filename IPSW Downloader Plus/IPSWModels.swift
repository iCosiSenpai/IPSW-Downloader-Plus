//
//  IPSWModels.swift
//  IPSW Downloader Plus
//

import Foundation

struct DownloadProgressDetails: Equatable, Codable {
    let fractionCompleted: Double
    let bytesWritten: Int64
    let totalBytesExpected: Int64
    let bytesPerSecond: Double

    var percentText: String {
        "\(Int(fractionCompleted * 100))%"
    }

    var transferredText: String {
        "\(ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: totalBytesExpected, countStyle: .file))"
    }

    var speedText: String {
        guard bytesPerSecond > 0 else { return "—" }
        let rate = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file)
        return "\(rate)/s"
    }

    var etaText: String {
        guard bytesPerSecond > 0, totalBytesExpected > bytesWritten else { return "—" }
        let secondsRemaining = Double(totalBytesExpected - bytesWritten) / bytesPerSecond
        guard secondsRemaining.isFinite, secondsRemaining > 0 else { return "—" }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = secondsRemaining >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: secondsRemaining) ?? "—"
    }
}

enum ActivityLogKind: String, Codable {
    case info
    case success
    case warning
    case error

    var systemImage: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}

struct ActivityLogEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let timestamp: Date
    let kind: ActivityLogKind
    let deviceIdentifier: String?
    let title: String
    let message: String

    init(id: UUID = UUID(), timestamp: Date, kind: ActivityLogKind, deviceIdentifier: String?, title: String, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.deviceIdentifier = deviceIdentifier
        self.title = title
        self.message = message
    }
}

struct AutoLaunchReport: Equatable, Codable {
    let startedAt: Date
    let finishedAt: Date
    let checkedCount: Int
    let downloadedCount: Int
    let skippedCount: Int
    let failedCount: Int

    var hadFailures: Bool {
        failedCount > 0
    }

    var completionKind: ActivityLogKind {
        hadFailures ? .warning : .success
    }
}

// MARK: - Device

struct IPSWDevice: Codable, Identifiable, Hashable {
    let name: String
    let identifier: String
    let firmwares: [IPSWFirmware]?

    var id: String { identifier }

    /// Categoria del dispositivo che determina la cartella di destinazione.
    var category: DeviceCategory { DeviceCategory.from(identifier: identifier) }

    /// Prefisso OS corretto per mostrare la versione firmware (iOS, tvOS, audioOS, ecc.)
    var osLabel: String {
        let lower = identifier.lowercased()
        if lower.hasPrefix("appletv")        { return "tvOS" }
        if lower.hasPrefix("audioaccessory") { return "audioOS" }
        if lower.hasPrefix("realitydevice")  { return "visionOS" }
        if lower.hasPrefix("ibridge")        { return "BridgeOS" }
        if lower.hasPrefix("mac") || lower.hasPrefix("imac") ||
           lower.hasPrefix("macbook") || lower.hasPrefix("macpro") ||
           lower.hasPrefix("macmini")        { return "macOS" }
        return "iOS"  // iPhone, iPad, iPod
    }

    var deviceTypeLabel: String {
        AppSettings.productTypeKey(for: identifier) ?? "Other"
    }

    /// Icona SF Symbol appropriata al tipo di dispositivo.
    var symbolName: String {
        let lower = identifier.lowercased()
        if lower.hasPrefix("iphone") { return "iphone" }
        if lower.hasPrefix("ipad") { return "ipad" }
        if lower.hasPrefix("ipod") { return "ipodtouch" }
        if lower.hasPrefix("appletv") { return "appletv" }
        if lower.hasPrefix("audioaccessory") { return "homepod" }
        if lower.hasPrefix("realitydevice") { return "visionpro" }
        if lower.hasPrefix("ibridge") { return "laptopcomputer" }
        return "cpu"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    static func == (lhs: IPSWDevice, rhs: IPSWDevice) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

// MARK: - Firmware

struct IPSWFirmware: Codable, Identifiable {
    let identifier: String
    let version: String
    let buildid: String
    let sha1: String?
    let sha256sum: String?
    let filesize: Int64?
    let url: String
    let filename: String?
    let releasedate: String?
    let signed: Bool

    var id: String { buildid }

    // L'API usa nomi diversi a seconda dell'endpoint:
    //   /device/{id}       → sha1
    //   /ipsw/{version}    → sha1sum
    // sha256sum è supportato quando l'API lo fornisce.
    enum CodingKeys: String, CodingKey {
        case identifier, version, buildid
        case sha1, sha1sum
        case sha256sum
        case filesize, url, filename
        case releasedate, signed
    }

    init(
        identifier: String,
        version: String,
        buildid: String,
        sha1: String?,
        sha256sum: String? = nil,
        filesize: Int64?,
        url: String,
        filename: String?,
        releasedate: String?,
        signed: Bool
    ) {
        self.identifier = identifier
        self.version = version
        self.buildid = buildid
        self.sha1 = sha1
        self.sha256sum = sha256sum
        self.filesize = filesize
        self.url = url
        self.filename = filename
        self.releasedate = releasedate
        self.signed = signed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identifier  = try c.decode(String.self,   forKey: .identifier)
        version     = try c.decode(String.self,   forKey: .version)
        buildid     = try c.decode(String.self,   forKey: .buildid)
        filesize    = try c.decodeIfPresent(Int64.self,   forKey: .filesize)
        url         = try c.decode(String.self,   forKey: .url)
        filename    = try c.decodeIfPresent(String.self,  forKey: .filename)
        releasedate = try c.decodeIfPresent(String.self,  forKey: .releasedate)
        signed      = try c.decode(Bool.self,     forKey: .signed)
        sha1   = try c.decodeIfPresent(String.self, forKey: .sha1)
            ?? c.decodeIfPresent(String.self, forKey: .sha1sum)
        sha256sum = try c.decodeIfPresent(String.self, forKey: .sha256sum)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(version, forKey: .version)
        try container.encode(buildid, forKey: .buildid)
        try container.encodeIfPresent(sha1, forKey: .sha1)
        try container.encodeIfPresent(sha256sum, forKey: .sha256sum)
        try container.encodeIfPresent(filesize, forKey: .filesize)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(filename, forKey: .filename)
        try container.encodeIfPresent(releasedate, forKey: .releasedate)
        try container.encode(signed, forKey: .signed)
    }

    var downloadURL: URL? { URL(string: url) }

    nonisolated var releaseDateValue: Date? {
        FirmwareDateParser.date(from: releasedate)
    }

    nonisolated static func preferred(_ lhs: IPSWFirmware, over rhs: IPSWFirmware) -> Bool {
        switch (lhs.releaseDateValue, rhs.releaseDateValue) {
        case let (left?, right?) where left != right:
            return left > right
        default:
            let versionComparison = lhs.version.compare(rhs.version, options: .numeric)
            if versionComparison != .orderedSame {
                return versionComparison == .orderedDescending
            }
            return lhs.buildid.compare(rhs.buildid, options: .numeric) == .orderedDescending
        }
    }

    var filesizeMB: String {
        guard let size = filesize else { return "?" }
        let mb = Double(size) / 1_048_576
        if mb >= 1024 {
            return String(format: "%.2f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    static func placeholder(for identifier: String) -> IPSWFirmware {
        IPSWFirmware(
            identifier: identifier,
            version: "-",
            buildid: "pending",
            sha1: nil,
            sha256sum: nil,
            filesize: nil,
            url: "https://example.invalid/placeholder.ipsw",
            filename: nil,
            releasedate: nil,
            signed: false
        )
    }
}

enum SidebarSortOption: String, CaseIterable, Identifiable {
    case name
    case deviceType
    case firmwareVersion
    case firmwareReleaseDate
    case modelReleaseDate

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .name: return "sidebar.sort.name"
        case .deviceType: return "sidebar.sort.type"
        case .firmwareVersion: return "sidebar.sort.version"
        case .firmwareReleaseDate: return "sidebar.sort.release_date"
        case .modelReleaseDate: return "sidebar.sort.model_release"
        }
    }

    var localizedTitle: String {
        NSLocalizedString(localizationKey, comment: "")
    }

    var defaultAscending: Bool {
        switch self {
        case .name, .deviceType:
            return true
        case .firmwareVersion, .firmwareReleaseDate, .modelReleaseDate:
            return false
        }
    }
}

struct DeviceSortMetadata: Equatable {
    let latestFirmwareVersion: String?
    let latestFirmwareReleaseDate: Date?
    /// Proxy per la data di uscita del modello: prima data firmware disponibile.
    let modelReleaseDate: Date?
}

enum FirmwareDateParser {
    nonisolated static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: string) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - Download State

enum DownloadState: Equatable, Codable {
    case idle
    case queued
    case paused
    case downloading(progress: Double)
    case verifying           // SHA1 in corso (post-download)
    case completed(url: URL)
    case failed(error: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case progress
        case url
        case error
    }

    private enum Kind: String, Codable {
        case idle
        case queued
        case paused
        case downloading
        case verifying
        case completed
        case failed
    }

    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.queued, .queued): return true
        case (.paused, .paused): return true
        case (.verifying, .verifying): return true
        case (.downloading(let a), .downloading(let b)): return a == b
        case (.completed(let a), .completed(let b)): return a == b
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .idle:
            self = .idle
        case .queued:
            self = .queued
        case .paused:
            self = .paused
        case .downloading:
            self = .downloading(progress: try container.decode(Double.self, forKey: .progress))
        case .verifying:
            self = .verifying
        case .completed:
            self = .completed(url: try container.decode(URL.self, forKey: .url))
        case .failed:
            self = .failed(error: try container.decode(String.self, forKey: .error))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .idle:
            try container.encode(Kind.idle, forKey: .kind)
        case .queued:
            try container.encode(Kind.queued, forKey: .kind)
        case .paused:
            try container.encode(Kind.paused, forKey: .kind)
        case .downloading(let progress):
            try container.encode(Kind.downloading, forKey: .kind)
            try container.encode(progress, forKey: .progress)
        case .verifying:
            try container.encode(Kind.verifying, forKey: .kind)
        case .completed(let url):
            try container.encode(Kind.completed, forKey: .kind)
            try container.encode(url, forKey: .url)
        case .failed(let error):
            try container.encode(Kind.failed, forKey: .kind)
            try container.encode(error, forKey: .error)
        }
    }
}

// MARK: - Releases API

/// Singola release da /v4/releases
struct IPSWRelease: Codable {
    let name: String
    let date: String
    let count: Int?
    let type: String?  // "iOS", "iPadOS", "macOS", ecc.
}

/// Gruppo di release per data da /v4/releases
struct IPSWReleaseGroup: Codable {
    let date: String
    let releases: [IPSWRelease]
}

extension Sequence where Element == IPSWFirmware {
    nonisolated func newestSignedFirmware() -> IPSWFirmware? {
        self
            .filter(\.signed)
            .reduce(nil) { current, firmware in
                guard let current else { return firmware }
                return IPSWFirmware.preferred(firmware, over: current) ? firmware : current
            }
    }

    nonisolated func newestSignedFirmware(version: String) -> IPSWFirmware? {
        self
            .filter { $0.signed && $0.version == version }
            .reduce(nil) { current, firmware in
                guard let current else { return firmware }
                return IPSWFirmware.preferred(firmware, over: current) ? firmware : current
            }
    }
}

// MARK: - Download Task Info

struct DeviceDownloadTask: Identifiable, Codable {
    let id: String  // device identifier
    var device: IPSWDevice
    var firmware: IPSWFirmware
    var state: DownloadState = .idle
    var progressDetails: DownloadProgressDetails? = nil
    var attemptCount: Int = 0
    var lastErrorDescription: String? = nil
}

struct LocalFirmwareRecord: Identifiable, Equatable {
    let id: String
    let fileName: String
    let deviceIdentifier: String?
    let deviceName: String?
    let location: URL
    let fileSize: Int64
    let modifiedAt: Date?

    var title: String {
        deviceName ?? deviceIdentifier ?? fileName
    }

    var subtitle: String {
        if let deviceIdentifier, let deviceName {
            return "\(deviceName) • \(deviceIdentifier)"
        }
        if let deviceIdentifier {
            return deviceIdentifier
        }
        return fileName
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

struct PersistedAppState: Codable {
    let selectedDeviceIDs: Set<String>
    let downloadTasks: [String: DeviceDownloadTask]
    let pendingDownloadQueue: [String]
    let activityLog: [ActivityLogEntry]
    let resumeDataStore: [String: Data]
}
