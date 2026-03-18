//
//  IPSWModels.swift
//  IPSW Downloader Plus
//

import Foundation

// MARK: - Device

struct IPSWDevice: Decodable, Identifiable, Hashable {
    let name: String
    let identifier: String
    let boardconfig: String?
    let platform: String?
    let cpid: Int?
    let bdid: Int?
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
    let sha256: String?
    let md5: String?
    let sha1: String?
    let filesize: Int64?
    let url: String
    let filename: String?
    let releasedate: String?
    let uploaddate: String?
    let signed: Bool

    var id: String { buildid }

    // L'API usa nomi diversi a seconda dell'endpoint:
    //   /device/{id}       → sha1, sha256, md5
    //   /ipsw/{version}    → sha1sum, sha256sum, md5sum
    // CodingKeys mappa entrambi: il decoder tenta prima la chiave esplicita,
    // poi quella alternativa tramite init(from:) personalizzato.
    enum CodingKeys: String, CodingKey {
        case identifier, version, buildid
        case sha256, sha256sum
        case md5, md5sum
        case sha1, sha1sum
        case filesize, url, filename
        case releasedate, uploaddate, signed
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
        uploaddate  = try c.decodeIfPresent(String.self,  forKey: .uploaddate)
        signed      = try c.decode(Bool.self,     forKey: .signed)
        sha256 = try c.decodeIfPresent(String.self, forKey: .sha256)
            ?? c.decodeIfPresent(String.self, forKey: .sha256sum)
        md5    = try c.decodeIfPresent(String.self, forKey: .md5)
            ?? c.decodeIfPresent(String.self, forKey: .md5sum)
        sha1   = try c.decodeIfPresent(String.self, forKey: .sha1)
            ?? c.decodeIfPresent(String.self, forKey: .sha1sum)
    }

    var downloadURL: URL? { URL(string: url) }

    var filesizeMB: String {
        guard let size = filesize else { return "?" }
        let mb = Double(size) / 1_048_576
        if mb >= 1024 {
            return String(format: "%.2f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Download State

enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double)
    case verifying           // SHA1 in corso (post-download)
    case completed(url: URL)
    case failed(error: String)

    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
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

// MARK: - Download Task Info

struct DeviceDownloadTask: Identifiable {
    let id: String  // device identifier
    var device: IPSWDevice
    var firmware: IPSWFirmware
    var state: DownloadState = .idle
}
