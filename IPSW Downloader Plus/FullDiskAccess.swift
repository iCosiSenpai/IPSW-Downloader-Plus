//
//  FullDiskAccess.swift
//  IPSW Downloader Plus
//

import Foundation
import AppKit

enum FullDiskAccessStatus: Equatable, Sendable {
    case granted
    case denied
    case undetermined
}

enum FullDiskAccessChecker {
    private enum ProbeKind {
        case file
        case directory
    }

    /// Verifica il Full Disk Access tentando di leggere più percorsi protetti.
    /// Restituisce `.undetermined` se nessuno dei probe è disponibile sul sistema.
    nonisolated static func status() -> FullDiskAccessStatus {
        let fm = FileManager.default
        let library = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        let probes: [(url: URL, kind: ProbeKind)] = [
            (library.appendingPathComponent("Application Support/com.apple.TCC/TCC.db"), .file),
            (library.appendingPathComponent("Safari"), .directory),
            (library.appendingPathComponent("Messages"), .directory),
            (library.appendingPathComponent("Mail"), .directory)
        ]
        var foundAtLeastOneProbe = false
        var foundGrantedProbe = false
        var foundPermissionDeniedProbe = false

        for probe in probes where fm.fileExists(atPath: probe.url.path) {
            foundAtLeastOneProbe = true
            do {
                switch probe.kind {
                case .file:
                    let handle = try FileHandle(forReadingFrom: probe.url)
                    try handle.close()
                case .directory:
                    _ = try fm.contentsOfDirectory(at: probe.url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                }
                foundGrantedProbe = true
                break
            } catch {
                if isPermissionDenied(error) {
                    foundPermissionDeniedProbe = true
                }
            }
        }

        return resolveStatus(
            foundAtLeastOneProbe: foundAtLeastOneProbe,
            foundGrantedProbe: foundGrantedProbe,
            foundPermissionDeniedProbe: foundPermissionDeniedProbe
        )
    }

    nonisolated static func check() -> Bool {
        switch status() {
        case .granted:
            return true
        case .denied, .undetermined:
            return false
        }
    }

    nonisolated private static func isPermissionDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError
    }

    nonisolated static func resolveStatus(
        foundAtLeastOneProbe: Bool,
        foundGrantedProbe: Bool,
        foundPermissionDeniedProbe: Bool
    ) -> FullDiskAccessStatus {
        if foundGrantedProbe {
            return .granted
        }
        if foundPermissionDeniedProbe {
            return .denied
        }
        return foundAtLeastOneProbe ? .denied : .undetermined
    }

    @MainActor
    static func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
