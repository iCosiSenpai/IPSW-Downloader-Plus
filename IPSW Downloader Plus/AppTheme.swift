//
//  AppTheme.swift
//  IPSW Downloader Plus
//

import SwiftUI

// MARK: - Platform Compatibility

enum AppCompatibility {
    static var usesLegacySwiftUIWorkarounds: Bool {
        #if arch(x86_64)
        true
        #else
        false
        #endif
    }
}

// MARK: - Links

enum AppLinks {
    static let github = URL(string: "https://github.com/iCosiSenpai") ?? URL(fileURLWithPath: NSHomeDirectory())
    static let support = URL(string: "https://paypal.me/AlessioCosi") ?? URL(fileURLWithPath: NSHomeDirectory())
}

// MARK: - Appearance Mode

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .system: return String(localized: "settings.appearance.mode.system")
        case .light:  return String(localized: "settings.appearance.mode.light")
        case .dark:   return String(localized: "settings.appearance.mode.dark")
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case cobalt
    case forest
    case sunset
    case graphite

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .cobalt:   return String(localized: "settings.appearance.theme.cobalt")
        case .forest:   return String(localized: "settings.appearance.theme.forest")
        case .sunset:   return String(localized: "settings.appearance.theme.sunset")
        case .graphite: return String(localized: "settings.appearance.theme.graphite")
        }
    }

    var localizedDescription: String {
        switch self {
        case .cobalt:   return String(localized: "settings.appearance.theme.cobalt.description")
        case .forest:   return String(localized: "settings.appearance.theme.forest.description")
        case .sunset:   return String(localized: "settings.appearance.theme.sunset.description")
        case .graphite: return String(localized: "settings.appearance.theme.graphite.description")
        }
    }

    // MARK: Core Colors

    var tintColor: Color {
        switch self {
        case .cobalt:   return Color(red: 0.15, green: 0.42, blue: 0.96)
        case .forest:   return Color(red: 0.05, green: 0.58, blue: 0.42)
        case .sunset:   return Color(red: 0.93, green: 0.38, blue: 0.08)
        case .graphite: return Color(red: 0.38, green: 0.44, blue: 0.55)
        }
    }

    var accentColor: Color {
        switch self {
        case .cobalt:   return Color(red: 0.25, green: 0.72, blue: 0.98)
        case .forest:   return Color(red: 0.22, green: 0.82, blue: 0.58)
        case .sunset:   return Color(red: 0.99, green: 0.60, blue: 0.28)
        case .graphite: return Color(red: 0.60, green: 0.66, blue: 0.76)
        }
    }

    /// Soft glow for atmospheric canvas effects
    fileprivate var glowColor: Color {
        switch self {
        case .cobalt:   return Color(red: 0.30, green: 0.55, blue: 1.00)
        case .forest:   return Color(red: 0.15, green: 0.70, blue: 0.50)
        case .sunset:   return Color(red: 1.00, green: 0.48, blue: 0.18)
        case .graphite: return Color(red: 0.50, green: 0.55, blue: 0.68)
        }
    }

    // MARK: Gradient & Surface

    func heroGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let strength = colorScheme == .dark ? 0.22 : 0.14
        return LinearGradient(
            colors: [
                tintColor.opacity(strength),
                accentColor.opacity(strength * 0.45),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func canvasColors(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .dark {
            switch self {
            case .cobalt:
                return [Color(red: 0.04, green: 0.06, blue: 0.11), Color(red: 0.07, green: 0.10, blue: 0.16)]
            case .forest:
                return [Color(red: 0.04, green: 0.07, blue: 0.06), Color(red: 0.06, green: 0.11, blue: 0.09)]
            case .sunset:
                return [Color(red: 0.08, green: 0.06, blue: 0.04), Color(red: 0.13, green: 0.09, blue: 0.06)]
            case .graphite:
                return [Color(red: 0.06, green: 0.06, blue: 0.08), Color(red: 0.10, green: 0.11, blue: 0.14)]
            }
        }
        switch self {
        case .cobalt:
            return [Color(red: 0.95, green: 0.97, blue: 1.00), Color(red: 0.88, green: 0.93, blue: 1.00)]
        case .forest:
            return [Color(red: 0.94, green: 0.99, blue: 0.96), Color(red: 0.85, green: 0.97, blue: 0.91)]
        case .sunset:
            return [Color(red: 1.00, green: 0.97, blue: 0.93), Color(red: 1.00, green: 0.92, blue: 0.84)]
        case .graphite:
            return [Color(red: 0.96, green: 0.97, blue: 0.98), Color(red: 0.90, green: 0.92, blue: 0.95)]
        }
    }

    func windowBackgroundColor(for colorScheme: ColorScheme) -> Color {
        canvasColors(for: colorScheme).first ?? .clear
    }

    func surfaceColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.055)
            : Color.white.opacity(0.82)
    }

    func secondarySurfaceColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : tintColor.opacity(0.06)
    }

    func borderColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : tintColor.opacity(0.10)
    }

    func elevatedSurfaceColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.white.opacity(0.94)
    }
}

// MARK: - Canvas Background

struct ThemeCanvasBackground: View {
    let theme: AppTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.canvasColors(for: colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if !AppCompatibility.usesLegacySwiftUIWorkarounds {
                RadialGradient(
                    colors: [
                        theme.glowColor.opacity(colorScheme == .dark ? 0.07 : 0.04),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 600
                )
                RadialGradient(
                    colors: [
                        theme.accentColor.opacity(colorScheme == .dark ? 0.03 : 0.02),
                        .clear
                    ],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 500
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [theme.tintColor, theme.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 56)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(theme.localizedTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text(theme.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .liquidGlassCard(theme: theme, colorScheme: colorScheme, cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isSelected ? theme.tintColor : .clear,
                    lineWidth: isSelected ? 2.5 : 0
                )
        )
        .shadow(
            color: isSelected ? theme.tintColor.opacity(0.18) : .black.opacity(0.04),
            radius: isSelected ? 10 : 4,
            y: isSelected ? 4 : 2
        )
        .scaleEffect(isSelected ? 1.0 : 0.98)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - View Modifiers

struct ThemePanelBackground: ViewModifier {
    let theme: AppTheme
    let colorScheme: ColorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(theme.borderColor(for: colorScheme), lineWidth: 0.5)
                )
        }
    }
}

struct ThemeMetricCardBackground: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tint.opacity(colorScheme == .dark ? 0.14 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(tint.opacity(colorScheme == .dark ? 0.20 : 0.14), lineWidth: 0.5)
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

// MARK: - macOS 26 Liquid Glass

/// On macOS 26+, applies the Liquid Glass effect to views. Falls back to standard material on older systems.
struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// Applies Liquid Glass toolbar styling on macOS 26+.
struct LiquidGlassToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        } else {
            content
        }
    }
}

/// Card modifier that uses Liquid Glass on macOS 26, standard surface on older.
struct LiquidGlassCardModifier: ViewModifier {
    let theme: AppTheme
    let colorScheme: ColorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(theme.borderColor(for: colorScheme), lineWidth: 0.5)
                )
        }
    }
}

extension View {
    /// Apply Liquid Glass on macOS 26+, ultraThinMaterial fallback on older.
    func liquidGlass(cornerRadius: CGFloat = 12) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }

    /// Apply Liquid Glass toolbar effect on macOS 26+.
    func liquidGlassToolbar() -> some View {
        modifier(LiquidGlassToolbarModifier())
    }

    /// Card surface with Liquid Glass on macOS 26+, themed background on older.
    func liquidGlassCard(theme: AppTheme, colorScheme: ColorScheme, cornerRadius: CGFloat = 12) -> some View {
        modifier(LiquidGlassCardModifier(theme: theme, colorScheme: colorScheme, cornerRadius: cornerRadius))
    }
}
