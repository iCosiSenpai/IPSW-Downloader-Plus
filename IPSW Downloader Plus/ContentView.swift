//
//  ContentView.swift
//  IPSW Downloader Plus
//

import SwiftUI
import AppKit

// MARK: - Root View

struct ContentView: View {
    @ObservedObject var viewModel: IPSWViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        VStack(spacing: 0) {
            navigationContainer

            // Footer links
            HStack(spacing: 16) {
                Link(destination: URL(string: "https://paypal.me/AlessioCosi")!) {
                    HStack(spacing: 8) {
                        Text("PayPal")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.0, green: 0.38, blue: 0.75), Color(red: 0.0, green: 0.62, blue: 0.89)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        Text(String(localized: "footer.donate"))
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Link(destination: URL(string: "https://github.com/iCosiSenpai")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.callout)
                            .foregroundStyle(.primary)
                        Text(String(localized: "footer.made_with"))
                            .font(.callout)
                        Image(systemName: "heart.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                        Text(String(localized: "footer.by_author"))
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .top)
        }
        .frame(minWidth: 980, minHeight: 600)
        .task {
            await viewModel.loadDevices()
        }
    }

    @ViewBuilder
    private var navigationContainer: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(viewModel: viewModel)
            } detail: {
                DetailView(viewModel: viewModel)
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationView {
                SidebarView(viewModel: viewModel)
                DetailView(viewModel: viewModel)
            }
        }
    }

}

// MARK: - Sidebar (Device List)

struct SidebarView: View {
    @ObservedObject var viewModel: IPSWViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "search.placeholder"), text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.background.opacity(0.6))
            .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .bottom)

            HStack(spacing: 8) {
                Picker(String(localized: "sidebar.sort.label"), selection: $viewModel.sortOption) {
                    ForEach(SidebarSortOption.allCases) { option in
                        Text(option.localizedTitle).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)

                Button {
                    viewModel.sortAscending.toggle()
                } label: {
                    Image(systemName: viewModel.sortAscending ? "arrow.up" : "arrow.down")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "sidebar.sort.order"))

                Spacer()

                Text(viewModel.activeSortSummary)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.bar)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .bottom)

            // Device List
            if viewModel.isLoadingDevices {
                Spacer()
                ProgressView(String(localized: "sidebar.loading"))
                Spacer()
            } else if let error = viewModel.deviceLoadError {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button(String(localized: "sidebar.retry")) {
                        Task { await viewModel.loadDevices() }
                    }
                }
                .padding()
                Spacer()
            } else {
                List(viewModel.filteredDevices, selection: .constant(nil as String?)) { device in
                    DeviceRowView(device: device, viewModel: viewModel)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
                .listStyle(.sidebar)
            }

            Divider()

            // Bottom toolbar
            HStack {
                Button {
                    Task { await viewModel.loadDevices() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help(String(localized: "sidebar.refresh.help"))

                Spacer()

                Button {
                    if viewModel.hasSelection {
                        viewModel.deselectAll()
                    } else {
                        viewModel.selectAll()
                    }
                } label: {
                    Image(systemName: viewModel.hasSelection ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .buttonStyle(.plain)
                .help(viewModel.hasSelection
                      ? String(localized: "sidebar.deselect_all.help")
                      : String(localized: "sidebar.select_all.help"))
            }
            .padding(8)
        }
        .modifier(CompatibleSidebarWidth())
        .navigationTitle(String(localized: "sidebar.nav_title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.openDownloadFolder()
                } label: {
                    Label(String(localized: "sidebar.toolbar.download_folder"), systemImage: "folder")
                }
                .help(String(localized: "sidebar.toolbar.download_folder.help"))
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openWindow(id: "settings")
                } label: {
                    Label(String(localized: "settings.tab.general"), systemImage: "gearshape")
                }
                .help(String(localized: "sidebar.toolbar.settings.help"))
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel.applyTemplateLatestIOS()
                    } label: {
                        if viewModel.isApplyingLatestIOSTemplate {
                            Label(String(localized: "sidebar.template.loading"), systemImage: "hourglass")
                        } else {
                            Label(String(localized: "sidebar.template.latest_ios"), systemImage: "iphone")
                        }
                    }
                    .disabled(viewModel.isApplyingLatestIOSTemplate)
                    Button {
                        viewModel.applyTemplateVintage()
                    } label: {
                        Label(String(localized: "sidebar.template.vintage"), systemImage: "clock.arrow.circlepath")
                    }
                } label: {
                    if viewModel.isApplyingLatestIOSTemplate {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(String(localized: "sidebar.toolbar.template"), systemImage: "wand.and.stars")
                    }
                }
                .help(String(localized: "sidebar.toolbar.template.help"))
                .alert(String(localized: "sidebar.template.error_title"), isPresented: Binding(
                    get: { viewModel.templateError != nil },
                    set: { if !$0 { viewModel.templateError = nil } }
                )) {
                    Button("OK") { viewModel.templateError = nil }
                } message: {
                    Text(viewModel.templateError ?? "")
                }
            }
        }
    }

}

private struct CompatibleSidebarWidth: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content.navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 480)
        } else {
            content.frame(minWidth: 280, idealWidth: 320, maxWidth: 480)
        }
    }
}

private struct CompatibleListRowSeparatorHidden: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content.listRowSeparator(.hidden)
        } else {
            content
        }
    }
}

// MARK: - Device Row

struct DeviceRowView: View {
    let device: IPSWDevice
    @ObservedObject var viewModel: IPSWViewModel

    private var state: DownloadState { viewModel.downloadState(for: device) }
    private var isSelected: Bool { viewModel.isSelected(device) }

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            Image(systemName: device.symbolName)
                .frame(width: 16)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .fontWeight(.medium)
                Text(device.identifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            stateIndicator
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let shiftHeld = NSEvent.modifierFlags.contains(.shift)
            viewModel.handleClick(on: device, shiftHeld: shiftHeld)
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch state {
        case .idle:
            EmptyView()
        case .queued:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text(String(localized: "download.queued")).font(.caption2).foregroundStyle(.secondary)
            }
        case .paused:
            HStack(spacing: 4) {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
                Text(String(localized: "download.paused")).font(.caption2).foregroundStyle(.secondary)
            }
        case .downloading(let progress):
            HStack(spacing: 6) {
                ProgressView(value: progress)
                    .frame(width: 60)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        case .verifying:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("SHA1…").font(.caption2).foregroundStyle(.secondary)
            }
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Detail View

struct DetailView: View {
    @ObservedObject var viewModel: IPSWViewModel

    private var managedDevices: [IPSWDevice] {
        viewModel.managedDownloadDevices
    }

    private var activeDevices: [IPSWDevice] {
        managedDevices.filter { device in
            switch viewModel.downloadState(for: device) {
            case .queued, .downloading, .verifying:
                return true
            default:
                return false
            }
        }
    }

    private var pausedDevices: [IPSWDevice] {
        managedDevices.filter { device in
            if case .paused = viewModel.downloadState(for: device) {
                return true
            }
            return false
        }
    }

    private var readyDevices: [IPSWDevice] {
        viewModel.orderedSelectedDevices.filter { device in
            if case .idle = viewModel.downloadState(for: device) {
                return true
            }
            return false
        }
    }

    private var completedDevices: [IPSWDevice] {
        viewModel.orderedSelectedDevices.filter { device in
            if case .completed = viewModel.downloadState(for: device) {
                return true
            }
            return false
        }
    }

    private var failedDevices: [IPSWDevice] {
        viewModel.orderedSelectedDevices.filter { device in
            if case .failed = viewModel.downloadState(for: device) {
                return true
            }
            return false
        }
    }

    private var recentActivityEntries: [ActivityLogEntry] {
        viewModel.recentActivityEntries.filter { entry in
            guard let identifier = entry.deviceIdentifier else { return true }
            return viewModel.selectedDeviceIDs.contains(identifier)
        }
    }

    private var headerStatusLine: String {
        String(
            format: String(localized: "detail.header.status"),
            readyDevices.count,
            activeDevices.count,
            completedDevices.count,
            failedDevices.count
        )
    }

    var body: some View {
        if viewModel.selectedDeviceIDs.isEmpty && managedDevices.isEmpty && viewModel.downloadedFirmware.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(String(localized: "detail.empty"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: String(localized: "detail.header.selected"), viewModel.selectedDeviceIDs.count))
                                .font(.headline)
                            Text(headerStatusLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            viewModel.openDownloadFolder()
                        } label: {
                            Label(String(localized: "detail.open_folder"), systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                        Button {
                            viewModel.downloadSelectedDevices()
                        } label: {
                            Label(String(localized: "detail.download_all"), systemImage: "arrow.down.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedDeviceIDs.isEmpty)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            SummaryChip(title: String(localized: "detail.section.managed"), count: managedDevices.count, color: .blue)
                            SummaryChip(title: String(localized: "detail.section.active"), count: activeDevices.count, color: .blue)
                            SummaryChip(title: String(localized: "detail.section.paused"), count: pausedDevices.count, color: .orange)
                            SummaryChip(title: String(localized: "detail.section.ready"), count: readyDevices.count, color: .secondary)
                            SummaryChip(title: String(localized: "detail.section.completed"), count: completedDevices.count, color: .green)
                            SummaryChip(title: String(localized: "detail.section.failed"), count: failedDevices.count, color: .red)
                            SummaryChip(title: String(localized: "detail.section.local"), count: viewModel.downloadedFirmware.count, color: .mint)
                        }
                    }
                }
                .padding()
                .background(.background)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .bottom)

                List {
                    ManagedDownloadsSectionList(
                        title: String(localized: "detail.section.managed"),
                        activeDevices: activeDevices,
                        pausedDevices: pausedDevices,
                        viewModel: viewModel
                    )
                    DownloadSectionList(title: String(localized: "detail.section.ready"), devices: readyDevices, viewModel: viewModel, allowsManagedSelection: false)
                    DownloadSectionList(title: String(localized: "detail.section.completed"), devices: completedDevices, viewModel: viewModel, allowsManagedSelection: false)
                    DownloadSectionList(title: String(localized: "detail.section.failed"), devices: failedDevices, viewModel: viewModel, allowsManagedSelection: false)
                    LocalFirmwareSectionList(records: viewModel.downloadedFirmware, viewModel: viewModel)
                    ActivitySectionList(entries: recentActivityEntries)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .navigationTitle(String(localized: "detail.navigation.title"))
        }
    }
}

private struct ActivitySectionList: View {
    let entries: [ActivityLogEntry]

    var body: some View {
        if !entries.isEmpty {
            Section {
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: entry.kind.systemImage)
                            .foregroundStyle(color(for: entry.kind))
                            .frame(width: 16, alignment: .center)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.title)
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text(String(localized: "detail.section.activity"))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
            }
        }
    }

    private func color(for kind: ActivityLogKind) -> Color {
        switch kind {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

private struct SummaryChip: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

private struct DownloadSectionList: View {
    let title: String
    let devices: [IPSWDevice]
    @ObservedObject var viewModel: IPSWViewModel
    let allowsManagedSelection: Bool

    var body: some View {
        if !devices.isEmpty {
            Section {
                ForEach(devices) { device in
                    DownloadTaskCard(device: device, viewModel: viewModel, allowsManagedSelection: allowsManagedSelection)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .modifier(CompatibleListRowSeparatorHidden())
                        .listRowBackground(Color.clear)
                        .contextMenu {
                            let state = viewModel.downloadState(for: device)
                            switch state {
                            case .queued, .downloading, .verifying:
                                Button {
                                    viewModel.pauseDownload(for: device)
                                } label: {
                                    Label(String(localized: "download.pause"), systemImage: "pause.circle")
                                }
                                Button(role: .destructive) {
                                    viewModel.cancelDownload(for: device)
                                } label: {
                                    Label(String(localized: "download.cancel"), systemImage: "stop.circle")
                                }
                            case .paused:
                                Button {
                                    viewModel.resumeDownload(for: device)
                                } label: {
                                    Label(String(localized: "download.resume"), systemImage: "play.circle")
                                }
                                Button(role: .destructive) {
                                    viewModel.cancelDownload(for: device)
                                } label: {
                                    Label(String(localized: "download.cancel"), systemImage: "stop.circle")
                                }
                            default:
                                EmptyView()
                            }
                            Button(role: .destructive) {
                                viewModel.removeDevice(device)
                            } label: {
                                Label(String(localized: "download.remove"), systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
            }
        }
    }
}

private struct ManagedDownloadsSectionList: View {
    let title: String
    let activeDevices: [IPSWDevice]
    let pausedDevices: [IPSWDevice]
    @ObservedObject var viewModel: IPSWViewModel

    private var managedDevices: [IPSWDevice] {
        activeDevices + pausedDevices
    }

    private var hasSelection: Bool {
        !viewModel.selectedManagedDownloadIDs.isEmpty
    }

    var body: some View {
        if !managedDevices.isEmpty {
            Section {
                HStack(spacing: 8) {
                    Button(String(localized: "download.pause_all")) {
                        if hasSelection {
                            viewModel.pauseSelectedManagedDownloads()
                        } else {
                            viewModel.pauseAllManagedDownloads()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button(String(localized: "download.cancel_all")) {
                        if hasSelection {
                            viewModel.cancelSelectedManagedDownloads()
                        } else {
                            viewModel.cancelAllManagedDownloads()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Spacer()

                    if hasSelection {
                        Text(String(format: String(localized: "download.selection_count"), viewModel.selectedManagedDownloadIDs.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)

                ForEach(managedDevices) { device in
                    DownloadTaskCard(device: device, viewModel: viewModel, allowsManagedSelection: true)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .modifier(CompatibleListRowSeparatorHidden())
                        .listRowBackground(Color.clear)
                }
            } header: {
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
            }
        }
    }
}

private struct LocalFirmwareSectionList: View {
    let records: [LocalFirmwareRecord]
    @ObservedObject var viewModel: IPSWViewModel

    var body: some View {
        if !records.isEmpty {
            Section {
                ForEach(records) { record in
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.fill")
                            .foregroundStyle(.mint)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.title)
                                .font(.headline)
                            Text(record.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(record.fileName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(record.sizeText)
                                .font(.caption.weight(.semibold))
                            if let modifiedAt = record.modifiedAt {
                                Text(modifiedAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Button(String(localized: "download.show_in_finder")) {
                                viewModel.revealInFinder(record.location)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text(String(localized: "detail.section.local"))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
            }
        }
    }
}

// MARK: - Download Task Card

struct DownloadTaskCard: View {
    let device: IPSWDevice
    @ObservedObject var viewModel: IPSWViewModel
    let allowsManagedSelection: Bool

    private var state: DownloadState { viewModel.downloadState(for: device) }
    private var task: DeviceDownloadTask? { viewModel.downloadTasks[device.identifier] }
    private var isManagedSelected: Bool { viewModel.isManagedDownloadSelected(device) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Device name & identifier
            HStack {
                if allowsManagedSelection {
                    Button {
                        viewModel.toggleManagedDownloadSelection(device)
                    } label: {
                        Image(systemName: isManagedSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isManagedSelected ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                    Text(device.identifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
                actionButton
            }

            // Firmware info
            if let fw = task?.firmware {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 16) {
                        Label("\(device.osLabel) \(fw.version)", systemImage: "cpu")
                        Label(fw.buildid, systemImage: "number")
                        Label(fw.filesizeMB, systemImage: "internaldrive")
                    }
                    HStack(spacing: 16) {
                        if fw.signed {
                            Label(String(localized: "download.signed"), systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                        switch device.category {
                        case .iTunes(let pt):
                            Label("iTunes / \(pt)", systemImage: "music.note")
                                .help("~/Library/iTunes/\(pt) Software Updates")
                        case .configurator:
                            Label("Configurator", systemImage: "apps.iphone")
                                .help("~/Library/Group Containers/K36BKF7T3D…/Firmware")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Progress / state
            switch state {
            case .queued:
                queuedStateView
            case .paused:
                pausedStateView
            case .verifying:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "download.verifying"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .downloading(let progress):
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text(String(localized: "download.in_progress"))
                        Spacer()
                        Text(task?.progressDetails?.percentText ?? "\(Int(progress * 100))%")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if let details = task?.progressDetails {
                        HStack {
                            Text(details.transferredText)
                            Spacer()
                            Text(details.speedText)
                            Text("·")
                            Text(String(format: String(localized: "download.eta"), details.etaText))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            case .completed(let url):
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(String(localized: "download.completed"))
                        .foregroundStyle(.green)
                    Spacer()
                    Button(String(localized: "download.show_in_finder")) {
                        viewModel.revealInFinder(url)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .font(.caption)
            case .failed(let error):
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                    .font(.caption)

                    if let attemptLabel {
                        Text(attemptLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            case .idle:
                EmptyView()
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .idle, .failed:
            Button {
                Task { await viewModel.startDownload(for: device) }
            } label: {
                Label(String(localized: "download.action.download"), systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .queued:
            Button {
                viewModel.pauseDownload(for: device)
            } label: {
                Label(String(localized: "download.action.pause"), systemImage: "pause.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
        case .downloading:
            Button {
                viewModel.pauseDownload(for: device)
            } label: {
                Label(String(localized: "download.action.pause"), systemImage: "pause.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
        case .paused:
            Button {
                viewModel.resumeDownload(for: device)
            } label: {
                Label(String(localized: "download.action.resume"), systemImage: "play.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        case .verifying:
            Button { } label: {
                Label(String(localized: "download.action.verifying"), systemImage: "checkmark.shield")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(true)
        case .completed:
            Button {
                Task { await viewModel.startDownload(for: device) }
            } label: {
                Label(String(localized: "download.action.redownload"), systemImage: "arrow.clockwise.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var queuedStateView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(String(localized: "download.queued"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let attemptLabel {
                Text(attemptLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var pausedStateView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
                Text(String(localized: "download.paused"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let attemptLabel {
                Text(attemptLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var attemptLabel: String? {
        guard let task, task.attemptCount > 0 else { return nil }
        return String(format: String(localized: "download.attempt"), task.attemptCount, 3)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch state {
        case .idle:
            EmptyView()
        case .queued:
            badge(String(localized: "download.queued"), color: .orange)
        case .paused:
            badge(String(localized: "download.paused"), color: .orange)
        case .downloading:
            badge(String(localized: "download.in_progress"), color: .blue)
        case .verifying:
            badge(String(localized: "download.verifying"), color: .mint)
        case .completed:
            badge(String(localized: "download.completed"), color: .green)
        case .failed:
            badge(String(localized: "detail.section.failed"), color: .red)
        }
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var cardBackground: Color {
        switch state {
        case .completed:
            return .green.opacity(0.04)
        case .failed:
            return .red.opacity(0.05)
        case .paused:
            return .orange.opacity(0.05)
        case .downloading, .queued, .verifying:
            return .blue.opacity(0.04)
        case .idle:
            return Color(NSColor.windowBackgroundColor)
        }
    }

    private var cardBorder: Color {
        switch state {
        case .completed:
            return .green.opacity(0.18)
        case .failed:
            return .red.opacity(0.18)
        case .paused:
            return .orange.opacity(0.18)
        case .downloading, .queued, .verifying:
            return .blue.opacity(0.16)
        case .idle:
            return .primary.opacity(0.08)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: IPSWViewModel())
    }
}
