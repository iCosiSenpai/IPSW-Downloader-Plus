import Foundation
import Testing
@testable import IPSW_Downloader_Plus

// MARK: - Mock API Client

/// A fully controllable mock that conforms to IPSWAPIService for unit testing.
final class MockIPSWAPIClient: IPSWAPIService, @unchecked Sendable {

    // Stub results — set these before exercising the code under test.
    var devicesToReturn: [IPSWDevice] = []
    var deviceByIdentifier: [String: IPSWDevice] = [:]
    var latestIOSVersionToReturn: String = "18.4"
    var signedIdentifiersToReturn: Set<String> = []

    // Error stubs — when non-nil the corresponding method throws.
    var fetchDevicesError: Error?
    var fetchDeviceError: Error?
    var fetchLatestIOSVersionError: Error?
    var fetchSignedDeviceIdentifiersError: Error?

    // Call counters for verification.
    private(set) var fetchDevicesCallCount = 0
    private(set) var fetchDeviceCallArgs: [String] = []
    private(set) var fetchLatestIOSVersionCallCount = 0
    private(set) var fetchSignedDeviceIdentifiersCallArgs: [String] = []

    func fetchDevices() async throws -> [IPSWDevice] {
        fetchDevicesCallCount += 1
        if let error = fetchDevicesError { throw error }
        return devicesToReturn
    }

    func fetchDevice(identifier: String) async throws -> IPSWDevice {
        fetchDeviceCallArgs.append(identifier)
        if let error = fetchDeviceError { throw error }
        guard let device = deviceByIdentifier[identifier] else {
            throw IPSWError.invalidResponse
        }
        return device
    }

    func fetchLatestIOSVersion() async throws -> String {
        fetchLatestIOSVersionCallCount += 1
        if let error = fetchLatestIOSVersionError { throw error }
        return latestIOSVersionToReturn
    }

    func fetchSignedDeviceIdentifiers(for version: String) async throws -> Set<String> {
        fetchSignedDeviceIdentifiersCallArgs.append(version)
        if let error = fetchSignedDeviceIdentifiersError { throw error }
        return signedIdentifiersToReturn
    }
}

// MARK: - ViewModel Tests with Mock

struct ViewModelAPITests {

    // MARK: - Helpers

    private func makeFirmware(
        identifier: String = "iPhone17,1",
        version: String = "18.4",
        buildid: String = "22E100",
        signed: Bool = true,
        sha256sum: String? = nil
    ) -> IPSWFirmware {
        IPSWFirmware(
            identifier: identifier,
            version: version,
            buildid: buildid,
            sha1: "abc123",
            sha256sum: sha256sum,
            filesize: 5_000_000_000,
            url: "https://updates.cdn-apple.com/\(identifier)_\(version).ipsw",
            filename: "\(identifier)_\(version)_\(buildid)_Restore.ipsw",
            releasedate: "2026-03-01T00:00:00Z",
            signed: signed
        )
    }

    private func makeDevice(
        name: String = "iPhone 16 Pro",
        identifier: String = "iPhone17,1",
        firmwares: [IPSWFirmware]? = nil
    ) -> IPSWDevice {
        IPSWDevice(name: name, identifier: identifier, firmwares: firmwares)
    }

    // MARK: - loadDevices

    @MainActor @Test
    func loadDevicesPopulatesDevicesOnSuccess() async {
        let mock = MockIPSWAPIClient()
        let devices = [
            makeDevice(name: "iPhone 16 Pro", identifier: "iPhone17,1"),
            makeDevice(name: "iPad Pro (M4)", identifier: "iPad16,3"),
        ]
        mock.devicesToReturn = devices

        let vm = IPSWViewModel(apiClient: mock)
        await vm.loadDevices()

        #expect(vm.devices.count == 2)
        #expect(vm.devices[0].name == "iPhone 16 Pro")
        #expect(vm.devices[1].name == "iPad Pro (M4)")
        #expect(vm.isLoadingDevices == false)
        #expect(vm.deviceLoadError == nil)
        #expect(mock.fetchDevicesCallCount == 1)
    }

    @MainActor @Test
    func loadDevicesSetsErrorOnFailure() async {
        let mock = MockIPSWAPIClient()
        mock.fetchDevicesError = IPSWError.httpError(statusCode: 503)

        let vm = IPSWViewModel(apiClient: mock)
        await vm.loadDevices()

        #expect(vm.devices.isEmpty)
        #expect(vm.isLoadingDevices == false)
        #expect(vm.deviceLoadError != nil)
    }

    @MainActor @Test
    func loadDevicesAppendsActivityLogOnSuccess() async {
        let mock = MockIPSWAPIClient()
        mock.devicesToReturn = [makeDevice()]

        let vm = IPSWViewModel(apiClient: mock)
        await vm.loadDevices()

        #expect(vm.activityLog.contains(where: { $0.kind == .success }))
    }

    @MainActor @Test
    func loadDevicesAppendsErrorActivityOnFailure() async {
        let mock = MockIPSWAPIClient()
        mock.fetchDevicesError = IPSWError.networkTimeout

        let vm = IPSWViewModel(apiClient: mock)
        await vm.loadDevices()

        #expect(vm.activityLog.contains(where: { $0.kind == .error }))
    }
}

// MARK: - Device Category Tests

struct DeviceCategoryTests {

    @Test
    func iPhoneCategorisedAsITunes() {
        let category = DeviceCategory.from(identifier: "iPhone17,1")
        if case .iTunes(let productType) = category {
            #expect(productType == "iPhone")
        } else {
            Issue.record("Expected .iTunes(\"iPhone\")")
        }
    }

    @Test
    func iPadCategorisedAsITunes() {
        let category = DeviceCategory.from(identifier: "iPad16,3")
        if case .iTunes(let productType) = category {
            #expect(productType == "iPad")
        } else {
            Issue.record("Expected .iTunes(\"iPad\")")
        }
    }

    @Test
    func iPodCategorisedAsITunes() {
        let category = DeviceCategory.from(identifier: "iPod9,1")
        if case .iTunes(let productType) = category {
            #expect(productType == "iPod")
        } else {
            Issue.record("Expected .iTunes(\"iPod\")")
        }
    }

    @Test
    func appleTVCategorisedAsConfigurator() {
        let category = DeviceCategory.from(identifier: "AppleTV14,1")
        if case .configurator = category {
            // expected
        } else {
            Issue.record("Expected .configurator")
        }
    }

    @Test
    func homePodCategorisedAsConfigurator() {
        let category = DeviceCategory.from(identifier: "AudioAccessory6,1")
        if case .configurator = category {
            // expected
        } else {
            Issue.record("Expected .configurator")
        }
    }

    @Test
    func virtualMacCategorisedAsConfigurator() {
        let category = DeviceCategory.from(identifier: "VirtualMac2,1")
        if case .configurator = category {
            // expected
        } else {
            Issue.record("Expected .configurator")
        }
    }
}

// MARK: - Device Model Tests

struct DeviceModelTests {

    @Test
    func osLabelMapsCorrectly() {
        #expect(IPSWDevice(name: "iPhone 16", identifier: "iPhone17,1", firmwares: nil).osLabel == "iOS")
        #expect(IPSWDevice(name: "iPad Pro", identifier: "iPad16,3", firmwares: nil).osLabel == "iOS")
        #expect(IPSWDevice(name: "Apple TV 4K", identifier: "AppleTV14,1", firmwares: nil).osLabel == "tvOS")
        #expect(IPSWDevice(name: "HomePod", identifier: "AudioAccessory6,1", firmwares: nil).osLabel == "audioOS")
        #expect(IPSWDevice(name: "Vision Pro", identifier: "RealityDevice14,1", firmwares: nil).osLabel == "visionOS")
        #expect(IPSWDevice(name: "iBridge", identifier: "iBridge2,1", firmwares: nil).osLabel == "BridgeOS")
    }

    @Test
    func symbolNameMapsKnownDeviceTypes() {
        #expect(IPSWDevice(name: "iPhone", identifier: "iPhone17,1", firmwares: nil).symbolName == "iphone")
        #expect(IPSWDevice(name: "iPad", identifier: "iPad16,3", firmwares: nil).symbolName == "ipad")
        #expect(IPSWDevice(name: "Apple TV", identifier: "AppleTV14,1", firmwares: nil).symbolName == "appletv")
    }
}

// MARK: - Trusted URL Validation

struct TrustedURLTests {

    @Test
    func validAppleCDNDomainsAccepted() {
        let urls = [
            URL(string: "https://updates.cdn-apple.com/test.ipsw")!,
            URL(string: "https://appldnld.apple.com/ios18/test.ipsw")!,
            URL(string: "https://secure-appldnld.apple.com/test.ipsw")!,
        ]
        for url in urls {
            #expect(isValidIPSWURL(url), "Expected \(url) to be valid")
        }
    }

    @Test
    func untrustedDomainsRejected() {
        let urls = [
            URL(string: "https://malicious.example.com/fake.ipsw")!,
            URL(string: "https://apple.com.evil.net/test.ipsw")!,
            URL(string: "https://not-cdn-apple.com/test.ipsw")!,
        ]
        for url in urls {
            #expect(!isValidIPSWURL(url), "Expected \(url) to be rejected")
        }
    }

    @Test
    func urlWithNoHostRejected() {
        let url = URL(string: "file:///tmp/test.ipsw")!
        #expect(!isValidIPSWURL(url))
    }
}

// MARK: - Firmware Preference & Selection

struct FirmwareSelectionTests {

    private func makeFirmware(
        version: String,
        buildid: String,
        releasedate: String? = nil,
        signed: Bool = true,
        sha256sum: String? = nil
    ) -> IPSWFirmware {
        IPSWFirmware(
            identifier: "iPhone17,1",
            version: version,
            buildid: buildid,
            sha1: "abc",
            sha256sum: sha256sum,
            filesize: 100,
            url: "https://updates.cdn-apple.com/\(buildid).ipsw",
            filename: nil,
            releasedate: releasedate,
            signed: signed
        )
    }

    @Test
    func preferredFirmwarePicksNewerReleaseDateFirst() {
        let older = makeFirmware(version: "18.4", buildid: "22E100", releasedate: "2026-03-01T00:00:00Z")
        let newer = makeFirmware(version: "18.4", buildid: "22E101", releasedate: "2026-03-15T00:00:00Z")

        #expect(IPSWFirmware.preferred(newer, over: older))
        #expect(!IPSWFirmware.preferred(older, over: newer))
    }

    @Test
    func preferredFirmwareFallsBackToVersionComparison() {
        let lower = makeFirmware(version: "18.3", buildid: "22D100")
        let higher = makeFirmware(version: "18.4", buildid: "22E100")

        #expect(IPSWFirmware.preferred(higher, over: lower))
        #expect(!IPSWFirmware.preferred(lower, over: higher))
    }

    @Test
    func preferredFirmwareFallsBackToBuildIDWhenVersionsMatch() {
        let a = makeFirmware(version: "18.4", buildid: "22E100")
        let b = makeFirmware(version: "18.4", buildid: "22E200")

        #expect(IPSWFirmware.preferred(b, over: a))
    }

    @Test
    func newestSignedFirmwareIgnoresUnsigned() {
        let firmwares = [
            makeFirmware(version: "18.4", buildid: "22E100", signed: false),
            makeFirmware(version: "18.3", buildid: "22D100", signed: true),
        ]

        let result = firmwares.newestSignedFirmware()
        #expect(result?.buildid == "22D100")
    }

    @Test
    func newestSignedFirmwareReturnsNilWhenNoneSigned() {
        let firmwares = [
            makeFirmware(version: "18.4", buildid: "22E100", signed: false),
        ]
        #expect(firmwares.newestSignedFirmware() == nil)
    }

    @Test
    func sha256sumPreservedInRoundTrip() throws {
        let fw = makeFirmware(version: "18.4", buildid: "22E100", sha256sum: "deadbeef1234")
        let data = try JSONEncoder().encode(fw)
        let decoded = try JSONDecoder().decode(IPSWFirmware.self, from: data)
        #expect(decoded.sha256sum == "deadbeef1234")
    }

    @Test
    func sha256sumNilWhenNotProvided() throws {
        let fw = makeFirmware(version: "18.4", buildid: "22E100", sha256sum: nil)
        let data = try JSONEncoder().encode(fw)
        let decoded = try JSONDecoder().decode(IPSWFirmware.self, from: data)
        #expect(decoded.sha256sum == nil)
    }

    @Test
    func firmwarePlaceholderHasExpectedDefaults() {
        let placeholder = IPSWFirmware.placeholder(for: "iPhone17,1")
        #expect(placeholder.identifier == "iPhone17,1")
        #expect(placeholder.version == "-")
        #expect(placeholder.buildid == "pending")
        #expect(placeholder.signed == false)
        #expect(placeholder.sha256sum == nil)
    }

    @Test
    func firmwareFilesizeMBFormatsCorrectly() {
        let smallFW = IPSWFirmware(
            identifier: "iPhone17,1", version: "18.4", buildid: "22E100",
            sha1: nil, filesize: 524_288_000,
            url: "https://updates.cdn-apple.com/test.ipsw", filename: nil, releasedate: nil, signed: true
        )
        #expect(smallFW.filesizeMB.contains("MB"))

        let largeFW = IPSWFirmware(
            identifier: "iPhone17,1", version: "18.4", buildid: "22E100",
            sha1: nil, filesize: 5_368_709_120,
            url: "https://updates.cdn-apple.com/test.ipsw", filename: nil, releasedate: nil, signed: true
        )
        #expect(largeFW.filesizeMB.contains("GB"))

        let unknownFW = IPSWFirmware(
            identifier: "iPhone17,1", version: "18.4", buildid: "22E100",
            sha1: nil, filesize: nil,
            url: "https://updates.cdn-apple.com/test.ipsw", filename: nil, releasedate: nil, signed: true
        )
        #expect(unknownFW.filesizeMB == "?")
    }
}

// MARK: - Download Progress Details

struct DownloadProgressDetailsTests {

    @Test
    func percentTextFormatsCorrectly() {
        let details = DownloadProgressDetails(
            fractionCompleted: 0.756, bytesWritten: 756, totalBytesExpected: 1000, bytesPerSecond: 100
        )
        #expect(details.percentText == "75%")
    }

    @Test
    func etaTextShowsDashWhenNoSpeed() {
        let details = DownloadProgressDetails(
            fractionCompleted: 0.5, bytesWritten: 500, totalBytesExpected: 1000, bytesPerSecond: 0
        )
        #expect(details.etaText == "—")
    }

    @Test
    func speedTextShowsDashWhenZero() {
        let details = DownloadProgressDetails(
            fractionCompleted: 0.5, bytesWritten: 500, totalBytesExpected: 1000, bytesPerSecond: 0
        )
        #expect(details.speedText == "—")
    }

    @Test
    func transferredTextContainsSlash() {
        let details = DownloadProgressDetails(
            fractionCompleted: 0.5, bytesWritten: 500_000, totalBytesExpected: 1_000_000, bytesPerSecond: 100_000
        )
        #expect(details.transferredText.contains("/"))
    }
}

// MARK: - IPSWError Descriptions

struct IPSWErrorTests {

    @Test
    func allErrorCasesHaveLocalizedDescription() {
        let errors: [IPSWError] = [
            .invalidURL,
            .untrustedURL("https://evil.com"),
            .invalidResponse,
            .httpError(statusCode: 500),
            .noSignedFirmware,
            .downloadDirectoryUnavailable,
            .checksumMismatch(expected: "aaa", actual: "bbb"),
            .fullDiskAccessRequired,
            .networkTimeout,
            .connectionLost,
            .rateLimited,
        ]
        for error in errors {
            #expect(error.errorDescription != nil, "Missing description for \(error)")
            #expect(!error.errorDescription!.isEmpty, "Empty description for \(error)")
        }
    }
}

// MARK: - SHA-1 Fallback Decoding

struct FirmwareDecodingTests {

    @Test
    func sha1DecodesFromSha1sumKey() throws {
        // The API uses "sha1sum" in /ipsw/{version} endpoint but "sha1" in /device/{id}
        let json = """
        {
            "identifier": "iPhone17,1",
            "version": "18.4",
            "buildid": "22E100",
            "sha1sum": "fallback_hash",
            "filesize": 100,
            "url": "https://updates.cdn-apple.com/test.ipsw",
            "signed": true
        }
        """
        let data = json.data(using: .utf8)!
        let firmware = try JSONDecoder().decode(IPSWFirmware.self, from: data)
        #expect(firmware.sha1 == "fallback_hash")
    }

    @Test
    func sha1PrefersDirectKeyOverSha1sum() throws {
        let json = """
        {
            "identifier": "iPhone17,1",
            "version": "18.4",
            "buildid": "22E100",
            "sha1": "direct_hash",
            "sha1sum": "fallback_hash",
            "filesize": 100,
            "url": "https://updates.cdn-apple.com/test.ipsw",
            "signed": true
        }
        """
        let data = json.data(using: .utf8)!
        let firmware = try JSONDecoder().decode(IPSWFirmware.self, from: data)
        #expect(firmware.sha1 == "direct_hash")
    }

    @Test
    func sha256sumDecodesWhenPresent() throws {
        let json = """
        {
            "identifier": "iPhone17,1",
            "version": "18.4",
            "buildid": "22E100",
            "sha256sum": "sha256_hash_value",
            "filesize": 100,
            "url": "https://updates.cdn-apple.com/test.ipsw",
            "signed": true
        }
        """
        let data = json.data(using: .utf8)!
        let firmware = try JSONDecoder().decode(IPSWFirmware.self, from: data)
        #expect(firmware.sha256sum == "sha256_hash_value")
    }
}

// MARK: - Activity Log & Auto Launch Report

struct ActivityLogTests {

    @Test
    func autoLaunchReportNoFailuresIsSuccess() {
        let report = AutoLaunchReport(
            startedAt: Date(),
            finishedAt: Date(),
            checkedCount: 5,
            downloadedCount: 3,
            skippedCount: 2,
            failedCount: 0
        )
        #expect(!report.hadFailures)
        #expect(report.completionKind == .success)
    }

    @Test
    func activityLogKindSystemImages() {
        #expect(ActivityLogKind.info.systemImage == "info.circle.fill")
        #expect(ActivityLogKind.success.systemImage == "checkmark.circle.fill")
        #expect(ActivityLogKind.warning.systemImage == "exclamationmark.triangle.fill")
        #expect(ActivityLogKind.error.systemImage == "xmark.octagon.fill")
    }
}
