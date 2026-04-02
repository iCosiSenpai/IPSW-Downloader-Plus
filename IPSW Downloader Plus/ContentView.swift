//
//  ContentView.swift
//  IPSW Downloader Plus
//

import SwiftUI
import AppKit

// MARK: - Root View

struct ContentView: View {
    @ObservedObject var viewModel: IPSWViewModel
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemeCanvasBackground(theme: settings.selectedTheme)

            VStack(spacing: 0) {
                dashboardHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    navigationContainer
                    footerLinks
                }
                .themePanelBackground(theme: settings.selectedTheme, colorScheme: colorScheme, cornerRadius: 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(settings.selectedTheme.surfaceColor(for: colorScheme).opacity(0.6))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 16, y: 8)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(minWidth: 980, minHeight: 600)
        .navigationTitle(String(localized: "sidebar.nav_title"))
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
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 480)
                DetailView(viewModel: viewModel)
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Dashboard Header

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "dashboard.eyebrow"))
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(settings.selectedTheme.accentColor)
                        .textCase(.uppercase)
                    Text(String(localized: "dashboard.title"))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text(headerSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    DashboardMetricCard(
                        title: String(localized: "dashboard.metric.devices"),
                        value: "\(viewModel.filteredDevices.count)",
                        tint: settings.selectedTheme.tintColor
                    )
                    DashboardMetricCard(
                        title: String(localized: "dashboard.metric.selected"),
                        value: "\(viewModel.selectedDeviceIDs.count)",
                        tint: settings.selectedTheme.accentColor
                    )
                    DashboardMetricCard(
                        title: String(localized: "dashboard.metric.active"),
                        value: "\(activeDownloadCount)",
                        tint: .orange
                    )
                }
            }

            HStack(spacing: 8) {
                dashboardActionButton(
                    title: String(localized: "dashboard.action.download"),
                    systemImage: "arrow.down.circle.fill",
                    prominent: true,
                    isDisabled: !viewModel.hasSelection
                ) {
                    viewModel.downloadSelectedDevices()
                }
                headerBadge(title: String(localized: "dashboard.badge.sort"), value: viewModel.activeSortSummary)
                headerBadge(title: String(localized: "dashboard.badge.theme"), value: settings.selectedTheme.localizedTitle)

                Spacer()
            }

            if viewModel.hasActiveDownloads {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: viewModel.globalProgressFraction)
                        .progressViewStyle(.linear)
                        .tint(settings.selectedTheme.accentColor)
                    HStack {
                        Text(viewModel.globalProgressTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !viewModel.downloadStatsText.isEmpty {
                            Text(viewModel.downloadStatsText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(settings.selectedTheme.accentColor.opacity(colorScheme == .dark ? 0.10 : 0.06))
                )
            }
        }
        .padding(14)
        .themePanelBackground(theme: settings.selectedTheme, colorScheme: colorScheme, cornerRadius: 18)
        .background(settings.selectedTheme.heroGradient(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))
    }

    private func headerBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(settings.selectedTheme.secondarySurfaceColor(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
    }

    private func dashboardActionButton(title: String, systemImage: String, prominent: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 4)
                .frame(minHeight: 34)
        }
        .modifier(DashboardActionButtonStyle(prominent: prominent))
        .controlSize(.regular)
        .disabled(isDisabled)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 14) {
            Link(destination: AppLinks.support) {
                HStack(spacing: 6) {
                    Text("PayPal")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.38, blue: 0.75), Color(red: 0.0, green: 0.62, blue: 0.89)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                    Text(String(localized: "footer.donate"))
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Link(destination: AppLinks.github) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                    Text(String(localized: "footer.made_with"))
                        .font(.caption)
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(String(localized: "footer.by_author"))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(.separator), alignment: .top)
    }

    // MARK: - Helpers

    private var headerSummary: String {
        if viewModel.isLoadingDevices {
            return String(localized: "dashboard.summary.loading")
        }
        if let error = viewModel.deviceLoadError, !error.isEmpty {
            return error
        }
        if viewModel.hasActiveDownloads, !viewModel.downloadStatsText.isEmpty {
            return viewModel.downloadStatsText
        }
        return String(format: String(localized: "dashboard.summary.ready"), viewModel.filteredDevices.count)
    }

    private var activeDownloadCount: Int {
        viewModel.downloadTasks.values.filter { task in
            switch task.state {
            case .queued, .downloading, .verifying: return true
            default: return false
            }
        }.count
    }
}

private struct DashboardActionButtonStyle: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .modifier(NumericTextTransitionIfAvailable())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 80, alignment: .leading)
        .themeMetricCardBackground(tint: tint, cornerRadius: 12)
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
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
    }
}

// MARK: - Sidebar (Device List)

struct SidebarView: View {
    @ObservedObject var viewModel: IPSWViewModel
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            sidebarUtilityBar
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 6)

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
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(settings.selectedTheme.secondarySurfaceColor(for: colorScheme))
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            // Sort + count
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
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(settings.selectedTheme.secondarySurfaceColor(for: colorScheme))
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            // Filter chips
            if !viewModel.availableDeviceTypeFilters.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 5) {
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
                                if viewModel.activeDeviceTypeFilter == filter.id {
                                    viewModel.activeDeviceTypeFilter = nil
                                } else {
                                    viewModel.activeDeviceTypeFilter = filter.id
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .scrollIndicators(.hidden)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }

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
            } else if viewModel.filteredDevices.isEmpty && !viewModel.searchText.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "search.no_results"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "search.no_results.hint"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
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
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "search.empty_list"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(emptySidebarHint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
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
                        .listRowInsets(EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6))
                }
                .listStyle(.sidebar)
                .animation(.default, value: viewModel.filteredDevices.map(\.identifier))
            }

            Divider()

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
                .accessibilityLabel(String(localized: "sidebar.invert_selection.help"))
                .help(String(localized: "sidebar.invert_selection.help"))

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
                .accessibilityLabel(viewModel.hasSelection
                      ? String(localized: "sidebar.deselect_all.help")
                      : String(localized: "sidebar.select_all.help"))
                .help(viewModel.hasSelection
                      ? String(localized: "sidebar.deselect_all.help")
                      : String(localized: "sidebar.select_all.help"))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(settings.selectedTheme.secondarySurfaceColor(for: colorScheme))
            )
            .padding(8)
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 480)
        .navigationTitle(String(localized: "sidebar.nav_title"))
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    Task { await viewModel.loadDevices() }
                } label: {
                    Label(String(localized: "sidebar.refresh.help"), systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel.isLoadingDevices)
                .help(String(localized: "sidebar.refresh.help"))

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
        .alert(String(localized: "sidebar.template.error_title"), isPresented: Binding(
            get: { viewModel.templateError != nil },
            set: { if !$0 { viewModel.templateError = nil } }
        )) {
            Button("OK") { viewModel.templateError = nil }
        } message: {
            Text(viewModel.templateError ?? "")
        }
    }

    private var sidebarUtilityBar: some View {
        HStack(spacing: 6) {
            Text(String(localized: "sidebar.nav_title"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

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
                HStack(spacing: 4) {
                    if viewModel.isApplyingLatestIOSTemplate {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.caption)
                    }
                    Text(String(localized: "sidebar.toolbar.template"))
                        .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(settings.selectedTheme.secondarySurfaceColor(for: colorScheme))
                )
                .overlay(
                    Capsule()
                        .stroke(settings.selectedTheme.borderColor(for: colorScheme), lineWidth: 0.5)
                )
            }
            .menuStyle(.borderlessButton)
            .help(String(localized: "sidebar.toolbar.template.help"))
        }
        .padding(.horizontal, 2)
    }

    private var emptySidebarHint: String {
        if viewModel.activeDeviceTypeFilter != nil {
            return viewModel.activeSortSummary
        }
        if viewModel.isLoadingDevices {
            return String(localized: "dashboard.summary.loading")
        }
        return viewModel.deviceCountLabel
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
                Text(device.identifier)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
    @State private var isActivityCollapsed = false

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

    private var headerStatusLine: String {
        String(format: String(localized: "detail.header.status"),
               readyDevices.count, activeDevices.count, completedDevices.count, failedDevices.count)
    }

    private var isShowingEmptyState: Bool {
        viewModel.selectedDeviceIDs.isEmpty && managedDevices.isEmpty && viewModel.downloadedFirmware.isEmpty
    }

    private var primaryControlTitle: String {
        viewModel.hasActiveDownloads ? String(localized: "download.pause_all") : String(localized: "download.resume_all")
    }

    private var primaryControlSystemImage: String {
        viewModel.hasActiveDownloads ? "pause.fill" : "play.fill"
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
                    .background(Color(NSColor.controlBackgroundColor))
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // Detail header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: String(localized: "detail.header.selected"), viewModel.selectedDeviceIDs.count))
                                .font(.subheadline.weight(.semibold))
                            Text(headerStatusLine)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let estimated = viewModel.estimatedTotalDownloadSize {
                                Text(estimated)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: 6) {
                        SummaryChip(title: String(localized: "detail.section.managed"), count: managedDevices.count, color: .blue)
                        SummaryChip(title: String(localized: "detail.section.paused"), count: pausedDevices.count, color: .orange)
                        SummaryChip(title: String(localized: "detail.section.failed"), count: failedDevices.count, color: .red)
                    }

                    if !managedDevices.isEmpty {
                        controlCenterPanel
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(settings.selectedTheme.secondarySurfaceColor(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(settings.selectedTheme.borderColor(for: colorScheme), lineWidth: 0.5)
                )
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 4)

                List {
                    ManagedDownloadsSectionList(
                        title: String(localized: "detail.section.managed"),
                        activeDevices: activeDevices,
                        pausedDevices: pausedDevices,
                        viewModel: viewModel
                    )
                    DownloadSectionList(title: String(localized: "detail.section.ready"), devices: readyDevices, viewModel: viewModel, allowsManagedSelection: false)
                    DownloadSectionList(title: String(localized: "detail.section.completed"), devices: completedDevices, viewModel: viewModel, allowsManagedSelection: false, showClearCompleted: true)
                    DownloadSectionList(title: String(localized: "detail.section.failed"), devices: failedDevices, viewModel: viewModel, allowsManagedSelection: false, showRetryAll: true)
                    LocalFirmwareSectionList(records: viewModel.downloadedFirmware, viewModel: viewModel)
                    ActivitySectionList(entries: recentActivityEntries, isCollapsed: $isActivityCollapsed) {
                        viewModel.clearActivityLog()
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.controlBackgroundColor))
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: 0)
                }
            }
            .navigationTitle(String(localized: "detail.navigation.title"))
        }
    }

    // MARK: Empty State

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [settings.selectedTheme.tintColor, settings.selectedTheme.accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(String(localized: "detail.empty"))
                .font(.system(.title3, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: "1", text: String(localized: "detail.empty.step1"))
                instructionRow(number: "2", text: String(localized: "detail.empty.step2"))
                instructionRow(number: "3", text: String(localized: "detail.empty.step3"))
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: Control Center

    private var controlCenterPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "menu.downloads"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.globalProgressTitle)
                        .font(.subheadline.weight(.bold))
                }
                Spacer()
                if !viewModel.downloadStatsText.isEmpty {
                    Text(viewModel.downloadStatsText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            ProgressView(value: viewModel.globalProgressFraction)
                .progressViewStyle(.linear)
                .tint(settings.selectedTheme.accentColor)

            HStack(spacing: 8) {
                Button {
                    if viewModel.hasActiveDownloads {
                        viewModel.pauseAllManagedDownloads()
                    } else {
                        viewModel.resumeAllPausedDownloads()
                    }
                } label: {
                    Label(primaryControlTitle, systemImage: primaryControlSystemImage)
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!viewModel.hasActiveDownloads && !viewModel.hasPausedDownloads)

                Button {
                    viewModel.resumeAllPausedDownloads()
                } label: {
                    Label(String(localized: "download.resume_all"), systemImage: "play.circle.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!viewModel.hasPausedDownloads)

                Button(role: .destructive) {
                    viewModel.cancelAllManagedDownloads()
                } label: {
                    Label(String(localized: "download.cancel_all"), systemImage: "stop.circle.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(settings.selectedTheme.windowBackgroundColor(for: colorScheme).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(settings.selectedTheme.borderColor(for: colorScheme), lineWidth: 0.5)
        )
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
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
                        .padding(.vertical, 2)
                        .listRowBackground(Color.clear)
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
                            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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

// MARK: - Summary Chip

private struct SummaryChip: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .modifier(NumericTextTransitionIfAvailable())
            Text(title)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
        .accessibilityLabel("\(count) \(title)")
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

// MARK: - Download Section Lists

private struct DownloadSectionList: View {
    let title: String
    let devices: [IPSWDevice]
    @ObservedObject var viewModel: IPSWViewModel
    let allowsManagedSelection: Bool
    var showRetryAll: Bool = false
    var showClearCompleted: Bool = false
    @State private var devicePendingCancel: IPSWDevice?
    @State private var devicePendingRemoval: IPSWDevice?

    var body: some View {
        if !devices.isEmpty {
            Section {
                ForEach(devices) { device in
                    DownloadTaskCard(device: device, viewModel: viewModel, allowsManagedSelection: allowsManagedSelection)
                        .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
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

private struct ManagedDownloadsSectionList: View {
    let title: String
    let activeDevices: [IPSWDevice]
    let pausedDevices: [IPSWDevice]
    @ObservedObject var viewModel: IPSWViewModel

    private var managedDevices: [IPSWDevice] { activeDevices + pausedDevices }

    var body: some View {
        if !managedDevices.isEmpty {
            Section {
                ForEach(managedDevices) { device in
                    DownloadTaskCard(device: device, viewModel: viewModel, allowsManagedSelection: false)
                        .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                        .listRowSeparator(.hidden)
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
                    .padding(.vertical, 3)
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

// MARK: - Download Task Card

struct DownloadTaskCard: View {
    let device: IPSWDevice
    @ObservedObject var viewModel: IPSWViewModel
    let allowsManagedSelection: Bool

    private var state: DownloadState { viewModel.downloadState(for: device) }
    private var task: DeviceDownloadTask? { viewModel.downloadTasks[device.identifier] }
    private var isManagedSelected: Bool { viewModel.isManagedDownloadSelected(device) }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent strip
            RoundedRectangle(cornerRadius: 2)
                .fill(stateAccentColor)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                // Header row
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

                // Firmware info
                if let fw = task?.firmware {
                    HStack(spacing: 5) {
                        Text("\(fw.version) (\(fw.buildid))")
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

                // State-specific content
                stateContent
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(cardBorder, lineWidth: 0.5)
        )
        .modifier(PulsingBorder(isActive: isDownloading))
        .animation(.easeInOut(duration: 0.3), value: stateKey)
        .help(cardTooltip)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    // MARK: State Content

    @ViewBuilder
    private var stateContent: some View {
        switch state {
        case .queued:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "download.queued"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let label = attemptLabel {
                    Text(label).font(.caption2).foregroundStyle(.tertiary)
                }
            }
        case .paused:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "pause.circle.fill").foregroundStyle(.orange)
                    Text(String(localized: "download.paused"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let label = attemptLabel {
                    Text(label).font(.caption2).foregroundStyle(.tertiary)
                }
            }
        case .verifying:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(String(localized: "download.verifying"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                HStack {
                    if let details = task?.progressDetails {
                        Text(details.transferredText)
                            .monospacedDigit()
                        Spacer()
                        Text(details.speedText)
                            .fontWeight(.medium)
                            .monospacedDigit()
                        if !details.etaText.isEmpty {
                            Text("\u{2022}")
                                .foregroundStyle(.tertiary)
                            Text(String(format: String(localized: "download.eta"), details.etaText))
                                .monospacedDigit()
                        }
                    } else {
                        Text(String(localized: "download.in_progress"))
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .monospacedDigit()
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        case .completed(let url):
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
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
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    Text(error).foregroundStyle(.red).lineLimit(2)
                }
                .font(.caption)
                if let label = attemptLabel {
                    Text(label).font(.caption2).foregroundStyle(.tertiary)
                }
            }
        case .idle:
            EmptyView()
        }
    }

    // MARK: Helpers

    private var isDownloading: Bool {
        if case .downloading = state { return true }
        return false
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
        case .queued: return .orange
        case .paused: return .orange
        case .downloading: return .blue
        case .verifying: return .mint
        case .completed: return .green
        case .failed: return .red
        }
    }

    private var cardTooltip: String {
        var parts = [device.name, device.identifier]
        if let fw = task?.firmware {
            parts.append("\(device.osLabel) \(fw.version) (\(fw.buildid))")
            parts.append(fw.filesizeMB)
        }
        return parts.joined(separator: " \u{2014} ")
    }

    private var cardAccessibilityLabel: String {
        var parts = [device.name, device.identifier]
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
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var attemptLabel: String? {
        guard let task, task.attemptCount > 0 else { return nil }
        return String(format: String(localized: "download.attempt"), task.attemptCount, 3)
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
}

// MARK: - Filter Chip

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
            .padding(.vertical, 4)
            .background(isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pulsing Border

private struct PulsingBorder: ViewModifier {
    let isActive: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.blue.opacity(pulse ? 0.5 : 0.12), lineWidth: 2)
                    .opacity(isActive ? 1 : 0)
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
                } else {
                    withAnimation { pulse = false }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ContentView(viewModel: IPSWViewModel())
}
