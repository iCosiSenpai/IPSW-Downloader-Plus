//
//  FullDiskAccess.swift
//  IPSW Downloader Plus
//

import Foundation
import AppKit

enum FullDiskAccessChecker {
    /// Verifica il Full Disk Access tentando di leggere uno fra più percorsi protetti
    /// che tipicamente richiedono questo permesso. Usare più probe riduce i falsi
    /// negativi sui sistemi dove Safari o altri database non esistono ancora.
    nonisolated static func check() -> Bool {
        let fm = FileManager.default
        let library = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        let protectedPaths = [
            library.appendingPathComponent("Application Support/com.apple.TCC/TCC.db"),
            library.appendingPathComponent("Safari/History.db"),
            library.appendingPathComponent("Messages/chat.db"),
            library.appendingPathComponent("Mail")
        ]

        for url in protectedPaths where fm.fileExists(atPath: url.path) {
            if fm.isReadableFile(atPath: url.path) {
                return true
            }
        }

        return false
    }

    @MainActor
    static func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
