//
//  ThemeTokens.swift
//  SimpleTimer
//
//  Design tokens for each AppTheme. This is the single source of truth for
//  color/typography/metrics — views never hardcode a color or font, they read
//  Theme via @Environment(\.theme) instead. Light and Dark are identical in
//  every dimension except color; Retro also differs in metrics/typography to
//  achieve a 16-bit game UI look.
//

import SwiftUI

struct Theme {
    struct Colors {
        var background: Color
        var surface: Color
        var primaryText: Color
        var secondaryText: Color
        var accent: Color
        var destructive: Color
        var success: Color
        var border: Color
        var shadow: Color
    }

    struct Typography {
        var title: Font
        var headline: Font
        var body: Font
        var caption: Font
        var buttonLabel: Font
        var countdownDisplay: Font
    }

    struct Metrics {
        var cornerRadius: CGFloat
        var borderWidth: CGFloat
        var shadowRadius: CGFloat
        var shadowOffset: CGSize
        var pressedScale: CGFloat
    }

    var appTheme: AppTheme
    var colors: Colors
    var typography: Typography
    var metrics: Metrics

    static func resolve(_ appTheme: AppTheme) -> Theme {
        switch appTheme {
        case .light: return .lightTheme
        case .dark: return .darkTheme
        case .retro: return .retroTheme
        }
    }

    // MARK: - Light

    private static let lightTheme = Theme(
        appTheme: .light,
        colors: Colors(
            background: Color(white: 0.96),
            surface: Color.white,
            primaryText: Color(white: 0.09),
            secondaryText: Color(white: 0.45),
            accent: Color(red: 0.0, green: 0.48, blue: 1.0),
            destructive: Color(red: 1.0, green: 0.23, blue: 0.19),
            success: Color(red: 0.20, green: 0.78, blue: 0.35),
            border: Color.black.opacity(0.08),
            shadow: Color.black.opacity(0.10)
        ),
        typography: standardTypography,
        metrics: standardMetrics
    )

    // MARK: - Dark

    private static let darkTheme = Theme(
        appTheme: .dark,
        colors: Colors(
            background: Color.black,
            surface: Color(white: 0.11),
            primaryText: Color(white: 0.96),
            secondaryText: Color(white: 0.62),
            accent: Color(red: 0.0, green: 0.48, blue: 1.0),
            destructive: Color(red: 1.0, green: 0.27, blue: 0.23),
            success: Color(red: 0.20, green: 0.78, blue: 0.35),
            border: Color.white.opacity(0.12),
            shadow: Color.black.opacity(0.55)
        ),
        typography: standardTypography,
        metrics: standardMetrics
    )

    // Shared by Light + Dark, per the requirement that they differ only in color.
    // Uses TextStyle-relative system fonts (not the fixed `size:` initializer) so
    // these actually respect the user's Dynamic Type setting — `.system(size:)`
    // alone does not scale, by Apple's own design.
    // countdownDisplay is deliberately fixed-size: a hero numeric display, same
    // choice Apple's own Clock app timer makes.
    private static let standardTypography = Typography(
        title: .system(.title, design: .rounded).weight(.bold),
        headline: .system(.headline, design: .rounded).weight(.semibold),
        body: .system(.body, design: .default),
        caption: .system(.caption, design: .default),
        buttonLabel: .system(.body, design: .rounded).weight(.semibold),
        countdownDisplay: .system(size: 80, weight: .thin, design: .rounded).monospacedDigit()
    )

    private static let standardMetrics = Metrics(
        cornerRadius: 16,
        borderWidth: 1,
        shadowRadius: 10,
        shadowOffset: CGSize(width: 0, height: 4),
        pressedScale: 0.97
    )

    // MARK: - Retro (16-bit)

    private static let retroTheme = Theme(
        appTheme: .retro,
        colors: Colors(
            background: Color(red: 0.07, green: 0.06, blue: 0.16),
            surface: Color(red: 0.15, green: 0.12, blue: 0.30),
            primaryText: Color(red: 0.93, green: 0.95, blue: 1.0),
            secondaryText: Color(red: 0.72, green: 0.68, blue: 0.88),
            accent: Color(red: 0.0, green: 0.90, blue: 1.0),
            destructive: Color(red: 1.0, green: 0.24, blue: 0.35),
            success: Color(red: 0.36, green: 1.0, blue: 0.42),
            border: Color.black,
            shadow: Color.black
        ),
        // `relativeTo:` makes even this custom font scale with Dynamic Type;
        // countdownDisplay stays fixed-size, same rationale as standardTypography.
        typography: Typography(
            title: .custom("PressStart2P-Regular", size: 20, relativeTo: .title),
            headline: .custom("PressStart2P-Regular", size: 13, relativeTo: .headline),
            body: .custom("PressStart2P-Regular", size: 11, relativeTo: .body),
            caption: .custom("PressStart2P-Regular", size: 9, relativeTo: .caption),
            buttonLabel: .custom("PressStart2P-Regular", size: 12, relativeTo: .body),
            countdownDisplay: .custom("PressStart2P-Regular", size: 46)
        ),
        metrics: Metrics(
            cornerRadius: 3,
            borderWidth: 3,
            shadowRadius: 0,
            shadowOffset: CGSize(width: 4, height: 4),
            pressedScale: 1.0
        )
    )
}
