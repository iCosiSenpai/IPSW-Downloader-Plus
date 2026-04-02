//
//  SchedulingService.swift
//  IPSW Downloader Plus
//

import Foundation

struct SchedulingStatusSnapshot {
    let installed: Bool
    let loaded: Bool
    let error: String?
}

struct SchedulingOperationResult {
    let launchAgentInstalled: Bool
    let launchAgentLoaded: Bool
    let launchAgentError: String?
    let wakeScheduleActive: Bool
    let wakeScheduleError: String?
}

enum SchedulingService {
    static func queryLaunchAgentStatus(
        plistURL: URL?,
        launchAgentServiceIdentifier: String,
        previousError: String?
    ) -> SchedulingStatusSnapshot {
        guard let plistURL else {
            return SchedulingStatusSnapshot(installed: false, loaded: false, error: previousError)
        }

        let installed = FileManager.default.fileExists(atPath: plistURL.path)
        guard installed else {
            return SchedulingStatusSnapshot(installed: false, loaded: false, error: previousError)
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", launchAgentServiceIdentifier]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            let loaded = process.terminationStatus == 0
            let resolvedError = loaded ? nil : previousError
            return SchedulingStatusSnapshot(installed: installed, loaded: loaded, error: resolvedError)
        } catch {
            return SchedulingStatusSnapshot(installed: installed, loaded: false, error: error.localizedDescription)
        }
    }

    static func configureLaunchAgent(
        enabled: Bool,
        plistURL: URL?,
        appPath: String?,
        launchAgentLabel: String,
        launchAgentDomain: String,
        launchAgentServiceIdentifier: String,
        autoLaunchHour: Int,
        autoLaunchMinute: Int,
        autoLaunchDays: Set<Int>
    ) -> String? {
        guard let plistURL else { return nil }

        if !enabled {
            if FileManager.default.fileExists(atPath: plistURL.path) {
                let launchAgentError = runLaunchctl(arguments: ["bootout", launchAgentServiceIdentifier], ignoreFailure: true)
                try? FileManager.default.removeItem(at: plistURL)
                return launchAgentError
            }
            return nil
        }

        guard let appPath else { return nil }

        let plist: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [appPath, "--auto-launch"],
            "StartCalendarInterval": launchAgentCalendarIntervals(hour: autoLaunchHour, minute: autoLaunchMinute, days: autoLaunchDays),
            "RunAtLoad": false,
            "StandardOutPath": "/tmp/ipsw-downloader-plus.log",
            "StandardErrorPath": "/tmp/ipsw-downloader-plus-error.log"
        ]

        do {
            let dir = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL)
            let bootoutResult = runLaunchctl(arguments: ["bootout", launchAgentServiceIdentifier], ignoreFailure: true)
            let bootstrapResult = runLaunchctl(arguments: ["bootstrap", launchAgentDomain, plistURL.path], ignoreFailure: false)
            let enableResult = bootstrapResult == nil
                ? runLaunchctl(arguments: ["enable", launchAgentServiceIdentifier], ignoreFailure: false)
                : nil
            return bootstrapResult ?? enableResult ?? bootoutResult
        } catch {
            return error.localizedDescription
        }
    }

    static func launchAgentCalendarIntervals(hour: Int, minute: Int, days: Set<Int>) -> [[String: Int]] {
        if days.isEmpty {
            return [["Hour": hour, "Minute": minute]]
        }
        return days.sorted().map { day in
            [
                "Weekday": day,
                "Hour": hour,
                "Minute": minute
            ]
        }
    }

    private static func runLaunchctl(arguments: [String], ignoreFailure: Bool) -> String? {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus != 0 else { return nil }
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let message = (
                String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            ).flatMap { $0.isEmpty ? nil : $0 }
            ?? (
                String(data: outputData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            ).flatMap { $0.isEmpty ? nil : $0 }
            return ignoreFailure ? nil : (message?.isEmpty == false ? message : String(localized: "settings.schedule.agent.command_failed"))
        } catch {
            return ignoreFailure ? nil : error.localizedDescription
        }
    }
}
