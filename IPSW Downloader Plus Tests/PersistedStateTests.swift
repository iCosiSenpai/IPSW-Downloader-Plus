import Foundation
import Testing
@testable import IPSW_Downloader_Plus

struct PersistedStateTests {

    @Test
    func downloadStateCodableRoundTrip() throws {
        let original: DownloadState = .completed(url: URL(fileURLWithPath: "/tmp/test.ipsw"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DownloadState.self, from: data)

        #expect(decoded == original)
    }

    @Test
    func persistedAppStateRoundTripPreservesResumeData() throws {
        let device = IPSWDevice(name: "iPhone Test", identifier: "iPhone17,1", firmwares: nil)
        let firmware = IPSWFirmware(
            identifier: "iPhone17,1",
            version: "18.0",
            buildid: "22A000",
            sha1: "abc123",
            filesize: 1024,
            url: "https://updates.cdn-apple.com/test.ipsw",
            filename: "test.ipsw",
            releasedate: "2026-01-01T00:00:00Z",
            signed: true
        )
        let task = DeviceDownloadTask(
            id: device.identifier,
            device: device,
            firmware: firmware,
            state: .queued,
            progressDetails: DownloadProgressDetails(
                fractionCompleted: 0.5,
                bytesWritten: 512,
                totalBytesExpected: 1024,
                bytesPerSecond: 128
            ),
            attemptCount: 2,
            lastErrorDescription: "Network interrupted"
        )
        let snapshot = PersistedAppState(
            selectedDeviceIDs: [device.identifier],
            downloadTasks: [device.identifier: task],
            pendingDownloadQueue: [device.identifier],
            activityLog: [
                ActivityLogEntry(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                    kind: .info,
                    deviceIdentifier: device.identifier,
                    title: "Restored",
                    message: "Restored from a previous session"
                )
            ],
            resumeDataStore: [device.identifier: Data([0x01, 0x02, 0x03])]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PersistedAppState.self, from: data)

        #expect(decoded.selectedDeviceIDs == snapshot.selectedDeviceIDs)
        #expect(decoded.pendingDownloadQueue == snapshot.pendingDownloadQueue)
        #expect(decoded.downloadTasks[device.identifier]?.attemptCount == 2)
        #expect(decoded.resumeDataStore[device.identifier] == Data([0x01, 0x02, 0x03]))
        #expect(decoded.activityLog.count == 1)
    }

    @Test
    func normalizedRestoredTasksQueuesInterruptedDownloads() {
        let device = IPSWDevice(name: "iPad Test", identifier: "iPad17,1", firmwares: nil)
        let firmware = IPSWFirmware.placeholder(for: device.identifier)
        let tasks: [String: DeviceDownloadTask] = [
            "downloading": DeviceDownloadTask(
                id: "downloading",
                device: device,
                firmware: firmware,
                state: .downloading(progress: 0.4),
                progressDetails: DownloadProgressDetails(
                    fractionCompleted: 0.4,
                    bytesWritten: 400,
                    totalBytesExpected: 1000,
                    bytesPerSecond: 100
                )
            ),
            "verifying": DeviceDownloadTask(
                id: "verifying",
                device: device,
                firmware: firmware,
                state: .verifying
            ),
            "completed": DeviceDownloadTask(
                id: "completed",
                device: device,
                firmware: firmware,
                state: .completed(url: URL(fileURLWithPath: "/tmp/completed.ipsw"))
            )
        ]

        let normalized = IPSWViewModel.normalizedRestoredTasks(tasks)

        #expect(normalized["downloading"]?.state == .queued)
        #expect(normalized["downloading"]?.progressDetails == nil)
        #expect(normalized["verifying"]?.state == .queued)
        #expect(normalized["completed"]?.state == .completed(url: URL(fileURLWithPath: "/tmp/completed.ipsw")))
    }

    @Test
    func retryPolicyMatchesTransientNetworkErrorsOnlyWithinLimit() {
        let transient = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let permanent = NSError(domain: NSURLErrorDomain, code: NSURLErrorUserAuthenticationRequired)

        #expect(IPSWViewModel.shouldRetryDownload(error: transient, attempt: 1, maxRetryCount: 2))
        #expect(IPSWViewModel.shouldRetryDownload(error: IPSWError.httpError(statusCode: 503), attempt: 2, maxRetryCount: 2))
        #expect(!IPSWViewModel.shouldRetryDownload(error: transient, attempt: 3, maxRetryCount: 2))
        #expect(!IPSWViewModel.shouldRetryDownload(error: permanent, attempt: 1, maxRetryCount: 2))
        #expect(!IPSWViewModel.shouldRetryDownload(error: IPSWError.httpError(statusCode: 404), attempt: 1, maxRetryCount: 2))
    }

    @Test
    func newestSignedFirmwareForSpecificVersionPicksPreferredMatch() {
        let firmwares = [
            IPSWFirmware(
                identifier: "iPhone17,1",
                version: "18.4",
                buildid: "22E100",
                sha1: nil,
                filesize: 100,
                url: "https://updates.cdn-apple.com/older.ipsw",
                filename: nil,
                releasedate: "2026-03-01T00:00:00Z",
                signed: true
            ),
            IPSWFirmware(
                identifier: "iPhone17,1",
                version: "18.4",
                buildid: "22E101",
                sha1: nil,
                filesize: 100,
                url: "https://updates.cdn-apple.com/newer.ipsw",
                filename: nil,
                releasedate: "2026-03-02T00:00:00Z",
                signed: true
            ),
            IPSWFirmware(
                identifier: "iPhone17,1",
                version: "18.5",
                buildid: "22F100",
                sha1: nil,
                filesize: 100,
                url: "https://updates.cdn-apple.com/other.ipsw",
                filename: nil,
                releasedate: "2026-03-03T00:00:00Z",
                signed: true
            )
        ]

        let result = firmwares.newestSignedFirmware(version: "18.4")

        #expect(result?.buildid == "22E101")
    }

    @Test
    func fullDiskAccessResolutionDistinguishesDeniedAndUndetermined() {
        #expect(
            FullDiskAccessChecker.resolveStatus(
                foundAtLeastOneProbe: true,
                foundGrantedProbe: false,
                foundPermissionDeniedProbe: true
            ) == .denied
        )
        #expect(
            FullDiskAccessChecker.resolveStatus(
                foundAtLeastOneProbe: false,
                foundGrantedProbe: false,
                foundPermissionDeniedProbe: false
            ) == .undetermined
        )
        #expect(
            FullDiskAccessChecker.resolveStatus(
                foundAtLeastOneProbe: true,
                foundGrantedProbe: true,
                foundPermissionDeniedProbe: false
            ) == .granted
        )
    }

    @Test
    func autoLaunchReportTracksFailureState() {
        let report = AutoLaunchReport(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            finishedAt: Date(timeIntervalSince1970: 1_700_000_300),
            checkedCount: 8,
            downloadedCount: 3,
            skippedCount: 4,
            failedCount: 1
        )

        #expect(report.hadFailures)
        #expect(report.completionKind == .warning)
    }
}
