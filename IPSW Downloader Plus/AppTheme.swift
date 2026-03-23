//
//  AppTheme.swift
//  IPSW Downloader Plus
//

import SwiftUI
import AppKit

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .system:
            return String(localized: "settings.appearance.mode.system")
        case .light:
            return String(localized: "settings.appearance.mode.light")
        case .dark:
            return String(localized: "settings.appearance.mode.dark")
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case cobalt
    case forest
    case sunset
    case graphite

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .cobalt:
            return String(localized: "settings.appearance.theme.cobalt")
        case .forest:
            return String(localized: "settings.appearance.theme.forest")
        case .sunset:
            return String(localized: "settings.appearance.theme.sunset")
        case .graphite:
            return String(localized: "settings.appearance.theme.graphite")
        }
    }

    var localizedDescription: String {
        switch self {
        case .cobalt:
            return String(localized: "settings.appearance.theme.cobalt.description")
        case .forest:
            return String(localized: "settings.appearance.theme.forest.description")
        case .sunset:
            return String(localized: "settings.appearance.theme.sunset.description")
        case .graphite:
            return String(localized: "settings.appearance.theme.graphite.description")
        }
    }

    var tintColor: Color {
        switch self {
        case .cobalt:
            return Color(red: 0.10, green: 0.44, blue: 0.94)
        case .forest:
            return Color(red: 0.11, green: 0.53, blue: 0.36)
        case .sunset:
            return Color(red: 0.84, green: 0.36, blue: 0.18)
        case .graphite:
            return Color(red: 0.33, green: 0.38, blue: 0.46)
        }
    }

    var accentColor: Color {
        switch self {
        case .cobalt:
            return Color(red: 0.35, green: 0.72, blue: 1.00)
        case .forest:
            return Color(red: 0.49, green: 0.83, blue: 0.62)
        case .sunset:
            return Color(red: 0.99, green: 0.67, blue: 0.35)
        case .graphite:
            return Color(red: 0.74, green: 0.77, blue: 0.85)
        }
    }

    func heroGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let colors: [Color]
        switch self {
        case .cobalt:
            colors = [
                tintColor.opacity(colorScheme == .dark ? 0.20 : 0.16),
                accentColor.opacity(colorScheme == .dark ? 0.12 : 0.08),
                surfaceColor(for: colorScheme)
            ]
        case .forest:
            colors = [
                tintColor.opacity(colorScheme == .dark ? 0.18 : 0.14),
                accentColor.opacity(colorScheme == .dark ? 0.10 : 0.08),
                surfaceColor(for: colorScheme)
            ]
        case .sunset:
            colors = [
                tintColor.opacity(colorScheme == .dark ? 0.18 : 0.14),
                accentColor.opacity(colorScheme == .dark ? 0.10 : 0.08),
                surfaceColor(for: colorScheme)
            ]
        case .graphite:
            colors = [
                tintColor.opacity(colorScheme == .dark ? 0.18 : 0.12),
                accentColor.opacity(colorScheme == .dark ? 0.08 : 0.06),
                surfaceColor(for: colorScheme)
            ]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func canvasColors(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .dark {
            switch self {
            case .cobalt:
                return [Color(red: 0.07, green: 0.09, blue: 0.12), Color(red: 0.10, green: 0.13, blue: 0.18)]
            case .forest:
                return [Color(red: 0.07, green: 0.09, blue: 0.10), Color(red: 0.09, green: 0.13, blue: 0.11)]
            case .sunset:
                return [Color(red: 0.10, green: 0.09, blue: 0.08), Color(red: 0.14, green: 0.11, blue: 0.09)]
            case .graphite:
                return [Color(red: 0.08, green: 0.08, blue: 0.09), Color(red: 0.12, green: 0.12, blue: 0.14)]
            }
        }

        switch self {
        case .cobalt:
            return [Color(red: 0.95, green: 0.97, blue: 0.99), Color(red: 0.92, green: 0.95, blue: 0.99)]
        case .forest:
            return [Color(red: 0.95, green: 0.98, blue: 0.96), Color(red: 0.92, green: 0.96, blue: 0.94)]
        case .sunset:
            return [Color(red: 0.99, green: 0.96, blue: 0.93), Color(red: 0.98, green: 0.93, blue: 0.89)]
        case .graphite:
            return [Color(red: 0.95, green: 0.95, blue: 0.96), Color(red: 0.92, green: 0.93, blue: 0.95)]
        }
    }

    func windowBackgroundColor(for colorScheme: ColorScheme) -> Color {
        canvasColors(for: colorScheme).first ?? .clear
    }

    func windowBackgroundNSColor(for colorScheme: ColorScheme) -> NSColor {
        switch (self, colorScheme) {
        case (.cobalt, .dark):
            return NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.12, alpha: 1)
        case (.forest, .dark):
            return NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.10, alpha: 1)
        case (.sunset, .dark):
            return NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.08, alpha: 1)
        case (.graphite, .dark):
            return NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        case (.cobalt, _):
            return NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.99, alpha: 1)
        case (.forest, _):
            return NSColor(calibratedRed: 0.95, green: 0.98, blue: 0.96, alpha: 1)
        case (.sunset, _):
            return NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.93, alpha: 1)
        case (.graphite, _):
            return NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.96, alpha: 1)
        }
    }

    func surfaceColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.055)
            : Color.white.opacity(0.78)
    }

    func secondarySurfaceColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.075)
            : tintColor.opacity(0.08)
    }

    func borderColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : tintColor.opacity(0.14)
    }
}

struct ThemeCanvasBackground: View {
    let theme: AppTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.canvasColors(for: colorScheme), startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(
                colors: [
                    theme.tintColor.opacity(colorScheme == .dark ? 0.10 : 0.05),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
    }
}

struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.heroGradient(for: colorScheme))
                .frame(height: 72)
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                }

            Text(theme.localizedTitle)
                .font(.headline)

            Text(theme.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(theme.surfaceColor(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? theme.tintColor : theme.borderColor(for: colorScheme), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: .black.opacity(isSelected ? 0.14 : 0.05), radius: isSelected ? 14 : 6, y: isSelected ? 8 : 4)
    }
}

struct ThemePanelBackground: ViewModifier {
    let theme: AppTheme
    let colorScheme: ColorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(theme.surfaceColor(for: colorScheme), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(theme.borderColor(for: colorScheme), lineWidth: 1)
            )
    }
}

struct ThemeMetricCardBackground: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(tint.opacity(colorScheme == .dark ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(tint.opacity(colorScheme == .dark ? 0.28 : 0.20), lineWidth: 1)
            )
    }
}

extension View {
    func themePanelBackground(theme: AppTheme, colorScheme: ColorScheme, cornerRadius: CGFloat) -> some View {
        modifier(ThemePanelBackground(theme: theme, colorScheme: colorScheme, cornerRadius: cornerRadius))
    }

    func themeMetricCardBackground(tint: Color, cornerRadius: CGFloat = 18) -> some View {
        modifier(ThemeMetricCardBackground(tint: tint, cornerRadius: cornerRadius))
    }
}

struct ThemeWindowConfigurator: NSViewRepresentable {
    let theme: AppTheme
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        ConfiguratorView(theme: theme, colorScheme: colorScheme)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? ConfiguratorView else { return }
        view.theme = theme
        view.colorScheme = colorScheme
    }

    private final class ConfiguratorView: NSView {
        var theme: AppTheme {
            didSet { applyWindowBackgroundIfNeeded() }
        }

        var colorScheme: ColorScheme {
            didSet { applyWindowBackgroundIfNeeded() }
        }

        init(theme: AppTheme, colorScheme: ColorScheme) {
            self.theme = theme
            self.colorScheme = colorScheme
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyWindowBackgroundIfNeeded()
        }

        private func applyWindowBackgroundIfNeeded() {
            guard let window else { return }
            let backgroundColor = theme.windowBackgroundNSColor(for: colorScheme)
            if window.backgroundColor != backgroundColor {
                window.backgroundColor = backgroundColor
            }
            window.isOpaque = true
        }
    }
}
