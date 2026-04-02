//
//  WakeScheduler.swift
//  IPSW Downloader Plus
//

import Foundation

/// Gestisce la pianificazione della sveglia del Mac tramite `pmset repeat wakeorpoweron`.
/// Richiede privilegi di amministratore — usa il dialogo standard di autorizzazione macOS.
enum WakeScheduler {
    private static let statusProcessTimeout: TimeInterval = 5

    // Mappatura Weekday.rawValue (1=Dom..7=Sab) → codici pmset
    private static let pmsetDayCodes: [Int: String] = [
        1: "U",  // Sunday / Domenica
        2: "M",  // Monday / Lunedì
        3: "T",  // Tuesday / Martedì
        4: "W",  // Wednesday / Mercoledì
        5: "R",  // Thursday / Giovedì
        6: "F",  // Friday / Venerdì
        7: "S",  // Saturday / Sabato
    ]

    /// Imposta una sveglia ripetuta 2 minuti prima dell'orario indicato.
    /// Utilizza `pmset repeat wakeorpoweron` che funziona sia da sleep che da spento.
    /// Mostra il dialogo password admin standard di macOS al primo utilizzo.
    /// Restituisce nil in caso di successo, oppure la stringa di errore.
    @discardableResult
    static func scheduleWake(hour: Int, minute: Int, days: Set<Int>) -> String? {
        guard let command = scheduleWakeCommand(hour: hour, minute: minute, days: days) else {
            return "Nessun giorno valido selezionato."
        }
        return runWithAdminPrivileges(command)
    }

    /// Cancella tutti gli schedule repeat di pmset.
    /// Restituisce nil in caso di successo, oppure la stringa di errore.
    @discardableResult
    static func cancelWake() -> String? {
        return runWithAdminPrivileges("/usr/bin/pmset repeat cancel")
    }

    /// Controlla se è attivo uno schedule `wakeorpoweron` leggendo `pmset -g repeat`.
    static func isWakeScheduleActive() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "repeat"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let deadline = Date().addingTimeInterval(statusProcessTimeout)
            while process.isRunning && Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            }
            if process.isRunning {
                process.terminate()
                return false
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains("wakeorpoweron") || output.contains("wakepoweron")
        } catch {
            return false
        }
    }

    /// Esegue un comando shell con privilegi di amministratore tramite AppleScript.
    /// Mostra il dialogo password standard di macOS se necessario.
    private static func runWithAdminPrivileges(_ command: String) -> String? {
        // Escape caratteri speciali per AppleScript
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"\(escaped)\" with administrator privileges"

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return "Impossibile creare lo script AppleScript."
        }
        appleScript.executeAndReturnError(&error)

        if let error = error {
            // Codice 1004 = utente ha annullato il dialogo password
            if let code = error[NSAppleScript.errorNumber] as? Int, code == -128 {
                return String(localized: "wake.error.cancelled")
            }
            return error[NSAppleScript.errorMessage] as? String
                ?? String(localized: "wake.error.unknown")
        }
        return nil
    }

    static func scheduleWakeCommand(hour: Int, minute: Int, days: Set<Int>) -> String? {
        let wakeTime = wakeTimeComponents(hour: hour, minute: minute)
        let timeString = String(format: "%02d:%02d:00", wakeTime.hour, wakeTime.minute)

        let dayString: String
        if days.isEmpty {
            dayString = "MTWRFSU"
        } else {
            dayString = days.sorted()
                .compactMap { pmsetDayCodes[$0] }
                .joined()
        }

        guard !dayString.isEmpty else { return nil }
        return "/usr/bin/pmset repeat wakeorpoweron \(dayString) \(timeString)"
    }

    static func wakeTimeComponents(hour: Int, minute: Int) -> (hour: Int, minute: Int) {
        var wakeMinute = minute - 2
        var wakeHour = hour
        if wakeMinute < 0 {
            wakeMinute += 60
            wakeHour -= 1
            if wakeHour < 0 { wakeHour = 23 }
        }
        return (wakeHour, wakeMinute)
    }
}
