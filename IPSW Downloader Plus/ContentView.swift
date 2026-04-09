//
//  ContentView.swift
//  IPSW Downloader Plus
//
//  Complete UI rewrite — clean, minimal, no duplicate controls.
//

import SwiftUI
import AppKit

// MARK: - Root View

struct ContentView: View {
    @ObservedObject var viewModel: IPSWViewModel
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Compact global download bar — only when active
            if viewModel.hasActiveDownloads {
                GlobalDownloadBar(viewModel: viewModel)
            }

            // Update banner — when firmware updates detected at startup
            if !viewModel.firmwareUpdatesAvailable.isEmpty {
                UpdateBanner(viewModel: viewModel)
            }

            navigationContainer
        }
        .frame(minWidth: 900, minHeight: 550)
        .navigationTitle(String(localized: "sidebar.nav_title"))
        .toolbar { mainToolbar }
        .liquidGlassToolbar()
        .background {
            if !AppCompatibility.usesLegacySwiftUIWorkarounds {
                WindowChromeConfigurator()
            }
        }
        .task {
            await viewModel.loadDevices()
        }
    }

    @ViewBuilder
    private var navigationContainer: some View {
        if AppCompatibility.usesLegacySwiftUIWorkarounds {
            HSplitView {
                SidebarView(viewModel: viewModel)
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 420)
                DetailView(viewModel: viewModel)
                    .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            NavigationSplitView {
                SidebarView(viewModel: viewModel)
            } detail: {
                DetailView(viewModel: viewModel)
            }
            .navigationSplitViewStyle(.balanced)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                Task { await viewModel.loadDevices() }
            } label: {
                Label(String(localized: "sidebar.refresh.help"), systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .disabled(viewModel.isLoadingDevices)
            .help(String(localized: "sidebar.refresh.help"))
        }

        ToolbarItemGroup(placement: .automatic) {
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
                Label(String(localized: "sidebar.toolbar.template"), systemImage: "wand.and.stars")
            }
            .help(String(localized: "sidebar.toolbar.template.help"))

            Button {
                viewModel.downloadSelectedDevices()
            } label: {
                Label(String(localized: "dashboard.action.download"), systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.hasSelection)
            .help(String(localized: "dashboard.action.download"))

            Button {
                viewModel.openDownloadFolder()
            } label: {
                Label(String(localized: "sidebar.toolbar.download_folder"), systemImage: "folder")
            }
            .labelStyle(.iconOnly)
            .help(String(localized: "sidebar.toolbar.download_folder.help"))

            Button {
                SettingsPresenter.open()
            } label: {
                Label(String(localized: "settings.menu.open"), systemImage: "gearshape")
            }
            .labelStyle(.iconOnly)
            .help(String(localized: "sidebar.toolbar.settings.help"))
        }
    }
}

// MARK: - Global Download Bar (single compact progress area)

private struct GlobalDownloadBar: View {
    @ObservedObject var viewModel: IPSWViewModel
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: viewModel.globalProgressFraction)
                .progressViewStyle(.linear)
                .tint(settings.selectedTheme.accentColor)
                .accessibilityValue(Text("\(Int(viewModel.globalProgressFraction * 100))%"))

            HStack(spacing: 12) {
                Text(viewModel.globalProgressTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                if !viewModel.downloadStatsText.isEmpty {
                    Text(viewModel.downloadStatsText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }

                Spacer()

                Button {
                    if viewModel.hasActiveDownloads {
                        viewModel.pauseAllManagedDownloads()
                    } else {
                        viewModel.resumeAllPausedDownloads()
                    }
                } label: {
                    Label(
                        viewModel.hasActiveDownloads
                            ? String(localized: "download.pause_all")
                            : String(localized: "download.resume_all"),
                        systemImage: viewModel.hasActiveDownloads ? "pause.fill" : "play.fill"
                    )
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!viewModel.hasActiveDownloads && !viewModel.hasPausedDownloads)
                .help(viewModel.hasActiveDownloads ? String(localized: "download.pause_all") : String(localized: "download.resume_all"))

                Button(role: .destructive) {
                    viewModel.cancelAllManagedDownloads()
                } label: {
                    Label(String(localized: "download.cancel_all"), systemImage: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help(String(localized: "download.cancel_all"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .liquidGlass(cornerRadius: 0)
        .background(settings.selectedTheme.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.05))
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(.separator), alignment: .bottom)
    }
}

// MARK: - Update Banner

private struct UpdateBanner: View {
    @ObservedObject var viewModel: IPSWViewModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "updates.banner.title"))
                    .font(.caption.weight(.semibold))
                Text(String(format: String(localized: "updates.banner.message"), viewModel.firmwareUpdatesAvailable.count))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(String(localized: "updates.banner.download")) {
                viewModel.downloadFirmwareUpdates()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            Button {
                viewModel.dismissUpdateBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .liquidGlass(cornerRadius: 0)
        .background(Color.orange.opacity(0.08))
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(.separator), alignment: .bottom)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var viewModel: IPSWViewModel
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField(String(localized: "search.placeholder"), text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .liquidGlass(cornerRadius: 8)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Sort + count in one row
            HStack(spacing: 6) {
                Picker(String(localized: "sidebar.sort.label"), selection: $viewModel.sortOption) {
                    ForEach(SidebarSortOption.allCases) { option in
                        Text(option.localizedTitle).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)

                Button {
                    viewModel.sortAscending.toggle()
                } label: {
                    Image(systemName: viewModel.sortAscending ? "arrow.up" : "arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "sidebar.sort.order"))

                Spacer()

                Text(viewModel.deviceCountLabel)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)

            // Filter chips
            if !viewModel.availableDeviceTypeFilters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        FilterChip(
                            label: String(localized: "filter.all"),
                            symbol: "square.grid.2x2",
                            isActive: viewModel.activeDeviceTypeFilter == nil
                        ) {
                            viewModel.activeDeviceTypeFilter = nil
                        }
                        ForEach(viewModel.availableDeviceTypeFilters, id: \.id) { filter in
                            FilterChip(
                                label: filter.label,
                                symbol: filter.symbol,
                                isActive: viewModel.activeDeviceTypeFilter == filter.id
                            ) {
                                viewModel.activeDeviceTypeFilter = viewModel.activeDeviceTypeFilter == filter.id ? nil : filter.id
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.vertical, 2)
            }

            Divider().padding(.horizontal, 8)

            // Device List
            deviceListContent

            Divider().padding(.horizontal, 8)

            // Bottom toolbar
            HStack(spacing: 6) {
                if viewModel.hasSelection {
                    Text(String(format: String(localized: "sidebar.selection_badge"), viewModel.selectedDeviceIDs.count))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    viewModel.invertSelection()
                } label: {
                    Image(systemName: "arrow.triangle.swap")
                }
                .buttonStyle(.plain)
                .help(String(localized: "sidebar.invert_selection.help"))

                Button {
                    if viewModel.hasSelection { viewModel.deselectAll() } else { viewModel.selectAll() }
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
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
        .navigationTitle(String(localized: "sidebar.nav_title"))
        .alert(String(localized: "sidebar.template.error_title"), isPresented: Binding(
            get: { viewModel.templateError != nil },
            set: { if !$0 { viewModel.templateError = nil } }
        )) {
            Button("OK") { viewModel.templateError = nil }
        } message: {
            Text(viewModel.templateError ?? "")
        }
    }

    @ViewBuilder
    private var deviceListContent: some View {
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
        } else if viewModel.filteredDevices.isEmpty && !viewModel.searchText.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(String(localized: "search.no_results"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Button(String(localized: "search.clear")) {
                    viewModel.searchText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            Spacer()
        } else if viewModel.filteredDevices.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(String(localized: "search.empty_list"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if viewModel.activeDeviceTypeFilter != nil {
                        Button(String(localized: "filter.all")) {
                            viewModel.activeDeviceTypeFilter = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Button(String(localized: "sidebar.retry")) {
                        Task { await viewModel.loadDevices() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(viewModel.isLoadingDevices)
                }
            }
            .padding()
            Spacer()
        } else {
            List(viewModel.filteredDevices) { device in
                DeviceRowView(device: device, viewModel: viewModel)
                    .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
            }
            .listStyle(.sidebar)
            .animation(.default, value: viewModel.filteredDevices.map(\.identifier))
            .onKeyPress(.return) {
                if viewModel.hasSelection {
                    viewModel.downloadSelectedDevices()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(characters: .init(charactersIn: "a")) { event in
                if event.modifiers.contains(.command) {
                    viewModel.selectAll()
                    return .handled
                }
                return .ignored
            }
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
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                .font(.callout)

            ZStack(alignment: .bottomTrailing) {
                Image(systemName: device.symbolName)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                if case .downloading = state {
                    Circle().fill(.blue).frame(width: 6, height: 6).offset(x: 3, y: 3)
                } else if case .queued = state {
                    Circle().fill(.orange).frame(width: 6, height: 6).offset(x: 3, y: 3)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(device.identifier)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let version = viewModel.deviceSortMetadata[device.identifier]?.latestFirmwareVersion {
                        Text("\u{2022}")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                        Text("\(device.osLabel) \(version)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            stateIndicator
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if !viewModel.isSelected(device) {
                viewModel.toggleSelection(device: device)
            }
            Task { await viewModel.startDownload(for: device) }
        }
        .onTapGesture(count: 1) {
            let shiftHeld = NSEvent.modifierFlags.contains(.shift)
            viewModel.handleClick(on: device, shiftHeld: shiftHeld)
        }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(device.identifier, forType: .string)
            } label: {
                Label(String(localized: "context.copy_identifier"), systemImage: "doc.on.doc")
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(device.name, forType: .string)
            } label: {
                Label(String(localized: "context.copy_name"), systemImage: "doc.on.doc.fill")
            }
            Divider()
            Button {
                viewModel.toggleSelection(device: device)
            } label: {
                if isSelected {
                    Label(String(localized: "context.deselect"), systemImage: "minus.circle")
                } else {
                    Label(String(localized: "context.select"), systemImage: "plus.circle")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(deviceAccessibilityLabel)
    }

    private var deviceAccessibilityLabel: String {
        var parts = [device.name, device.identifier]
        if isSelected { parts.append(String(localized: "accessibility.selected")) }
        switch state {
        case .downloading(let p): parts.append(String(format: String(localized: "accessibility.downloading"), Int(p * 100)))
        case .queued: parts.append(String(localized: "download.queued"))
        case .paused: parts.append(String(localized: "download.paused"))
        case .verifying: parts.append(String(localized: "download.verifying"))
        case .completed: parts.append(String(localized: "download.completed"))
        case .failed: parts.append(String(localized: "detail.section.failed"))
        case .idle: break
        }
        return parts.joined(separator: ", ")
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
                Image(systemName: "pause.circle.fill").foregroundStyle(.orange).font(.caption2)
                Text(String(localized: "download.paused")).font(.caption2).foregroundStyle(.secondary)
            }
        case .downloading(let progress):
            HStack(spacing: 5) {
                ProgressView(value: progress).frame(width: 54)
                Text("\(Int(progress * 100))%")
                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        case .verifying:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("SHA1\u{2026}").font(.caption2).foregroundStyle(.secondary)
            }
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.caption)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red).font(.caption)
        }
    }
}

// MARK: - Detail View

struct DetailView: View {
    @ObservedObject var viewModel: IPSWViewModel
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isActivityCollapsed = true

    private var managedDevices: [IPSWDevice] { viewModel.managedDownloadDevices }

    private var activeDevices: [IPSWDevice] {
        managedDevices.filter { device in
            switch viewModel.downloadState(for: device) {
            case .queued, .downloading, .verifying: return true
            default: return false
            }
        }
    }

    private var pausedDevices: [IPSWDevice] {
        managedDevices.filter { if case .paused = viewModel.downloadState(for: $0) { return true }; return false }
    }

    private var readyDevices: [IPSWDevice] {
        viewModel.orderedSelectedDevices.filter { if case .idle = viewModel.downloadState(for: $0) { return true }; return false }
    }

    private var completedDevices: [IPSWDevice] {
        viewModel.orderedSelectedDevices.filter { if case .completed = viewModel.downloadState(for: $0) { return true }; return false }
    }

    private var failedDevices: [IPSWDevice] {
        viewModel.orderedSelectedDevices.filter { if case .failed = viewModel.downloadState(for: $0) { return true }; return false }
    }

    private var recentActivityEntries: [ActivityLogEntry] {
        guard !viewModel.selectedDeviceIDs.isEmpty else { return viewModel.recentActivityEntries }
        return viewModel.recentActivityEntries.filter { entry in
            guard let id = entry.deviceIdentifier else { return true }
            return viewModel.selectedDeviceIDs.contains(id)
        }
    }

    private var isShowingEmptyState: Bool {
        viewModel.selectedDeviceIDs.isEmpty && managedDevices.isEmpty && viewModel.downloadedFirmware.isEmpty
    }

    var body: some View {
        if isShowingEmptyState {
            VStack(spacing: 0) {
                emptyStateView

                if !recentActivityEntries.isEmpty {
                    Divider()
                    List {
                        ActivitySectionList(entries: recentActivityEntries, isCollapsed: $isActivityCollapsed) {
                            viewModel.clearActivityLog()
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                // Dashboard stats
                if managedDevices.count + completedDevices.count + failedDevices.count > 0 {
                    Section {
                        HStack(spacing: 8) {
                            if !activeDevices.isEmpty {
                                SummaryChip(title: String(localized: "detail.section.active"), count: activeDevices.count, color: .blue)
                            }
                            if !pausedDevices.isEmpty {
                                SummaryChip(title: String(localized: "detail.section.paused"), count: pausedDevices.count, color: .orange)
                            }
                            if !readyDevices.isEmpty {
                                SummaryChip(title: String(localized: "detail.section.ready"), count: readyDevices.count, color: .secondary)
                            }
                            if !completedDevices.isEmpty {
                                SummaryChip(title: String(localized: "download.completed"), count: completedDevices.count, color: .green)
                            }
                            if !failedDevices.isEmpty {
                                SummaryChip(title: String(localized: "detail.section.failed"), count: failedDevices.count, color: .red)
                            }
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }

                // Active + Paused downloads (merged)
                if !activeDevices.isEmpty || !pausedDevices.isEmpty {
                    Section {
                        ForEach(activeDevices + pausedDevices) { device in
                            DownloadTaskCard(device: device, viewModel: viewModel)
                                .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    } header: {
                        HStack {
                            Text(String(localized: "detail.section.managed"))
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                            Spacer()
                            SummaryChip(title: String(localized: "detail.section.active"), count: activeDevices.count, color: .blue)
                            if !pausedDevices.isEmpty {
                                SummaryChip(title: String(localized: "detail.section.paused"), count: pausedDevices.count, color: .orange)
                            }
                        }
                    }
                }

                DownloadSectionList(title: String(localized: "detail.section.ready"), devices: readyDevices, viewModel: viewModel, showRetryAll: false, showClearCompleted: false)
                DownloadSectionList(title: String(localized: "detail.section.completed"), devices: completedDevices, viewModel: viewModel, showRetryAll: false, showClearCompleted: true)
                DownloadSectionList(title: String(localized: "detail.section.failed"), devices: failedDevices, viewModel: viewModel, showRetryAll: true, showClearCompleted: false)
                LocalFirmwareSectionList(records: viewModel.downloadedFirmware, viewModel: viewModel)
                ActivitySectionList(entries: recentActivityEntries, isCollapsed: $isActivityCollapsed) {
                    viewModel.clearActivityLog()
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .navigationTitle(String(localized: "detail.navigation.title"))
        }
    }

    // MARK: Empty State

    @State private var emptyStateFloating = false

    private var emptyStateView: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                settings.selectedTheme.tintColor.opacity(0.18),
                                settings.selectedTheme.accentColor.opacity(0.06),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 10)

                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [settings.selectedTheme.tintColor, settings.selectedTheme.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .modifier(SymbolPulseEffectIfAvailable())
                    .offset(y: emptyStateFloating ? -4 : 4)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: emptyStateFloating)
            }

            Text(String(localized: "detail.empty"))
                .font(.system(.title3, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: "1", text: String(localized: "detail.empty.step1"))
                instructionRow(number: "2", text: String(localized: "detail.empty.step2"))
                instructionRow(number: "3", text: String(localized: "detail.empty.step3"))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { emptyStateFloating = true }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Download Section List

private struct DownloadSectionList: View {
    let title: String
    let devices: [IPSWDevice]
    @ObservedObject var viewModel: IPSWViewModel
    var showRetryAll: Bool = false
    var showClearCompleted: Bool = false
    @State private var devicePendingCancel: IPSWDevice?
    @State private var devicePendingRemoval: IPSWDevice?

    var body: some View {
        if !devices.isEmpty {
            Section {
                ForEach(devices) { device in
                    DownloadTaskCard(device: device, viewModel: viewModel)
                        .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                        .listRowSeparator(.hidden)
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
                                    devicePendingCancel = device
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
                                    devicePendingCancel = device
                                } label: {
                                    Label(String(localized: "download.cancel"), systemImage: "stop.circle")
                                }
                            default:
                                EmptyView()
                            }
                            Divider()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(device.identifier, forType: .string)
                            } label: {
                                Label(String(localized: "context.copy_identifier"), systemImage: "doc.on.doc")
                            }
                            if let url = viewModel.downloadTasks[device.identifier]?.firmware.downloadURL?.absoluteString {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url, forType: .string)
                                } label: {
                                    Label(String(localized: "context.copy_download_url"), systemImage: "link")
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                devicePendingRemoval = device
                            } label: {
                                Label(String(localized: "download.remove"), systemImage: "trash")
                            }
                        }
                }
            } header: {
                HStack {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                    Spacer()
                    if showRetryAll && viewModel.hasFailedDownloads {
                        Button(String(localized: "download.retry_all")) {
                            viewModel.retryAllFailed()
                        }
                        .font(.caption2)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.blue)
                    }
                    if showClearCompleted && viewModel.hasCompletedDownloads {
                        Button(String(localized: "download.clear_completed")) {
                            viewModel.clearCompletedDownloads()
                        }
                        .font(.caption2)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .confirmationDialog(
                String(localized: "confirm.cancel_download.title"),
                isPresented: Binding(get: { devicePendingCancel != nil }, set: { if !$0 { devicePendingCancel = nil } }),
                titleVisibility: .visible
            ) {
                Button(String(localized: "confirm.cancel_download.action"), role: .destructive) {
                    if let device = devicePendingCancel { viewModel.cancelDownload(for: device) }
                    devicePendingCancel = nil
                }
            } message: {
                Text(String(localized: "confirm.cancel_download.message"))
            }
            .confirmationDialog(
                String(localized: "confirm.remove_device.title"),
                isPresented: Binding(get: { devicePendingRemoval != nil }, set: { if !$0 { devicePendingRemoval = nil } }),
                titleVisibility: .visible
            ) {
                Button(String(localized: "confirm.remove_device.action"), role: .destructive) {
                    if let device = devicePendingRemoval { viewModel.removeDevice(device) }
                    devicePendingRemoval = nil
                }
            } message: {
                Text(String(localized: "confirm.remove_device.message"))
            }
        }
    }
}

// MARK: - Local Firmware Section

private struct LocalFirmwareSectionList: View {
    let records: [LocalFirmwareRecord]
    @ObservedObject var viewModel: IPSWViewModel

    var body: some View {
        if !records.isEmpty {
            Section {
                ForEach(records) { record in
                    HStack(spacing: 10) {
                        Image(systemName: "externaldrive.fill")
                            .foregroundStyle(.mint)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.title)
                                .font(.subheadline.weight(.semibold))
                            Text(record.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(record.fileName)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(record.sizeText)
                                .font(.caption.weight(.medium))
                            if let modifiedAt = record.modifiedAt {
                                Text(modifiedAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Button(String(localized: "download.show_in_finder")) {
                                viewModel.revealInFinder(record.location)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(Color.clear)
                    .contextMenu {
                        Button {
                            viewModel.revealInFinder(record.location)
                        } label: {
                            Label(String(localized: "download.show_in_finder"), systemImage: "folder")
                        }
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(record.location.path, forType: .string)
                        } label: {
                            Label(String(localized: "context.copy_path"), systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(role: .destructive) {
                            try? FileManager.default.trashItem(at: record.location, resultingItemURL: nil)
                        } label: {
                            Label(String(localized: "context.move_to_trash"), systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text(String(localized: "detail.section.local"))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
            }
        }
    }
}

// MARK: - Activity Section

private struct ActivitySectionList: View {
    let entries: [ActivityLogEntry]
    @Binding var isCollapsed: Bool
    var onClear: (() -> Void)? = nil

    var body: some View {
        if !entries.isEmpty {
            Section {
                if !isCollapsed {
                    ForEach(entries) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: entry.kind.systemImage)
                                .foregroundStyle(color(for: entry.kind))
                                .frame(width: 14, alignment: .center)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text(entry.title)
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                    Text(entry.timestamp, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
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
                        .padding(.vertical, 1)
                        .listRowBackground(Color.clear)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .contextMenu {
                            Button {
                                let text = "[\(entry.timestamp.formatted(date: .abbreviated, time: .shortened))] \(entry.title): \(entry.message)"
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                            } label: {
                                Label(String(localized: "activity.copy_entry"), systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            } header: {
                HStack(spacing: 5) {
                    Button {
                        withAnimation { isCollapsed.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                                .animation(.easeInOut(duration: 0.2), value: isCollapsed)
                            Text(String(localized: "detail.section.activity"))
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                            Text("(\(entries.count))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if let onClear, !isCollapsed {
                        Button(String(localized: "activity.clear")) {
                            onClear()
                        }
                        .font(.caption2)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func color(for kind: ActivityLogKind) -> Color {
        switch kind {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Download Task Card

struct DownloadTaskCard: View {
    let device: IPSWDevice
    @ObservedObject var viewModel: IPSWViewModel
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    private var state: DownloadState { viewModel.downloadState(for: device) }
    private var task: DeviceDownloadTask? { viewModel.downloadTasks[device.identifier] }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(stateAccentColor)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: device.symbolName)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(device.name)
                            .font(.callout.weight(.semibold))
                        Text(device.identifier)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    statusBadge
                    actionButton
                }

                if let fw = task?.firmware, fw.buildid != "pending" {
                    HStack(spacing: 5) {
                        Text("\(device.osLabel) \(fw.version) (\(fw.buildid))")
                        Text("\u{2022}")
                        Text(fw.filesizeMB)
                        if fw.signed {
                            Text("\u{2022}")
                            Text(String(localized: "download.signed"))
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                stateContent
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
        }
        .background(cardBackground)
        .liquidGlassCard(theme: settings.selectedTheme, colorScheme: colorScheme, cornerRadius: 8)
        .shadow(color: activeGlowColor, radius: isActiveState ? 8 : 0, y: 0)
        .animation(.easeInOut(duration: 0.25), value: stateKey)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    @ViewBuilder
    private var stateContent: some View {
        switch state {
        case .queued:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(String(localized: "download.queued"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .paused:
            HStack(spacing: 6) {
                Image(systemName: "pause.circle.fill").foregroundStyle(.orange)
                Text(String(localized: "download.paused"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .verifying:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(String(localized: "download.verifying"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 2) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .animation(.linear(duration: 0.5), value: progress)
                    .accessibilityValue(Text("\(Int(progress * 100))%"))
                HStack {
                    if let details = task?.progressDetails {
                        Text(details.transferredText).monospacedDigit()
                        Spacer()
                        Text(details.speedText).fontWeight(.medium).monospacedDigit()
                        if !details.etaText.isEmpty {
                            Text("\u{2022}").foregroundStyle(.tertiary)
                            Text(String(format: String(localized: "download.eta"), details.etaText)).monospacedDigit()
                        }
                    } else {
                        Text("\(Int(progress * 100))%").monospacedDigit()
                        Spacer()
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        case .completed(let url):
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .modifier(SymbolBounceEffectIfAvailable())
                Text(String(localized: "download.completed")).foregroundStyle(.green)
                Spacer()
                Button(String(localized: "download.show_in_finder")) {
                    viewModel.revealInFinder(url)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .font(.caption)
        case .failed(let error):
            HStack {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text(error).foregroundStyle(.red).lineLimit(2)
            }
            .font(.caption)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .idle, .failed:
            Button {
                Task { await viewModel.startDownload(for: device) }
            } label: {
                Label(String(localized: "download.action.download"), systemImage: "arrow.down.circle")
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 110)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .accessibilityHint(String(localized: "accessibility.hint.download"))
        case .queued, .downloading:
            Button {
                viewModel.pauseDownload(for: device)
            } label: {
                Label(String(localized: "download.action.pause"), systemImage: "pause.circle")
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(.orange)
            .accessibilityHint(String(localized: "accessibility.hint.pause"))
        case .paused:
            Button {
                viewModel.resumeDownload(for: device)
            } label: {
                Label(String(localized: "download.action.resume"), systemImage: "play.circle")
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 110)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .accessibilityHint(String(localized: "accessibility.hint.resume"))
        case .verifying:
            Button { } label: {
                Label(String(localized: "download.action.verifying"), systemImage: "checkmark.shield")
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(true)
        case .completed:
            Button {
                Task { await viewModel.startDownload(for: device) }
            } label: {
                Label(String(localized: "download.action.redownload"), systemImage: "arrow.clockwise.circle")
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch state {
        case .idle: EmptyView()
        case .queued: badge(String(localized: "download.queued"), color: .orange)
        case .paused: badge(String(localized: "download.paused"), color: .orange)
        case .downloading: badge(String(localized: "download.in_progress"), color: .blue)
        case .verifying: badge(String(localized: "download.verifying"), color: .mint)
        case .completed: badge(String(localized: "download.completed"), color: .green)
        case .failed: badge(String(localized: "detail.section.failed"), color: .red)
        }
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .transition(.scale.combined(with: .opacity))
    }

    private var stateKey: String {
        switch state {
        case .idle: return "idle"
        case .queued: return "queued"
        case .paused: return "paused"
        case .downloading: return "downloading"
        case .verifying: return "verifying"
        case .completed: return "completed"
        case .failed: return "failed"
        }
    }

    private var stateAccentColor: Color {
        switch state {
        case .idle: return .clear
        case .queued, .paused: return .orange
        case .downloading: return .blue
        case .verifying: return .mint
        case .completed: return .green
        case .failed: return .red
        }
    }

    private var cardBackground: Color {
        switch state {
        case .completed: return .green.opacity(0.03)
        case .failed: return .red.opacity(0.04)
        case .paused: return .orange.opacity(0.04)
        case .downloading, .queued, .verifying: return .blue.opacity(0.03)
        case .idle: return Color(NSColor.windowBackgroundColor)
        }
    }

    private var cardBorder: Color {
        switch state {
        case .completed: return .green.opacity(0.15)
        case .failed: return .red.opacity(0.15)
        case .paused: return .orange.opacity(0.15)
        case .downloading, .queued, .verifying: return .blue.opacity(0.12)
        case .idle: return .primary.opacity(0.06)
        }
    }

    private var isActiveState: Bool {
        switch state {
        case .downloading, .queued, .verifying: return true
        default: return false
        }
    }

    private var activeGlowColor: Color {
        switch state {
        case .downloading, .queued, .verifying: return stateAccentColor.opacity(colorScheme == .dark ? 0.25 : 0.12)
        case .completed: return .green.opacity(colorScheme == .dark ? 0.15 : 0.08)
        default: return .clear
        }
    }

    private var cardAccessibilityLabel: String {
        var parts = [device.name]
        if let fw = task?.firmware, fw.buildid != "pending" {
            parts.append("\(device.osLabel) \(fw.version)")
        }
        switch state {
        case .downloading(let p): parts.append(String(format: String(localized: "accessibility.downloading"), Int(p * 100)))
        case .queued: parts.append(String(localized: "download.queued"))
        case .paused: parts.append(String(localized: "download.paused"))
        case .verifying: parts.append(String(localized: "download.verifying"))
        case .completed: parts.append(String(localized: "download.completed"))
        case .failed(let err): parts.append("\(String(localized: "detail.section.failed")): \(err)")
        case .idle: break
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Supporting Views

private struct SummaryChip: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .modifier(NumericTextTransitionIfAvailable())
            Text(title)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }
}

private struct FilterChip: View {
    let label: String
    let symbol: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 9))
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .liquidGlass(cornerRadius: 20)
            .background(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct NumericTextTransitionIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if AppCompatibility.usesLegacySwiftUIWorkarounds {
            content
        } else {
            content.contentTransition(.numericText())
        }
    }
}

private struct SymbolPulseEffectIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.symbolEffect(.pulse, options: .repeating)
        } else {
            content
        }
    }
}

private struct SymbolBounceEffectIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.symbolEffect(.bounce, options: .nonRepeating)
        } else {
            content
        }
    }
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in configureWindow(for: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in configureWindow(for: nsView) }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window else { return }
        if #available(macOS 26.0, *) {
            window.toolbarStyle = .unified
            window.titlebarSeparatorStyle = .automatic
        } else {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView(viewModel: IPSWViewModel())
}
