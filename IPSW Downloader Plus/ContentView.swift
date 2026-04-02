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

            VStack(spacing: 14) {
                contentHeader
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                VStack(spacing: 0) {
                    navigationContainer

                    footerLinks
                }
                .padding(8)
                .themePanelBackground(theme: settings.selectedTheme, colorScheme: colorScheme, cornerRadius: 24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(settings.selectedTheme.surfaceColor(for: colorScheme).opacity(0.72))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 18, y: 12)
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
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

    private var contentHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "dashboard.eyebrow"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(settings.selectedTheme.accentColor)
                        .textCase(.uppercase)
                    Text(String(localized: "dashboard.title"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(headerSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        DashboardMetricCard(title: String(localized: "dashboard.metric.devices"), value: "\(viewModel.filteredDevices.count)", tint: settings.selectedTheme.tintColor)
                        DashboardMetricCard(title: String(localized: "dashboard.metric.selected"), value: "\(viewModel.selectedDeviceIDs.count)", tint: settings.selectedTheme.accentColor)
                        DashboardMetricCard(title: String(localized: "dashboard.metric.active"), value: "\(activeDownloadCount)", tint: .orange)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
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
                }
            }

            if viewModel.hasActiveDownloads {
                VStack(alignment: .leading, spacing: 5) {
                    ProgressView(value: viewModel.globalProgressFraction)
                        .progressViewStyle(.linear)
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
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(settings.selectedTheme.secondarySurfaceColor(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .themePanelBackground(theme: settings.selectedTheme, colorScheme: colorScheme, cornerRadius: 22)
        .background(settings.selectedTheme.heroGradient(for: colorScheme), in: RoundedRectangle(cornerRadius: 22))
    }

    private func headerBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(settings.selectedTheme.secondarySurfaceColor(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    private func dashboardActionButton(title: String, systemImage: String, prominent: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 6)
                .frame(minHeight: 42)
        }
        .modifier(DashboardActionButtonStyle(prominent: prominent))
        .controlSize(.large)
        .disabled(isDisabled)
    }

    private var footerLinks: some View {
        HStack(spacing: 16) {
            Link(destination: AppLinks.support) {
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

            Link(destination: AppLinks.github) {
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
            case .queued, .downloading, .verifying:
                return true
            default:
                return false
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 104, alignment: .leading)
        .themeMetricCardBackground(tint: tint, cornerRadius: 16)
    }
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: nsView)
        }
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
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(settings.selectedTheme.secondarySurfaceColor(for: colorScheme))
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

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

                Text(viewModel.deviceCountLabel)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(settings.selectedTheme.secondarySurfaceColor(for: colorScheme))
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            // Device type filter chips
            if !viewModel.availableDeviceTypeFilters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
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
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
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
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
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
                }
                .padding()
                Spacer()
            } else if viewModel.filteredDevices.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "search.empty_list"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(emptySidebarHint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        if viewModel.activeDeviceTypeFilter != nil {
                            Button(String(localized: "filter.all")) {
                                viewModel.activeDeviceTypeFilter = nil
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(String(localized: "sidebar.retry")) {
                            Task { await viewModel.loadDevices() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoadingDevices)
                    }
                }
                .padding()
                Spacer()
            } else {
                List(viewModel.filteredDevices) { device in
                    DeviceRowView(device: device, viewModel: viewModel)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
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
                .help(viewModel.hasSelection
                      ? String(localized: "sidebar.deselect_all.help")
                      : String(localized: "sidebar.select_all.help"))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14)
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
        HStack(spacing: 8) {
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
                HStack(spacing: 6) {
                    if viewModel.isApplyingLatestIOSTemplate {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(String(localized: "sidebar.toolbar.template"))
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(settings.selectedTheme.secondarySurfaceColor(for: colorScheme))
                )
                .overlay(
                    Capsule()
                        .stroke(settings.selectedTheme.borderColor(for: colorScheme), lineWidth: 1)
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
        HStack(spacing: 10) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

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
            .accessibilityLabel(String(localized: "download.queued"))
        case .paused:
            HStack(spacing: 4) {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
                Text(String(localized: "download.paused")).font(.caption2).foregroundStyle(.secondary)
            }
            .accessibilityLabel(String(localized: "download.paused"))
        case .downloading(let progress):
            HStack(spacing: 6) {
                ProgressView(value: progress)
                    .frame(width: 60)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityLabel(String(format: String(localized: "accessibility.downloading"), Int(progress * 100)))
        case .verifying:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("SHA1…").font(.caption2).foregroundStyle(.secondary)
            }
            .accessibilityLabel(String(localized: "download.verifying"))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel(String(localized: "download.completed"))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel(String(localized: "detail.section.failed"))
        }
    }
}

// MARK: - Detail View

struct DetailView: View {
    @ObservedObject var viewModel: IPSWViewModel
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isActivityCollapsed = false

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
        guard !viewModel.selectedDeviceIDs.isEmpty else {
            return viewModel.recentActivityEntries
        }
        return viewModel.recentActivityEntries.filter { entry in
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

    private var isShowingEmptyState: Bool {
        viewModel.selectedDeviceIDs.isEmpty && managedDevices.isEmpty && viewModel.downloadedFirmware.isEmpty
    }

    private var primaryControlTitle: String {
        if viewModel.hasActiveDownloads {
            return String(localized: "download.pause_all")
        }
        return String(localized: "download.resume_all")
    }

    private var primaryControlSystemImage: String {
        viewModel.hasActiveDownloads ? "pause.fill" : "play.fill"
    }

    var body: some View {
        if isShowingEmptyState {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "detail.empty"))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 10) {
                        instructionRow(number: "1", text: String(localized: "detail.empty.step1"))
                        instructionRow(number: "2", text: String(localized: "detail.empty.step2"))
                        instructionRow(number: "3", text: String(localized: "detail.empty.step3"))
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)

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
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
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

                    HStack(spacing: 8) {
                        SummaryChip(title: String(localized: "detail.section.managed"), count: managedDevices.count, color: .blue)
                        SummaryChip(title: String(localized: "detail.section.paused"), count: pausedDevices.count, color: .orange)
                        SummaryChip(title: String(localized: "detail.section.failed"), count: failedDevices.count, color: .red)
                    }

                    if !managedDevices.isEmpty {
                        controlCenterPanel
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(settings.selectedTheme.secondarySurfaceColor(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(settings.selectedTheme.borderColor(for: colorScheme), lineWidth: 1)
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

    private var controlCenterPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "menu.downloads"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.globalProgressTitle)
                        .font(.headline)
                }

                Spacer()

                if !viewModel.downloadStatsText.isEmpty {
                    Text(viewModel.downloadStatsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            ProgressView(value: viewModel.globalProgressFraction)
                .progressViewStyle(.linear)

            HStack(spacing: 10) {
                Button {
                    if viewModel.hasActiveDownloads {
                        viewModel.pauseAllManagedDownloads()
                    } else {
                        viewModel.resumeAllPausedDownloads()
                    }
                } label: {
                    Label(primaryControlTitle, systemImage: primaryControlSystemImage)
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.hasActiveDownloads && !viewModel.hasPausedDownloads)

                Button {
                    viewModel.resumeAllPausedDownloads()
                } label: {
                    Label(String(localized: "download.resume_all"), systemImage: "play.circle.fill")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!viewModel.hasPausedDownloads)

                Button(role: .destructive) {
                    viewModel.cancelAllManagedDownloads()
                } label: {
                    Label(String(localized: "download.cancel_all"), systemImage: "stop.circle.fill")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(settings.selectedTheme.windowBackgroundColor(for: colorScheme).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(settings.selectedTheme.borderColor(for: colorScheme), lineWidth: 1)
        )
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ActivitySectionList: View {
    let entries: [ActivityLogEntry]
    @Binding var isCollapsed: Bool
    var onClear: (() -> Void)? = nil

    var body: some View {
        if !entries.isEmpty {
            Section {
                if !isCollapsed {
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
                HStack(spacing: 6) {
                    Button {
                        withAnimation { isCollapsed.toggle() }
                    } label: {
                        HStack(spacing: 6) {
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
                .modifier(NumericTextTransitionIfAvailable())
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
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
                    if let device = devicePendingCancel {
                        viewModel.cancelDownload(for: device)
                    }
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
                    if let device = devicePendingRemoval {
                        viewModel.removeDevice(device)
                    }
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

    private var managedDevices: [IPSWDevice] {
        activeDevices + pausedDevices
    }

    var body: some View {
        if !managedDevices.isEmpty {
            Section {
                ForEach(managedDevices) { device in
                    DownloadTaskCard(device: device, viewModel: viewModel, allowsManagedSelection: false)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
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
        VStack(alignment: .leading, spacing: 8) {
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
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                    Text(device.identifier)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
                actionButton
            }

            if let fw = task?.firmware {
                HStack(spacing: 6) {
                    Text("\(fw.version) (\(fw.buildid))")
                    Text("•")
                    Text(fw.filesizeMB)
                    if fw.signed {
                        Text("•")
                        Text(String(localized: "download.signed"))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

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
                    .font(.caption2)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .modifier(PulsingBorder(isActive: isDownloading))
        .animation(.easeInOut(duration: 0.3), value: stateKey)
        .help(cardTooltip)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cardAccessibilityLabel)
    }

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

    private var cardTooltip: String {
        var parts = [device.name, device.identifier]
        if let fw = task?.firmware {
            parts.append("\(device.osLabel) \(fw.version) (\(fw.buildid))")
            parts.append(fw.filesizeMB)
        }
        return parts.joined(separator: " — ")
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

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let symbol: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.caption2)
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pulsing Border Modifier

private struct PulsingBorder: ViewModifier {
    let isActive: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.blue.opacity(pulse ? 0.5 : 0.15), lineWidth: 2)
                    .opacity(isActive ? 1 : 0)
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                } else {
                    withAnimation { pulse = false }
                }
            }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: IPSWViewModel())
    }
}
