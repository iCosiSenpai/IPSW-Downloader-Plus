import SwiftUI
import Testing
@testable import IPSW_Downloader_Plus

struct ThemeBehaviorTests {

    @Test
    func appearanceModeMapsToExpectedColorScheme() {
        #expect(AppAppearanceMode.system.preferredColorScheme == nil)
        #expect(AppAppearanceMode.light.preferredColorScheme == .light)
        #expect(AppAppearanceMode.dark.preferredColorScheme == .dark)
    }

    @Test
    func eachThemeProvidesDistinctWindowBackgroundsForLightAndDark() {
        for theme in AppTheme.allCases {
            let light = theme.windowBackgroundColor(for: .light)
            let dark = theme.windowBackgroundColor(for: .dark)

            #expect(light != dark)
        }
    }

    @Test
    func eachThemeProvidesTwoCanvasStopsPerAppearance() {
        for theme in AppTheme.allCases {
            #expect(theme.canvasColors(for: .light).count == 2)
            #expect(theme.canvasColors(for: .dark).count == 2)
        }
    }
}
