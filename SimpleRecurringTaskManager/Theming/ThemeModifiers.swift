//
//  ThemeModifiers.swift
//  SimpleTimer
//
//  Small composable View extensions used to theme screen backgrounds, card
//  groupings, and Form/List chrome without touching any view logic.
//

import SwiftUI

private struct ThemedScreenBackgroundModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        // A plain `.background()` only paints behind `content`'s own reported
        // size — fine for screens whose root is an inherently full-width
        // container (ScrollView, List, Form), but a screen whose root is a
        // centered VStack (e.g. ActiveTimerView) would report a narrower
        // natural width, leaving the true screen edges unpainted. Layering
        // the color first in a ZStack guarantees edge-to-edge fill (Color
        // always expands to fill whatever space it's proposed) regardless of
        // what the foreground content's own layout behavior is.
        ZStack {
            theme.colors.background.ignoresSafeArea()
            content
        }
    }
}

private struct ThemedCardModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                    .fill(theme.colors.surface)
                    .shadow(
                        color: theme.colors.shadow,
                        radius: theme.metrics.shadowRadius,
                        x: theme.metrics.shadowOffset.width,
                        y: theme.metrics.shadowOffset.height
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                    .stroke(theme.appTheme == .retro ? theme.colors.border : Color.clear, lineWidth: theme.metrics.borderWidth)
            )
    }
}

private struct ThemedFormChromeModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(theme.colors.background)
            .tint(theme.colors.accent)
    }
}

extension View {
    /// Fills the screen with the theme's background color, edge to edge.
    func themedScreenBackground() -> some View {
        modifier(ThemedScreenBackgroundModifier())
    }

    /// Groups content into a themed surface/card (background, corner radius,
    /// border, shadow all driven by the current Theme).
    func themedCard() -> some View {
        modifier(ThemedCardModifier())
    }

    /// Applies theme colors to a Form/List's chrome without altering its
    /// native row/section structure.
    func themedFormChrome() -> some View {
        modifier(ThemedFormChromeModifier())
    }
}
