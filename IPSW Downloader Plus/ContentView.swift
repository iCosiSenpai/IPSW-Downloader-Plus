//
//  ContentView.swift
//  IPSW Downloader Plus
//

import SwiftUI
import AppKit

// MARK: - Root View

struct ContentView: View {
    @ObservedObject var viewModel: IPSWViewModel

    var body: some View {
        VStack(spacing: 0) {
            navigationContainer

            // Footer with GitHub link
            HStack {
                Spacer()
                Link(destination: URL(string: "https://github.com/iCosiSenpai")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.caption2)
                        Text("iCosiSenpai")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.bar)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .top)
        }
        .frame(minWidth: 900, minHeight: 540)
        .task {
            await viewModel.loadDevices()
        }
    }

    @ViewBuilder
    private var navigationContainer: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView(columnVisibility: .constant(.all)) {
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

    var body: some View {
        if viewModel.selectedDeviceIDs.isEmpty {
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
                HStack {
                    Text(String(format: String(localized: "detail.header.selected"), viewModel.selectedDeviceIDs.count))
                        .font(.headline)
                    Spacer()
                    Button {
                        viewModel.downloadSelectedDevices()
                    } label: {
                        Label(String(localized: "detail.download_all"), systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedDeviceIDs.isEmpty)
                }
                .padding()
                .background(.background)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .bottom)

                List {
                    ForEach(viewModel.orderedSelectedDevices) { device in
                        DownloadTaskCard(device: device, viewModel: viewModel)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                            .modifier(CompatibleListRowSeparatorHidden())
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                let state = viewModel.downloadState(for: device)
                                if case .downloading = state {
                                    Button(role: .destructive) {
                                        viewModel.cancelDownload(for: device)
                                    } label: {
                                        Label(String(localized: "download.cancel"), systemImage: "stop.circle")
                                    }
                                }
                                Button(role: .destructive) {
                                    viewModel.removeDevice(device)
                                } label: {
                                    Label(String(localized: "download.remove"), systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in
                        viewModel.removeDevices(at: offsets)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(String(localized: "sidebar.toolbar.download_folder"))
        }
    }
}

// MARK: - Download Task Card

struct DownloadTaskCard: View {
    let device: IPSWDevice
    @ObservedObject var viewModel: IPSWViewModel

    private var state: DownloadState { viewModel.downloadState(for: device) }
    private var task: DeviceDownloadTask? { viewModel.downloadTasks[device.identifier] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Device name & identifier
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                    Text(device.identifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                actionButton
            }

            // Firmware info
            if let fw = task?.firmware {
                HStack(spacing: 16) {
                    Label("\(device.osLabel) \(fw.version)", systemImage: "cpu")
                    Label(fw.buildid, systemImage: "number")
                    Label(fw.filesizeMB, systemImage: "internaldrive")
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
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Progress / state
            switch state {
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
                        Text("\(Int(progress * 100))%")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                .font(.caption)
            case .idle:
                EmptyView()
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
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
        case .downloading:
            Button {
                viewModel.cancelDownload(for: device)
            } label: {
                Label(String(localized: "download.action.cancel"), systemImage: "stop.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
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
}

// MARK: - Preview

#Preview {
    ContentView(viewModel: IPSWViewModel())
}
