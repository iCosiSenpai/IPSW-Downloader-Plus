//
//  IPSWModels.swift
//  IPSW Downloader Plus
//

import Foundation

// MARK: - Device

struct IPSWDevice: Decodable, Identifiable, Hashable {
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

struct IPSWFirmware: Decodable, Identifiable {
    let identifier: String
    let version: String
    let buildid: String
    let sha1: String?
    let filesize: Int64?
    let url: String
    let filename: String?
    let releasedate: String?
    let signed: Bool

    var id: String { buildid }

    // L'API usa nomi diversi a seconda dell'endpoint:
    //   /device/{id}       → sha1
    //   /ipsw/{version}    → sha1sum
    enum CodingKeys: String, CodingKey {
        case identifier, version, buildid
        case sha1, sha1sum
        case filesize, url, filename
        case releasedate, signed
    }

    init(
        identifier: String,
        version: String,
        buildid: String,
        sha1: String?,
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

enum DownloadState: Equatable {
    case idle
    case queued
    case downloading(progress: Double)
    case verifying           // SHA1 in corso (post-download)
    case completed(url: URL)
    case failed(error: String)

    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.queued, .queued): return true
        case (.verifying, .verifying): return true
        case (.downloading(let a), .downloading(let b)): return a == b
        case (.completed(let a), .completed(let b)): return a == b
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
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
}

// MARK: - Download Task Info

struct DeviceDownloadTask: Identifiable {
    let id: String  // device identifier
    var device: IPSWDevice
    var firmware: IPSWFirmware
    var state: DownloadState = .idle
}
